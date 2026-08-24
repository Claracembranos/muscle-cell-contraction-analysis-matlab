function [frames, timeVec, fps] = preprocessVideo(videoPath, roiPos, sigmaBlur, maxVideoTime_s)

    % This function reads one video, crops the selected ROI,
    % converts the frames to grayscale, applies Gaussian blur,
    % and keeps only the first maxVideoTime_s seconds.
    
    %Preprocess
    v = VideoReader(videoPath);

    fps = v.FrameRate;
    videoDuration = v.Duration;

    analysisDuration = min(videoDuration, maxVideoTime_s);
    nFramesToRead = floor(analysisDuration * fps);

    fprintf('      Video duration: %.2f s | Analysed duration: %.2f s | Frames to read: %d\n', ...
        videoDuration, analysisDuration, nFramesToRead);

    v.CurrentTime = 0;

    try
        firstFrame = readFrame(v);
    catch ME
        error('The first frame could not be read. %s', ME.message);
    end
    
    %Grayscale
    firstCrop = imcrop(firstFrame, roiPos);

    if size(firstCrop,3) == 3
        gray = rgb2gray(firstCrop);
    else
        gray = firstCrop;
    end
    
    %Gaussian Blur
    gray = im2double(gray);
    gray = imgaussfilt(gray, sigmaBlur);

    [H, W] = size(gray);
    
    %Load all frames
    frames = zeros(H, W, nFramesToRead);
    timeVec = zeros(1, nFramesToRead);

    frames(:,:,1) = gray;
    timeVec(1) = 0;

    frameIdx = 1;

    while hasFrame(v) && frameIdx < nFramesToRead

        frameIdx = frameIdx + 1;

        if mod(frameIdx,100) == 0
            fprintf('      Preprocessing frame %d/%d\n', frameIdx, nFramesToRead);
        end

        try
            frame = readFrame(v);
        catch ME
            warning('Frame reading stopped early in %s', videoPath);
            disp(ME.message);
            frameIdx = frameIdx - 1;
            break;
        end

        frameCrop = imcrop(frame, roiPos);

        if size(frameCrop,3) == 3
            gray = rgb2gray(frameCrop);
        else
            gray = frameCrop;
        end

        gray = im2double(gray);
        gray = imresize(gray, [H W]);
        gray = imgaussfilt(gray, sigmaBlur);

        frames(:,:,frameIdx) = gray;
        timeVec(frameIdx) = (frameIdx - 1) / fps;
    end

    frames = frames(:,:,1:frameIdx);
    timeVec = timeVec(1:frameIdx);

    fprintf('      Preprocessing finished. Loaded frames: %d\n', frameIdx);
end