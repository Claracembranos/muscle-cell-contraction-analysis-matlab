function [Tcontraction, Ttracking, TcontractionSeries, TdetectedContractions, TtrackingSeries] = runContractionMovementAnalysis( ...
    frames, cellMask, timeVec, fps, patchBox0, frameRef, ...
    phaseNames, phaseStart, phaseEnd)

    % Combined contraction and movement analysis.
    %
    % It first tracks the selected cellular pattern using template matching.
    % Then it detects contraction cycles from the displacement signal.
    %
    % A contraction cycle is defined as:
    %   maximum expansion displacement -> following minimum contraction displacement
 

    [H, W, nFrames] = size(frames);
    timeTrack = timeVec(:); % time vector to column

    %% 1. Template tracking

    searchRadius_px = 18;
    minCorrelation = 0.35;
    smoothWindow = 3;
    templateUpdateAlpha = 0.02;

    x = round(patchBox0(1));
    y = round(patchBox0(2));
    bw = round(patchBox0(3));
    bh = round(patchBox0(4));

    x = max(1, min(W, x));
    y = max(1, min(H, y));

    bw = max(5, bw);
    bh = max(5, bh);

    if x + bw - 1 > W
        bw = W - x + 1;
    end

    if y + bh - 1 > H
        bh = H - y + 1;
    end

    refFrame = frames(:,:,frameRef);
    template = refFrame(y:y+bh-1, x:x+bw-1);

    if std(template(:), 'omitnan') < 1e-6
        error('The selected cellular template has too little contrast. Select a more textured region of the cell.');
    end
    
    % Tracking variables
    centerX = nan(nFrames,1);
    centerY = nan(nFrames,1);
    topLeftX = nan(nFrames,1);
    topLeftY = nan(nFrames,1);
    correlationScore = nan(nFrames,1);
    validTracking = zeros(nFrames,1);

    topLeftX(frameRef) = x;
    topLeftY(frameRef) = y;

    centerX(frameRef) = x + (bw - 1)/2;
    centerY(frameRef) = y + (bh - 1)/2;

    correlationScore(frameRef) = 1;
    validTracking(frameRef) = 1;

    previousX = x;
    previousY = y;

    for k = frameRef+1:nFrames

        if mod(k,100) == 0
            fprintf('      Contraction tracking frame %d/%d\n', k, nFrames);
        end

        currentFrame = frames(:,:,k);

        searchX1 = max(1, round(previousX - searchRadius_px));
        searchY1 = max(1, round(previousY - searchRadius_px));

        searchX2 = min(W, round(previousX + bw - 1 + searchRadius_px));
        searchY2 = min(H, round(previousY + bh - 1 + searchRadius_px));

        searchImg = currentFrame(searchY1:searchY2, searchX1:searchX2);

        if size(searchImg,1) < bh || size(searchImg,2) < bw

            topLeftX(k) = topLeftX(k-1);
            topLeftY(k) = topLeftY(k-1);
            centerX(k) = centerX(k-1);
            centerY(k) = centerY(k-1);
            correlationScore(k) = NaN;
            validTracking(k) = 0;

            continue;
        end
        
        % Compare the search image with the template
        c = normxcorr2(template, searchImg);
        c(~isfinite(c)) = -Inf;

        [maxCorr, maxIdx] = max(c(:));
        [peakY, peakX] = ind2sub(size(c), maxIdx);

        [subDx, subDy] = getSubpixelPeakOffset(c, peakX, peakY);

        peakXsub = peakX + subDx;
        peakYsub = peakY + subDy;

        localX = peakXsub - bw + 1;
        localY = peakYsub - bh + 1;

        localX = max(1, min(size(searchImg,2) - bw + 1, localX));
        localY = max(1, min(size(searchImg,1) - bh + 1, localY));

        newX = searchX1 + localX - 1;
        newY = searchY1 + localY - 1;

        if maxCorr >= minCorrelation

            topLeftX(k) = newX;
            topLeftY(k) = newY;

            centerX(k) = newX + (bw - 1)/2;
            centerY(k) = newY + (bh - 1)/2;

            correlationScore(k) = maxCorr;
            validTracking(k) = 1;

            previousX = newX;
            previousY = newY;

            newPatch = currentFrame(round(newY):round(newY)+bh-1, round(newX):round(newX)+bw-1);

            if all(size(newPatch) == size(template))
                template = (1 - templateUpdateAlpha) * template + templateUpdateAlpha * newPatch;
            end

        else

            topLeftX(k) = topLeftX(k-1);
            topLeftY(k) = topLeftY(k-1);

            centerX(k) = centerX(k-1);
            centerY(k) = centerY(k-1);

            correlationScore(k) = maxCorr;
            validTracking(k) = 0;
        end
    end

    for k = frameRef-1:-1:1
        topLeftX(k) = topLeftX(frameRef);
        topLeftY(k) = topLeftY(frameRef);
        centerX(k) = centerX(frameRef);
        centerY(k) = centerY(frameRef);
        correlationScore(k) = correlationScore(frameRef);
        validTracking(k) = validTracking(frameRef);
    end
    
    % Smoothing the trayectory
    centerX_smooth = movmedian(centerX, smoothWindow, 'omitnan');
    centerY_smooth = movmedian(centerY, smoothWindow, 'omitnan');

    %% 2. Displacement and speed from tracked cellular pattern
    
    % Calculate the baseline before stimulation
    baselineIdx = timeTrack < 10;

    if any(baselineIdx)
        x0 = median(centerX_smooth(baselineIdx), 'omitnan');
        y0 = median(centerY_smooth(baselineIdx), 'omitnan');
    else
        x0 = centerX_smooth(frameRef);
        y0 = centerY_smooth(frameRef);
    end
    
    % Calculate the displacement from baseline
    DispX_px = centerX_smooth - x0;
    DispY_px = centerY_smooth - y0;

    Displacement_px = sqrt(DispX_px.^2 + DispY_px.^2);
    
    % Velocity frame to frame
    dx = [NaN; diff(centerX_smooth)];
    dy = [NaN; diff(centerY_smooth)];

    Speed_px_s = sqrt(dx.^2 + dy.^2) * fps;

    %% 3. Motion energy inside the cell mask

    Motion_energy_median = nan(nFrames,1);
    Motion_energy_p95 = nan(nFrames,1);

    for k = 2:nFrames

        diffImg = abs(frames(:,:,k) - frames(:,:,k-1));
        values = diffImg(cellMask);

        Motion_energy_median(k) = median(values, 'omitnan');
        Motion_energy_p95(k) = prctile(values, 95);
    end

    %%  4. Detect contraction cycles from dominant movement signal
    
    % It builds a cleaner contraction signal from the tracked position.
    % It projects the XY trajectory onto the dominant movement axis and removes
    % slow drift. This is good when the cell moves laterally.
    
    contractionSignal = buildDominantMotionSignal( ...
        centerX_smooth, centerY_smooth, timeTrack, ...
        phaseStart, phaseEnd, fps);
    
    % Robust noise estimation from the Before phase
    baselineIdxSignal = timeTrack < 10;
    baselineSignal = contractionSignal(baselineIdxSignal);
    
    if numel(baselineSignal) >= 5
        baselineMedian = median(baselineSignal, 'omitnan');
        baselineMAD = median(abs(baselineSignal - baselineMedian), 'omitnan');
        baselineNoise = 1.4826 * baselineMAD;
    else
        signalMedian = median(contractionSignal, 'omitnan');
        signalMAD = median(abs(contractionSignal - signalMedian), 'omitnan');
        baselineNoise = 1.4826 * signalMAD;
    end
    
    % Prominence umbral
    signalRange = prctile(contractionSignal, 95) - prctile(contractionSignal, 5);
    
    minProminence_px = max([0.03, 2.5 * baselineNoise, 0.08 * signalRange]);
    minDistance_s = max(3/fps, 0.12);
    
    % Expansion maxima
    [expansionMaxValues, expansionMaxTimes] = findpeaks(contractionSignal, timeTrack, ...
        'MinPeakProminence', minProminence_px, ...
        'MinPeakDistance', minDistance_s);
    
    % Contraction minima
    [minInvertedValues, contractionMinTimes] = findpeaks(-contractionSignal, timeTrack, ...
        'MinPeakProminence', minProminence_px, ...
        'MinPeakDistance', minDistance_s);
    
    contractionMinValues = -minInvertedValues;
    
    ContractionID = [];
    Expansion_time_s = [];
    Contraction_time_s = [];
    Expansion_max_px = [];
    Contraction_min_px = [];
    Contraction_displacement_px = [];
    Contraction_duration_s = [];
    Contraction_period_s = [];
    Contraction_frequency_Hz = [];
    Contraction_speed_px_s = [];
    Mean_cycle_correlation_score = [];
    Mean_cycle_valid_tracking = [];
    Phase = strings(0,1);
    
    % Pair max and min of contraction
    contractionCounter = 0;
    
    for i = 1:numel(expansionMaxTimes)
    
        tExpansion = expansionMaxTimes(i);
        valueExpansion = expansionMaxValues(i);
    
        % Find the next contraction minimum after the expansion maximum
        nextMinIdx = find(contractionMinTimes > tExpansion, 1, 'first');
    
        if isempty(nextMinIdx)
            continue;
        end
    
        tContraction = contractionMinTimes(nextMinIdx);
        valueContraction = contractionMinValues(nextMinIdx);
        
        % Amplitude
        contractionAmplitude = valueExpansion - valueContraction;
    
        if contractionAmplitude < minProminence_px
            continue;
        end
        
        %Period of contraction
        contractionDuration = tContraction - tExpansion;
    
        if contractionDuration <= 0
            continue;
        end
    
        % Period is calculated from one expansion maximum to the next expansion maximum
        if i < numel(expansionMaxTimes)
            periodValue = expansionMaxTimes(i+1) - expansionMaxTimes(i);
        else
            periodValue = NaN;
        end
    
        if ~isnan(periodValue) && periodValue > 0
            frequencyValue = 1 / periodValue;
        else
            frequencyValue = NaN;
        end
    
        % Quality control: avoid cycles where tracking was poor
        idxCycle = timeTrack >= tExpansion & timeTrack <= tContraction;
    
        if any(idxCycle)
            cycleCorrelation = mean(correlationScore(idxCycle), 'omitnan');
            cycleValidTracking = mean(validTracking(idxCycle), 'omitnan');
        else
            cycleCorrelation = NaN;
            cycleValidTracking = NaN;
        end
    
        if ~isnan(cycleValidTracking) && cycleValidTracking < 0.50
            continue;
        end
    
        contractionCounter = contractionCounter + 1;
    
        ContractionID(end+1,1) = contractionCounter; %#ok<AGROW>
        Expansion_time_s(end+1,1) = tExpansion; %#ok<AGROW>
        Contraction_time_s(end+1,1) = tContraction; %#ok<AGROW>
        Expansion_max_px(end+1,1) = valueExpansion; %#ok<AGROW>
        Contraction_min_px(end+1,1) = valueContraction; %#ok<AGROW>
        Contraction_displacement_px(end+1,1) = contractionAmplitude; %#ok<AGROW>
        Contraction_duration_s(end+1,1) = contractionDuration; %#ok<AGROW>
        Contraction_period_s(end+1,1) = periodValue; %#ok<AGROW>
        Contraction_frequency_Hz(end+1,1) = frequencyValue; %#ok<AGROW>
        Contraction_speed_px_s(end+1,1) = contractionAmplitude / contractionDuration; %#ok<AGROW>
        Mean_cycle_correlation_score(end+1,1) = cycleCorrelation; %#ok<AGROW>
        Mean_cycle_valid_tracking(end+1,1) = cycleValidTracking; %#ok<AGROW>
    
        Phase(end+1,1) = getPhaseName(tExpansion, phaseNames, phaseStart, phaseEnd); %#ok<AGROW>
    
    end
    
    TdetectedContractions = table( ...
        ContractionID, ...
        Expansion_time_s, ...
        Contraction_time_s, ...
        Expansion_max_px, ...
        Contraction_min_px, ...
        Contraction_displacement_px, ...
        Contraction_duration_s, ...
        Contraction_period_s, ...
        Contraction_frequency_Hz, ...
        Contraction_speed_px_s, ...
        Mean_cycle_correlation_score, ...
        Mean_cycle_valid_tracking, ...
        Phase);

    %% 5. Phase summaries for contraction
    
    nPhases = numel(phaseNames);
    
    Contraction_count = nan(nPhases,1);
    
    % Frequency of contraction
    Mean_contraction_frequency_Hz = nan(nPhases,1);
    Std_contraction_frequency_Hz = nan(nPhases,1);
    
    Mean_contraction_period_s = nan(nPhases,1);
    Std_contraction_period_s = nan(nPhases,1);
    
    % Displacement of contraction for each phase (important for the change
    % of amplitude in contractions between phases)
    % No measurement of lateral movements 
    Mean_contraction_displacement_px = nan(nPhases,1);
    Std_contraction_displacement_px = nan(nPhases,1);
    Max_contraction_displacement_px = nan(nPhases,1);
    
    % Mean velocity of each contraction
    Mean_contraction_speed_px_s = nan(nPhases,1);
    Std_contraction_speed_px_s = nan(nPhases,1);
    Max_contraction_speed_px_s = nan(nPhases,1);
    
    % Calculate the change of the mask
    Mean_motion_energy_median = nan(nPhases,1);
    Mean_motion_energy_p95 = nan(nPhases,1);
    
    for ph = 1:nPhases
    
        idxPhaseTime = timeTrack >= phaseStart(ph) & timeTrack < phaseEnd(ph);
    
        idxContractions = Expansion_time_s >= phaseStart(ph) & Expansion_time_s < phaseEnd(ph);
    
        phasePeriods = Contraction_period_s(idxContractions);
        phaseFrequencies = Contraction_frequency_Hz(idxContractions);
        phaseAmplitudes = Contraction_displacement_px(idxContractions);
        phaseSpeeds = Contraction_speed_px_s(idxContractions);
    
        phasePeriods = phasePeriods(~isnan(phasePeriods));
        phaseFrequencies = phaseFrequencies(~isnan(phaseFrequencies));
        
        % Counter of contractions per phase
        Contraction_count(ph) = numel(phaseAmplitudes);
    
        if ~isempty(phaseFrequencies)
            Mean_contraction_frequency_Hz(ph) = mean(phaseFrequencies, 'omitnan');
            Std_contraction_frequency_Hz(ph) = std(phaseFrequencies, 'omitnan');
        end
    
        if ~isempty(phasePeriods)
            Mean_contraction_period_s(ph) = mean(phasePeriods, 'omitnan');
            Std_contraction_period_s(ph) = std(phasePeriods, 'omitnan');
        end
    
        if ~isempty(phaseAmplitudes)
            Mean_contraction_displacement_px(ph) = mean(phaseAmplitudes, 'omitnan');
            Std_contraction_displacement_px(ph) = std(phaseAmplitudes, 'omitnan');
            Max_contraction_displacement_px(ph) = max(phaseAmplitudes);
        end
    
        if ~isempty(phaseSpeeds)
            Mean_contraction_speed_px_s(ph) = mean(phaseSpeeds, 'omitnan');
            Std_contraction_speed_px_s(ph) = std(phaseSpeeds, 'omitnan');
            Max_contraction_speed_px_s(ph) = max(phaseSpeeds);
        end
    
        Mean_motion_energy_median(ph) = mean(Motion_energy_median(idxPhaseTime), 'omitnan');
        Mean_motion_energy_p95(ph) = mean(Motion_energy_p95(idxPhaseTime), 'omitnan');
    
    end
    
    Phase = phaseNames(:);
    
    Tcontraction = table(Phase, ...
        Contraction_count, ...
        Mean_contraction_frequency_Hz, Std_contraction_frequency_Hz, ...
        Mean_contraction_period_s, Std_contraction_period_s, ...
        Mean_contraction_displacement_px, Std_contraction_displacement_px, Max_contraction_displacement_px, ...
        Mean_contraction_speed_px_s, Std_contraction_speed_px_s, Max_contraction_speed_px_s, ...
        Mean_motion_energy_median, Mean_motion_energy_p95);


    %%  6. Phase summaries for global movement

    % Taking into account lateral movements
    Mean_displacement_px = nan(nPhases,1);
    Std_displacement_px = nan(nPhases,1);
    Max_displacement_px = nan(nPhases,1);

    Mean_speed_px_s = nan(nPhases,1);
    Std_speed_px_s = nan(nPhases,1);
    Max_speed_px_s = nan(nPhases,1);

    Mean_correlation_score = nan(nPhases,1);
    Valid_tracking_fraction = nan(nPhases,1);

    for ph = 1:nPhases

        idxPhase = timeTrack >= phaseStart(ph) & timeTrack < phaseEnd(ph);

        Mean_displacement_px(ph) = mean(Displacement_px(idxPhase), 'omitnan');
        Std_displacement_px(ph) = std(Displacement_px(idxPhase), 'omitnan');
        Max_displacement_px(ph) = max(Displacement_px(idxPhase));

        Mean_speed_px_s(ph) = mean(Speed_px_s(idxPhase), 'omitnan');
        Std_speed_px_s(ph) = std(Speed_px_s(idxPhase), 'omitnan');
        Max_speed_px_s(ph) = max(Speed_px_s(idxPhase));

        Mean_correlation_score(ph) = mean(correlationScore(idxPhase), 'omitnan');
        Valid_tracking_fraction(ph) = mean(validTracking(idxPhase), 'omitnan');
    end

    Ttracking = table(Phase, ...
        Mean_displacement_px, Std_displacement_px, Max_displacement_px, ...
        Mean_speed_px_s, Std_speed_px_s, Max_speed_px_s, ...
        Mean_correlation_score, Valid_tracking_fraction);

    %%  7. Time series

    TcontractionSeries = table( ...
        timeTrack, ...
        contractionSignal, ...
        Motion_energy_median, ...
        Motion_energy_p95, ...
        'VariableNames', { ...
        'Time_s', ...
        'Contraction_signal_px', ...
        'Motion_energy_median', ...
        'Motion_energy_p95'});

    TtrackingSeries = table( ...
        timeTrack, ...
        centerX_smooth, ...
        centerY_smooth, ...
        DispX_px, ...
        DispY_px, ...
        Displacement_px, ...
        Speed_px_s, ...
        correlationScore, ...
        validTracking, ...
        'VariableNames', { ...
        'Time_s', ...
        'CenterX_px', ...
        'CenterY_px', ...
        'DispX_px', ...
        'DispY_px', ...
        'Displacement_px', ...
        'Speed_px_s', ...
        'Correlation_score', ...
        'Valid_tracking'});

