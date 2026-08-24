function sharedSelections = selectAllSharedSelections(videoTable, videoPacks, settings, resultFolder)
    
    % This function keeps the selections of each pack of videos.
    % For each pack, the 1 Hz video is used as reference. 
    % The selected ROI, cell line and KLT tracking box are later applied to the three videos of
    % that same pack.

    sharedSelections = struct();

    for packIdx = 1:numel(videoPacks)

        packName = videoPacks(packIdx);

        % Return only the three videos belonging to the selected pack.
        packVideos = videoTable(videoTable.GroupID == packName, :);
        packVideos = packVideos(ismember(packVideos.StimIndex, [1 2 3]), :);
        packVideos = sortrows(packVideos, 'StimIndex'); % put the videos in order

        % Prefer video (1), corresponding to 1 Hz, for manual selections.
        referenceRow = find(packVideos.StimIndex == 1, 1);

        if isempty(referenceRow)
            referenceRow = 1;
        end

        referenceVideoPath = packVideos.FullPath(referenceRow);

        fprintf('Manual selections %d/%d: %s\n', packIdx, numel(videoPacks), packName);
        disp(packVideos(:, {'FileName','StimIndex'}));

        % For each pack, the shared selections are reused in later runs.
        selectionFile = fullfile(settings.selectionFolder, char(packName + "_shared_selections.mat"));

        if settings.reuseSavedSelections && exist(selectionFile, 'file')

            loaded = load(selectionFile, 'shared');
            shared = loaded.shared;
            fprintf('Loaded saved selections for %s.\n', packName);

        else

            % The ROI defines the common crop used for the three videos of one pack.
            v = VideoReader(referenceVideoPath);
            v.CurrentTime = 0;
            firstFrame = readFrame(v);

            figure;
            imshow(firstFrame, []);
            title("Select shared ROI - " + packName);

            roi = drawrectangle('Color','r');
            wait(roi);

            roiPos = round(roi.Position);
            close(gcf);

            % The reference video is preprocessed once so the mask and box are drawn
            % on the same images that will later be analysed.
            [refFrames, ~, refFps] = preprocessVideo( ...
                 referenceVideoPath, roiPos, settings.sigmaBlur, settings.maxVideoTime_s);

            % The cell line is used only for activity/frequency analysis.
            % It defines which pixels belong to the cell region.

            % safeFrameIndex for mask frame
            maskFrame = round(settings.maskTime_s * refFps);
            maskFrame = max(1, maskFrame);
            maskFrame = min(size(refFrames,3), maskFrame);

            figure;
            imshow(refFrames(:,:,maskFrame), []);
            title("Draw cell line for activity analysis - " + packName);

            hLine = drawpolyline('Color','y');
            wait(hLine);
            linePos = hLine.Position;

            % makeTubeMask
            H = size(refFrames,1);
            W = size(refFrames,2);

            maskLine = false(H, W);

            for i = 1:size(linePos,1)-1

                x1 = linePos(i,1);
                y1 = linePos(i,2);
                x2 = linePos(i+1,1);
                y2 = linePos(i+1,2);

                nPointsLine = ceil(sqrt((x2-x1)^2 + (y2-y1)^2));
                xs = linspace(x1, x2, nPointsLine);
                ys = linspace(y1, y2, nPointsLine);

                for j = 1:nPointsLine
                    xPix = round(xs(j));
                    yPix = round(ys(j));

                    if xPix >= 1 && xPix <= W && yPix >= 1 && yPix <= H
                        maskLine(yPix, xPix) = true;
                    end
                end
            end

            cellMask = imdilate(maskLine, strel('disk', settings.tubeRadius));

            figure;
            imshow(labeloverlay(refFrames(:,:,maskFrame), cellMask));
            title("Cell mask - " + packName);

            % Tracking box plot of moving area
            patchFrame = round(settings.patchTime_s * refFps);
            patchFrame = max(1, patchFrame);
            patchFrame = min(size(refFrames,3), patchFrame);

            figure;
            imshow(refFrames(:,:,patchFrame), []);
            title("Select tracking box in the first frame - " + packName);

            hPatch = drawrectangle('Color','r');
            wait(hPatch);
            patchBox0 = round(hPatch.Position);

            figure;
            imshow(refFrames(:,:,patchFrame), []);
            hold on;
            rectangle('Position', patchBox0, 'EdgeColor', 'r', 'LineWidth', 2);
            title("Tracking box - " + packName);

            shared.roiPos = roiPos;
            shared.linePos = linePos;
            shared.cellMask = cellMask;
            shared.patchBox0 = patchBox0;
            shared.tubeRadius = settings.tubeRadius;
            shared.maskTime_s = settings.maskTime_s;
            shared.patchTime_s = settings.patchTime_s;

            save(selectionFile, 'shared');

        end

        sharedSelections.(matlab.lang.makeValidName(char(packName))) = shared;

    end

    % Save all selections together before analysis starts.
    save(fullfile(resultFolder, 'all_shared_selections.mat'), ...
        'sharedSelections', 'videoPacks', 'videoTable', 'settings');

end