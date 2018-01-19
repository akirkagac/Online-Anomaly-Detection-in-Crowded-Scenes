function groundTruth(groundTruthBoolean)

groundTruthStartEnd = [510,610;680,808;    %lawn
                     330,485;570,672;530,660;456,557;745,880;375,485;   %indoor
                       555,637;578,655;740,772];   %plaza

    if groundTruthBoolean == 1
        for j = 1:11
            vidReader = VideoReader(strcat('Trim',num2str(j),'.mp4'));
            alarms = zeros(1,ceil(vidReader.FrameRate*vidReader.Duration));
            
            alarms(groundTruthStartEnd(j,1):groundTruthStartEnd(j,2)) = 1;
            save(strcat('alarm',num2str(j),'.mat'),'alarms');
        end
    end
end