end


function [subDx, subDy] = getSubpixelPeakOffset(c, peakX, peakY)

    subDx = 0;
    subDy = 0;

    [H, W] = size(c);

    if peakX > 1 && peakX < W

        leftVal = c(peakY, peakX-1);
        centerVal = c(peakY, peakX);
        rightVal = c(peakY, peakX+1);

        denom = leftVal - 2*centerVal + rightVal;

        if abs(denom) > eps
            subDx = 0.5 * (leftVal - rightVal) / denom;
        end
    end

    if peakY > 1 && peakY < H

        topVal = c(peakY-1, peakX);
        centerVal = c(peakY, peakX);
        bottomVal = c(peakY+1, peakX);

        denom = topVal - 2*centerVal + bottomVal;

        if abs(denom) > eps
            subDy = 0.5 * (topVal - bottomVal) / denom;
        end
    end

    subDx = max(-1, min(1, subDx));
    subDy = max(-1, min(1, subDy));

end


function phaseName = getPhaseName(t, phaseNames, phaseStart, phaseEnd)

    phaseName = "Outside";

    for ph = 1:numel(phaseNames)
        if t >= phaseStart(ph) && t < phaseEnd(ph)
            phaseName = phaseNames(ph);
            return;
        end
    end

end

function contractionSignal = buildDominantMotionSignal( ...
    centerX_smooth, centerY_smooth, timeTrack, phaseStart, phaseEnd, fps)

    % Build a signed contraction signal from the tracked XY trajectory.
    % The signal is the projection of movement onto the dominant movement axis.
    % Slow drift is removed so that contraction cycles are easier to detect.

    x = centerX_smooth(:);
    y = centerY_smooth(:);

    valid = isfinite(x) & isfinite(y);

    % Prefer the During phase to estimate the dominant contraction direction.
    duringIdx = timeTrack >= phaseStart(2) & timeTrack < phaseEnd(2) & valid;

    if sum(duringIdx) < 5
        duringIdx = valid;
    end

    xyDuring = [x(duringIdx), y(duringIdx)];
    xyDuring = xyDuring - median(xyDuring, 1, 'omitnan');

    if size(xyDuring,1) >= 3
        [~, ~, V] = svd(xyDuring, 'econ');
        motionAxis = V(:,1);
    else
        motionAxis = [1; 0];
    end

    xyAll = [x, y];
    xyReference = median(xyAll(duringIdx,:), 1, 'omitnan');

    signedSignal = (xyAll - xyReference) * motionAxis;

    % Orient the signal so that the dominant deflection is positive.
    validDuringSignal = signedSignal(duringIdx);

    if numel(validDuringSignal) >= 5
        positiveDeflection = prctile(validDuringSignal, 95);
        negativeDeflection = abs(prctile(validDuringSignal, 5));

        if negativeDeflection > positiveDeflection
            signedSignal = -signedSignal;
        end
    end

    % Remove slow drift.
    trendWindow_s = 1.5;
    trendWindow_frames = max(5, round(trendWindow_s * fps));

    if mod(trendWindow_frames, 2) == 0
        trendWindow_frames = trendWindow_frames + 1;
    end

    slowTrend = movmedian(signedSignal, trendWindow_frames, 'omitnan');
    contractionSignal = signedSignal - slowTrend;

    % Smooth only slightly. Too much smoothing removes true contractions.
    contractionSignal = movmedian(contractionSignal, 3, 'omitnan');

end