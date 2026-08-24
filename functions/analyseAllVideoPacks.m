function results = analyseAllVideoPacks(videoTable, videoPacks, sharedSelections, settings)

    % It preprocesses each video, calculate contractions and movement and
    % keep the results

    % initialiseResults

    % Empty tables are created
    results.contractionSummary = table();
    results.trackingSummary = table();
    results.finalSummary = table(); %final combinated table Tracking + Contraction
    results.contractionSeries = table();
    results.detectedContractions = table(); % individual contractions
    results.trackingSeries = table();

    for packIdx = 1:numel(videoPacks) % in our case, 18 packs

        packName = videoPacks(packIdx);
        % getGroupRows
        % Return only the three videos belonging to the selected pack.
        packVideos = videoTable(videoTable.GroupID == packName, :);
        packVideos = packVideos(ismember(packVideos.StimIndex, [1 2 3]), :);
        packVideos = sortrows(packVideos, 'StimIndex');

        shared = sharedSelections.(matlab.lang.makeValidName(char(packName)));

        fprintf('Analysis %d/%d: %s\n', packIdx, numel(videoPacks), packName);

        try

            % analyseVideoPack
            packResults.contractionSummary = table();
            packResults.trackingSummary = table();
            packResults.finalSummary = table();
            packResults.contractionSeries = table();
            packResults.detectedContractions = table();
            packResults.trackingSeries = table();

            for r = 1:height(packVideos)

                videoPath = packVideos.FullPath(r);
                fileName = packVideos.FileName(r);
                stimIndex = packVideos.StimIndex(r);
                
                % Convert it in real frequency
                if isKey(settings.stimIndexToFrequency, stimIndex) 
                    stimulationFrequency_Hz = settings.stimIndexToFrequency(stimIndex);
                else
                    stimulationFrequency_Hz = NaN;
                end

                fprintf('\nProcessing file %d/%d: %s\n', r, height(packVideos), fileName);

                fprintf('  1/2 Preprocessing video:\n');

                try %to not block the analysis in case of error
                    [frames, timeVec, fps] = preprocessVideo( ...
                        videoPath, shared.roiPos, settings.sigmaBlur, settings.maxVideoTime_s);
                catch ME
                    warning('This video could not be preprocessed and will be skipped: %s', fileName);
                    disp(ME.message);
                    continue;
                end

                fprintf('      Done. Frames: %d | FPS: %.2f\n', size(frames,3), fps);

                fprintf('  2/2 Contraction movement analysis:\n');

                % safeFrameIndex
                frameRef = round(settings.patchTime_s * fps);
                frameRef = max(1, frameRef);
                frameRef = min(size(frames,3), frameRef);

                [Tcontraction, Ttracking, TcontractionSeries, TdetectedContractions, TtrackingSeries] = runContractionMovementAnalysis( ...
                    frames, shared.cellMask, timeVec, fps, shared.patchBox0, frameRef, ...
                    settings.phaseNames, settings.phaseStart, settings.phaseEnd);

                fprintf('      Done.\n');

                % addVideoInfo for Tcontraction
                Tcontraction.GroupID = repmat(packName, height(Tcontraction), 1);
                Tcontraction.FileName = repmat(fileName, height(Tcontraction), 1);
                Tcontraction.StimIndex = repmat(stimIndex, height(Tcontraction), 1);
                Tcontraction.StimulationFrequency_Hz = repmat(stimulationFrequency_Hz, height(Tcontraction), 1);

                Tcontraction = movevars(Tcontraction, ...
                    {'GroupID','FileName','StimIndex','StimulationFrequency_Hz'}, ...
                    'Before', 1);

                % addVideoInfo for Ttracking
                Ttracking.GroupID = repmat(packName, height(Ttracking), 1);
                Ttracking.FileName = repmat(fileName, height(Ttracking), 1);
                Ttracking.StimIndex = repmat(stimIndex, height(Ttracking), 1);
                Ttracking.StimulationFrequency_Hz = repmat(stimulationFrequency_Hz, height(Ttracking), 1);

                Ttracking = movevars(Ttracking, ...
                    {'GroupID','FileName','StimIndex','StimulationFrequency_Hz'}, ...
                    'Before', 1);

                % addVideoInfo for TcontractionSeries
                TcontractionSeries.GroupID = repmat(packName, height(TcontractionSeries), 1);
                TcontractionSeries.FileName = repmat(fileName, height(TcontractionSeries), 1);
                TcontractionSeries.StimIndex = repmat(stimIndex, height(TcontractionSeries), 1);
                TcontractionSeries.StimulationFrequency_Hz = repmat(stimulationFrequency_Hz, height(TcontractionSeries), 1);

                TcontractionSeries = movevars(TcontractionSeries, ...
                    {'GroupID','FileName','StimIndex','StimulationFrequency_Hz'}, ...
                    'Before', 1);

                % addVideoInfo for TdetectedContractions
                TdetectedContractions.GroupID = repmat(packName, height(TdetectedContractions), 1);
                TdetectedContractions.FileName = repmat(fileName, height(TdetectedContractions), 1);
                TdetectedContractions.StimIndex = repmat(stimIndex, height(TdetectedContractions), 1);
                TdetectedContractions.StimulationFrequency_Hz = repmat(stimulationFrequency_Hz, height(TdetectedContractions), 1);

                TdetectedContractions = movevars(TdetectedContractions, ...
                    {'GroupID','FileName','StimIndex','StimulationFrequency_Hz'}, ...
                    'Before', 1);

                % addVideoInfo for TtrackingSeries
                TtrackingSeries.GroupID = repmat(packName, height(TtrackingSeries), 1);
                TtrackingSeries.FileName = repmat(fileName, height(TtrackingSeries), 1);
                TtrackingSeries.StimIndex = repmat(stimIndex, height(TtrackingSeries), 1);
                TtrackingSeries.StimulationFrequency_Hz = repmat(stimulationFrequency_Hz, height(TtrackingSeries), 1);

                TtrackingSeries = movevars(TtrackingSeries, ...
                    {'GroupID','FileName','StimIndex','StimulationFrequency_Hz'}, ...
                    'Before', 1);

                Tfinal = join(Tcontraction, Ttracking, ...
                    'Keys', {'GroupID','FileName','StimIndex','StimulationFrequency_Hz','Phase'});

                packResults.contractionSummary = [packResults.contractionSummary; Tcontraction];
                packResults.trackingSummary = [packResults.trackingSummary; Ttracking];
                packResults.finalSummary = [packResults.finalSummary; Tfinal];
                packResults.contractionSeries = [packResults.contractionSeries; TcontractionSeries];
                packResults.detectedContractions = [packResults.detectedContractions; TdetectedContractions];
                packResults.trackingSeries = [packResults.trackingSeries; TtrackingSeries];

            end

            % appendResults
            results.contractionSummary = [results.contractionSummary; packResults.contractionSummary];
            results.trackingSummary = [results.trackingSummary; packResults.trackingSummary];
            results.finalSummary = [results.finalSummary; packResults.finalSummary];
            results.contractionSeries = [results.contractionSeries; packResults.contractionSeries];
            results.detectedContractions = [results.detectedContractions; packResults.detectedContractions];
            results.trackingSeries = [results.trackingSeries; packResults.trackingSeries];

        catch ME
            warning('Pack %s failed and was skipped.', packName);
            disp(ME.message);
        end

    end

end