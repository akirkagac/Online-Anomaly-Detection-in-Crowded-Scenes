clear
clc;

%video number
videoNo = 1;
videoNoStr = num2str(videoNo);
count = 0;

%exponential smoothing parameters for alarm metrics
TOVExponential = 0.03;
EntropyExponential = 0.03;

%threshold value
TOVThreshold = 0.35;
EntropyThreshold = 0.35;

%define videoreader and videowriter objects
vidReader = VideoReader(strcat('Trim',videoNoStr,'.mp4'));
video=VideoWriter(strcat('Alarmed',videoNoStr,'.mp4'));
open(video);

numOfFrames = ceil(vidReader.FrameRate*vidReader.Duration);

alarmsDetected = zeros(1,numOfFrames);

%define optical flow object
opticFlow = opticalFlowFarneback;

TOVLevel = zeros(1,numOfFrames);
EntropyLevel = zeros(1,numOfFrames);


while hasFrame(vidReader)
    
    count = count + 1;
    fprintf('Image no %i\n',count); 
    frameRGB = readFrame(vidReader);

%     show RGB image
%     figure(1);
%     imshow(frameRGB)
    
    frameGray = rgb2gray(frameRGB);  
    %gaussian filtering to remove noise
    frameGray = imgaussfilt(frameGray,1);
    
    %create necessary arrays
    if count==1
        sizeG = size(frameGray);
        magSequence = zeros(sizeG(1),sizeG(2),30);
    end      
    
% estimate flow for each input frame
    flow = estimateFlow(opticFlow,frameGray); 

% calculate and refine magnitude of the optical flow    
    mag=flow.Magnitude;
    mag = mag.*(mag>0.3);
    
% show farneback magnitude output    
%     figure(3);
%     imshow(uint8(255*mat2gray(mag)))
    
%create activity map 
    countModulo = rem(count,30);
    if countModulo == 0
            countModulo = 30;
    end
    magSequence(:,:,countModulo) = mag;
    meanMag = mean(magSequence,3);

%start to display image and look for alarming situations after the
%activity map is available
    if(count >= 35)

%remove salt-pepper noise using median filtering
        activityMap = uint8(255*mat2gray(meanMag));
        activityMap = medfilt2(activityMap);
        
%         show activity map image
%         figure(4);
%         imshow(activityMap)
%         
        if(count == 35)
            oldFrame = activityMap;            
        end

       %calculate the difference between two activity maps and refine
       dif=(round(255*abs(im2double(activityMap) - im2double(oldFrame)))); 
       dif2= uint8(dif.*(dif>9));
       
%        figure(5);
%        imshow(dif2>0)
%  

       %define metrics
       TOVDifference = sum(sum(dif2))/(sizeG(1)*sizeG(2));
       imgEntropy = entropy(dif2);
 
       %define exponential smoothing for both metrics to employ persistency effect
       TOVLevel(count) = (1-TOVExponential)*TOVLevel(count-1) + TOVExponential*TOVDifference;
       EntropyLevel(count) = (1-EntropyExponential)*EntropyLevel(count-1) + EntropyExponential*imgEntropy;

       %check for alarms
       if (TOVLevel(count) > TOVThreshold || EntropyLevel(count) > EntropyThreshold)
           frameRGB = insertText(frameRGB,[100,100],'ALARM','FontSize',18,'TextColor','red');
           alarmsDetected(count) = 1;
       end
        
       %show processed output and save to video
        figure(1);imshow(frameRGB)
        writeVideo(video,frameRGB);
        oldFrame = activityMap;
    end
end

 close(video);
 %plot entropy and TOV over time
 figure(7); plot(TOVLevel);
 figure(8); plot(EntropyLevel);
 
 