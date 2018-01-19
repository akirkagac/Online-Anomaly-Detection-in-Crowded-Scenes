%takes long since it tries a range of threshold values

clear
clc;

%save ground truth information
groundTruthBoolean = 1;
groundTruth(groundTruthBoolean);

%exponential smoothing parameters for alarm metrics
TOVExponential = 0.03;
EntropyExponential = 0.03;

%threshold ranges
TOVThreshold = [0:0.005:0.03 , 0.06:0.1:0.36, 0.4:0.02:0.6];
EntropyThreshold = 0.75*TOVThreshold;

tp_rate = zeros(1,(length(TOVThreshold)+2));
fp_rate = zeros(1,(length(TOVThreshold)+2));

%ensure that this is a closed curve for AUC calculation
tp_rate(1) = 1;
fp_rate(1) = 1;

%iterate over videos for the same type
for videoNo = 9:11
    %iterate over threshold values
    for j = 1:length(TOVThreshold)
        videoNoStr = num2str(videoNo);
        vidReader = VideoReader(strcat('Trim',videoNoStr,'.mp4'));
        count = 0;
        numOfFrames = ceil(vidReader.FrameRate*vidReader.Duration);
        
        %load corresponding ground truth matrix
        load(strcat('alarm',videoNoStr,'.mat'));
        alarmsDetected = zeros(1,numOfFrames);
        
        %define optical flow object
        opticFlow = opticalFlowFarneback;
        
        TOVLevel = zeros(1,numOfFrames);
        EntropyLevel = zeros(1,numOfFrames);
        
        %iteration over one video
        while hasFrame(vidReader)
            
            count = count + 1;
            fprintf('Image no %i\n',count);
            frameRGB = readFrame(vidReader);
            
            %         figure(1);
            %         imshow(frameRGB)
            
            frameGray = rgb2gray(frameRGB);
            frameGray = imgaussfilt(frameGray,1);
            
            
            if count==1
                sizeG = size(frameGray);
                magSequence = zeros(sizeG(1),sizeG(2),30);
            end
            
            % estimate flow for each input frame
            flow = estimateFlow(opticFlow,frameGray);
            
            mag=flow.Magnitude;
            mag = mag.*(mag>0.3);
            
            
            %         figure(3);
            %         imshow(uint8(255*mat2gray(mag)))
            
            countModulo = rem(count,30);
            if countModulo == 0
                countModulo = 30;
            end
            magSequence(:,:,countModulo) = mag;
            meanMag = mean(magSequence,3);
            
            if(count >= 35)
                
                %remove salt-pepper noise using median filtering
                activityMap = uint8(255*mat2gray(meanMag));
                activityMap = medfilt2(activityMap);
                
                %             figure(4);
                %             imshow(activityMap)
                
                %start to display image and look for alarming situations after the
                %activity map is available
                if(count == 35)
                    oldFrame = activityMap;
                end
                
                dif=(round(255*abs(im2double(activityMap) - im2double(oldFrame))));
                dif2= uint8(dif.*(dif>9));
                
                %             figure(5);
                %             imshow(dif2>0)
                
                TOVDifference = sum(sum(dif2))/(sizeG(1)*sizeG(2));
                imgEntropy = entropy(dif2);
                
                %define exponential smoothing for both metrics to employ persistency effect
                TOVLevel(count) = (1-TOVExponential)*TOVLevel(count-1) + TOVExponential*TOVDifference;
                EntropyLevel(count) = (1-EntropyExponential)*EntropyLevel(count-1) + EntropyExponential*imgEntropy;
                
                %check for alarms
                if (TOVLevel(count) > TOVThreshold(j) || EntropyLevel(count) > TOVThreshold(j))
                    frameRGB = insertText(frameRGB,[100,100],'ALARM','FontSize',18,'TextColor','red');
                    alarmsDetected(count) = 1;
                end
                
                %figure(1);imshow(frameRGB)
                %writeVideo(video,frameRGB);
                oldFrame = activityMap;
            end
        end
        
        %calculate tp and fp rates (the coefficient 1/3 is basically for
        %averaging)
        tp_rate(j+1) = tp_rate(j+1) + (1/3) * sum((alarms == 1) & (alarmsDetected == 1)) / sum(alarms);
        fp_rate(j+1) = fp_rate(j+1) + (1/3) * sum((alarms == 0) & (alarmsDetected == 1)) / sum(alarms == 0);
        
        
        
    end
end

%plot roc
graph3 = plot(fp_rate,tp_rate,'-r'); xlabel('FPR');ylabel('TPR');
set (graph3,'LineWidth',3);
auc3 = -trapz(fp_rate,tp_rate)
