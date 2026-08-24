function results = organiseAndComputeStatistics(results, settings)

    % These tables are prepared for Excel.
    % The most useful sheets are:
    %   01_All_phase_results        -> raw phase results for every video
    %   05_Mean_SD_by_freq_phase    -> mean, SD and SEM across packs
    %   09_Paired_during            -> paired comparison between frequencies


    %% organiseAllResults
    % Sort all tables and create separate tables for Before, During and After.

    % sort ByFrequencyAndPhase for finalSummary
    phaseOrder = nan(numel(results.finalSummary.Phase),1);

    for ph = 1:numel(settings.phaseNames)
        phaseOrder(results.finalSummary.Phase == settings.phaseNames(ph)) = ph;
    end

    results.finalSummary.PhaseOrder = phaseOrder;
    results.finalSummary = sortrows(results.finalSummary, {'GroupID','StimulationFrequency_Hz','PhaseOrder'});
    results.finalSummary.PhaseOrder = [];


    % sort ByFrequencyAndPhase for contractionSummary
    phaseOrder = nan(numel(results.contractionSummary.Phase),1);

    for ph = 1:numel(settings.phaseNames)
        phaseOrder(results.contractionSummary.Phase == settings.phaseNames(ph)) = ph;
    end

    results.contractionSummary.PhaseOrder = phaseOrder;
    results.contractionSummary = sortrows(results.contractionSummary, {'GroupID','StimulationFrequency_Hz','PhaseOrder'});
    results.contractionSummary.PhaseOrder = [];


    % sort ByFrequencyAndPhase for trackingSummary
    phaseOrder = nan(numel(results.trackingSummary.Phase),1);

    for ph = 1:numel(settings.phaseNames)
        phaseOrder(results.trackingSummary.Phase == settings.phaseNames(ph)) = ph;
    end

    results.trackingSummary.PhaseOrder = phaseOrder;
    results.trackingSummary = sortrows(results.trackingSummary, {'GroupID','StimulationFrequency_Hz','PhaseOrder'});
    results.trackingSummary.PhaseOrder = [];

    %sort detected contractions, series of contraction and series of tracking (chain)
    results.detectedContractions = sortrows(results.detectedContractions, ...
        {'GroupID','StimulationFrequency_Hz','Expansion_time_s'});

    results.contractionSeries = sortrows(results.contractionSeries, ...
        {'GroupID','StimulationFrequency_Hz','Time_s'});

    results.trackingSeries = sortrows(results.trackingSeries, ...
        {'GroupID','StimulationFrequency_Hz','Time_s'});
    
    % separate
    results.before = results.finalSummary(results.finalSummary.Phase == "Before", :);
    results.during = results.finalSummary(results.finalSummary.Phase == "During", :);
    results.after = results.finalSummary(results.finalSummary.Phase == "After", :);


    %% computeSummaryStatistics for results.statsByFrequencyPhase

    % Calculate stadistics
    T = results.finalSummary;
    includePhase = true;
    % Possible metrics 
    possibleMetrics = [ ...
        "Contraction_count", ...
        "Mean_contraction_frequency_Hz", ...
        "Std_contraction_frequency_Hz", ...
        "Mean_contraction_period_s", ...
        "Std_contraction_period_s", ...
        "Mean_contraction_displacement_px", ...
        "Std_contraction_displacement_px", ...
        "Max_contraction_displacement_px", ...
        "Mean_contraction_speed_px_s", ...
        "Std_contraction_speed_px_s", ...
        "Max_contraction_speed_px_s", ...
        "Mean_motion_energy_median", ...
        "Mean_motion_energy_p95", ...
        "Mean_displacement_px", ...
        "Std_displacement_px", ...
        "Max_displacement_px", ...
        "Mean_speed_px_s", ...
        "Std_speed_px_s", ...
        "Max_speed_px_s", ...
        "Mean_correlation_score", ...
        "Valid_tracking_fraction"];
    
    %The metrics that exits
    metricMask = ismember(possibleMetrics, string(T.Properties.VariableNames));
    metrics = possibleMetrics(metricMask);

    frequencies = unique(T.StimulationFrequency_Hz, 'stable');
    
    % define phases
    if includePhase
        phases = settings.phaseNames(:);
    else
        phases = "All";
    end

    % empty vectors
    StimulationFrequency_Hz = [];
    Phase = strings(0,1);
    Metric = strings(0,1);
    N = [];
    Mean = [];
    SD = [];
    SEM = [];
    Median = [];
    Min = [];
    Max = [];

    for f = 1:numel(frequencies)
        for ph = 1:numel(phases)
            for m = 1:numel(metrics)

                idx = T.StimulationFrequency_Hz == frequencies(f);

                if includePhase
                    idx = idx & T.Phase == phases(ph);
                end

                values = T.(metrics(m))(idx);
                values = values(~isnan(values));
                n = numel(values);
                
                % keep values
                StimulationFrequency_Hz(end+1,1) = frequencies(f); %#ok<AGROW>
                Phase(end+1,1) = phases(ph); %#ok<AGROW>
                Metric(end+1,1) = metrics(m); %#ok<AGROW>
                N(end+1,1) = n; %#ok<AGROW>
                
                % put nan in empty values
                if n == 0
                    Mean(end+1,1) = NaN; %#ok<AGROW>
                    SD(end+1,1) = NaN; %#ok<AGROW>
                    SEM(end+1,1) = NaN; %#ok<AGROW>
                    Median(end+1,1) = NaN; %#ok<AGROW>
                    Min(end+1,1) = NaN; %#ok<AGROW>
                    Max(end+1,1) = NaN; %#ok<AGROW>
                else
                    Mean(end+1,1) = mean(values, 'omitnan'); %#ok<AGROW>
                    SD(end+1,1) = std(values, 'omitnan'); %#ok<AGROW>
                    SEM(end+1,1) = std(values, 'omitnan') / sqrt(n); %#ok<AGROW>
                    Median(end+1,1) = median(values, 'omitnan'); %#ok<AGROW>
                    Min(end+1,1) = min(values); %#ok<AGROW>
                    Max(end+1,1) = max(values); %#ok<AGROW>
                end
            end
        end
    end

    results.statsByFrequencyPhase = table(StimulationFrequency_Hz, Phase, Metric, N, Mean, SD, SEM, Median, Min, Max);


    %% computeSummaryStatistics for results.statsDuringOnly

    % only during values
    T = results.during;
    includePhase = false;

    possibleMetrics = [ ...
        "Contraction_count", ...
        "Mean_contraction_frequency_Hz", ...
        "Std_contraction_frequency_Hz", ...
        "Mean_contraction_period_s", ...
        "Std_contraction_period_s", ...
        "Mean_contraction_displacement_px", ...
        "Std_contraction_displacement_px", ...
        "Max_contraction_displacement_px", ...
        "Mean_contraction_speed_px_s", ...
        "Std_contraction_speed_px_s", ...
        "Max_contraction_speed_px_s", ...
        "Mean_motion_energy_median", ...
        "Mean_motion_energy_p95", ...
        "Mean_displacement_px", ...
        "Std_displacement_px", ...
        "Max_displacement_px", ...
        "Mean_speed_px_s", ...
        "Std_speed_px_s", ...
        "Max_speed_px_s", ...
        "Mean_correlation_score", ...
        "Valid_tracking_fraction"];

    metricMask = ismember(possibleMetrics, string(T.Properties.VariableNames));
    metrics = possibleMetrics(metricMask);

    frequencies = unique(T.StimulationFrequency_Hz, 'stable');

    if includePhase
        phases = settings.phaseNames(:);
    else
        phases = "All";
    end

    StimulationFrequency_Hz = [];
    Phase = strings(0,1);
    Metric = strings(0,1);
    N = [];
    Mean = [];
    SD = [];
    SEM = [];
    Median = [];
    Min = [];
    Max = [];

    for f = 1:numel(frequencies)
        for ph = 1:numel(phases)
            for m = 1:numel(metrics)

                idx = T.StimulationFrequency_Hz == frequencies(f);

                if includePhase
                    idx = idx & T.Phase == phases(ph);
                end

                values = T.(metrics(m))(idx);
                values = values(~isnan(values));
                n = numel(values);

                StimulationFrequency_Hz(end+1,1) = frequencies(f); %#ok<AGROW>
                Phase(end+1,1) = phases(ph); %#ok<AGROW>
                Metric(end+1,1) = metrics(m); %#ok<AGROW>
                N(end+1,1) = n; %#ok<AGROW>

                if n == 0
                    Mean(end+1,1) = NaN; %#ok<AGROW>
                    SD(end+1,1) = NaN; %#ok<AGROW>
                    SEM(end+1,1) = NaN; %#ok<AGROW>
                    Median(end+1,1) = NaN; %#ok<AGROW>
                    Min(end+1,1) = NaN; %#ok<AGROW>
                    Max(end+1,1) = NaN; %#ok<AGROW>
                else
                    Mean(end+1,1) = mean(values, 'omitnan'); %#ok<AGROW>
                    SD(end+1,1) = std(values, 'omitnan'); %#ok<AGROW>
                    SEM(end+1,1) = std(values, 'omitnan') / sqrt(n); %#ok<AGROW>
                    Median(end+1,1) = median(values, 'omitnan'); %#ok<AGROW>
                    Min(end+1,1) = min(values); %#ok<AGROW>
                    Max(end+1,1) = max(values); %#ok<AGROW>
                end
            end
        end
    end

    results.statsDuringOnly = table(StimulationFrequency_Hz, Phase, Metric, N, Mean, SD, SEM, Median, Min, Max);


    %% computeSummaryStatistics for results.statsBeforeOnly

    % only before values
    T = results.before;
    includePhase = false;

    possibleMetrics = [ ...
        "Contraction_count", ...
        "Mean_contraction_frequency_Hz", ...
        "Std_contraction_frequency_Hz", ...
        "Mean_contraction_period_s", ...
        "Std_contraction_period_s", ...
        "Mean_contraction_displacement_px", ...
        "Std_contraction_displacement_px", ...
        "Max_contraction_displacement_px", ...
        "Mean_contraction_speed_px_s", ...
        "Std_contraction_speed_px_s", ...
        "Max_contraction_speed_px_s", ...
        "Mean_motion_energy_median", ...
        "Mean_motion_energy_p95", ...
        "Mean_displacement_px", ...
        "Std_displacement_px", ...
        "Max_displacement_px", ...
        "Mean_speed_px_s", ...
        "Std_speed_px_s", ...
        "Max_speed_px_s", ...
        "Mean_correlation_score", ...
        "Valid_tracking_fraction"];

    metricMask = ismember(possibleMetrics, string(T.Properties.VariableNames));
    metrics = possibleMetrics(metricMask);

    frequencies = unique(T.StimulationFrequency_Hz, 'stable');

    if includePhase
        phases = settings.phaseNames(:);
    else
        phases = "All";
    end

    StimulationFrequency_Hz = [];
    Phase = strings(0,1);
    Metric = strings(0,1);
    N = [];
    Mean = [];
    SD = [];
    SEM = [];
    Median = [];
    Min = [];
    Max = [];

    for f = 1:numel(frequencies)
        for ph = 1:numel(phases)
            for m = 1:numel(metrics)

                idx = T.StimulationFrequency_Hz == frequencies(f);

                if includePhase
                    idx = idx & T.Phase == phases(ph);
                end

                values = T.(metrics(m))(idx);
                values = values(~isnan(values));
                n = numel(values);

                StimulationFrequency_Hz(end+1,1) = frequencies(f); %#ok<AGROW>
                Phase(end+1,1) = phases(ph); %#ok<AGROW>
                Metric(end+1,1) = metrics(m); %#ok<AGROW>
                N(end+1,1) = n; %#ok<AGROW>

                if n == 0
                    Mean(end+1,1) = NaN; %#ok<AGROW>
                    SD(end+1,1) = NaN; %#ok<AGROW>
                    SEM(end+1,1) = NaN; %#ok<AGROW>
                    Median(end+1,1) = NaN; %#ok<AGROW>
                    Min(end+1,1) = NaN; %#ok<AGROW>
                    Max(end+1,1) = NaN; %#ok<AGROW>
                else
                    Mean(end+1,1) = mean(values, 'omitnan'); %#ok<AGROW>
                    SD(end+1,1) = std(values, 'omitnan'); %#ok<AGROW>
                    SEM(end+1,1) = std(values, 'omitnan') / sqrt(n); %#ok<AGROW>
                    Median(end+1,1) = median(values, 'omitnan'); %#ok<AGROW>
                    Min(end+1,1) = min(values); %#ok<AGROW>
                    Max(end+1,1) = max(values); %#ok<AGROW>
                end
            end
        end
    end

    results.statsBeforeOnly = table(StimulationFrequency_Hz, Phase, Metric, N, Mean, SD, SEM, Median, Min, Max);


    %% computeSummaryStatistics for results.statsAfterOnly

    % only after values
    T = results.after;
    includePhase = false;

    possibleMetrics = [ ...
        "Contraction_count", ...
        "Mean_contraction_frequency_Hz", ...
        "Std_contraction_frequency_Hz", ...
        "Mean_contraction_period_s", ...
        "Std_contraction_period_s", ...
        "Mean_contraction_displacement_px", ...
        "Std_contraction_displacement_px", ...
        "Max_contraction_displacement_px", ...
        "Mean_contraction_speed_px_s", ...
        "Std_contraction_speed_px_s", ...
        "Max_contraction_speed_px_s", ...
        "Mean_motion_energy_median", ...
        "Mean_motion_energy_p95", ...
        "Mean_displacement_px", ...
        "Std_displacement_px", ...
        "Max_displacement_px", ...
        "Mean_speed_px_s", ...
        "Std_speed_px_s", ...
        "Max_speed_px_s", ...
        "Mean_correlation_score", ...
        "Valid_tracking_fraction"];

    metricMask = ismember(possibleMetrics, string(T.Properties.VariableNames));
    metrics = possibleMetrics(metricMask);

    frequencies = unique(T.StimulationFrequency_Hz, 'stable');

    if includePhase
        phases = settings.phaseNames(:);
    else
        phases = "All";
    end

    StimulationFrequency_Hz = [];
    Phase = strings(0,1);
    Metric = strings(0,1);
    N = [];
    Mean = [];
    SD = [];
    SEM = [];
    Median = [];
    Min = [];
    Max = [];

    for f = 1:numel(frequencies)
        for ph = 1:numel(phases)
            for m = 1:numel(metrics)

                idx = T.StimulationFrequency_Hz == frequencies(f);

                if includePhase
                    idx = idx & T.Phase == phases(ph);
                end

                values = T.(metrics(m))(idx);
                values = values(~isnan(values));
                n = numel(values);

                StimulationFrequency_Hz(end+1,1) = frequencies(f); %#ok<AGROW>
                Phase(end+1,1) = phases(ph); %#ok<AGROW>
                Metric(end+1,1) = metrics(m); %#ok<AGROW>
                N(end+1,1) = n; %#ok<AGROW>

                if n == 0
                    Mean(end+1,1) = NaN; %#ok<AGROW>
                    SD(end+1,1) = NaN; %#ok<AGROW>
                    SEM(end+1,1) = NaN; %#ok<AGROW>
                    Median(end+1,1) = NaN; %#ok<AGROW>
                    Min(end+1,1) = NaN; %#ok<AGROW>
                    Max(end+1,1) = NaN; %#ok<AGROW>
                else
                    Mean(end+1,1) = mean(values, 'omitnan'); %#ok<AGROW>
                    SD(end+1,1) = std(values, 'omitnan'); %#ok<AGROW>
                    SEM(end+1,1) = std(values, 'omitnan') / sqrt(n); %#ok<AGROW>
                    Median(end+1,1) = median(values, 'omitnan'); %#ok<AGROW>
                    Min(end+1,1) = min(values); %#ok<AGROW>
                    Max(end+1,1) = max(values); %#ok<AGROW>
                end
            end
        end
    end

    results.statsAfterOnly = table(StimulationFrequency_Hz, Phase, Metric, N, Mean, SD, SEM, Median, Min, Max);


    %% computePairedDuringComparisons

    % only during values in comparison
    Tduring = results.during;

    possibleMetrics = [ ...
        "Contraction_count", ...
        "Mean_contraction_frequency_Hz", ...
        "Std_contraction_frequency_Hz", ...
        "Mean_contraction_period_s", ...
        "Std_contraction_period_s", ...
        "Mean_contraction_displacement_px", ...
        "Std_contraction_displacement_px", ...
        "Max_contraction_displacement_px", ...
        "Mean_contraction_speed_px_s", ...
        "Std_contraction_speed_px_s", ...
        "Max_contraction_speed_px_s", ...
        "Mean_motion_energy_median", ...
        "Mean_motion_energy_p95", ...
        "Mean_displacement_px", ...
        "Std_displacement_px", ...
        "Max_displacement_px", ...
        "Mean_speed_px_s", ...
        "Std_speed_px_s", ...
        "Max_speed_px_s", ...
        "Mean_correlation_score", ...
        "Valid_tracking_fraction"];

    metricMask = ismember(possibleMetrics, string(Tduring.Properties.VariableNames));
    metrics = possibleMetrics(metricMask);

    frequencyPairs = [1 50; 1 100; 50 100];

    Metric = strings(0,1);
    Frequency_A_Hz = [];
    Frequency_B_Hz = [];
    N = [];
    Mean_A = [];
    Mean_B = [];
    Mean_difference_B_minus_A = [];
    SD_difference = [];
    SEM_difference = [];
    Paired_ttest_p = [];

    groupIDs = unique(Tduring.GroupID, 'stable');

    for m = 1:numel(metrics)
        for p = 1:size(frequencyPairs,1)

            freqA = frequencyPairs(p,1);
            freqB = frequencyPairs(p,2);
            valuesA = [];
            valuesB = [];

            for g = 1:numel(groupIDs)
                idxA = Tduring.GroupID == groupIDs(g) & Tduring.StimulationFrequency_Hz == freqA;
                idxB = Tduring.GroupID == groupIDs(g) & Tduring.StimulationFrequency_Hz == freqB;

                if any(idxA) && any(idxB)
                    valueA = Tduring.(metrics(m))(find(idxA,1));
                    valueB = Tduring.(metrics(m))(find(idxB,1));

                    if ~isnan(valueA) && ~isnan(valueB)
                        valuesA(end+1,1) = valueA; %#ok<AGROW>
                        valuesB(end+1,1) = valueB; %#ok<AGROW>
                    end
                end
            end

            differences = valuesB - valuesA;
            n = numel(differences);

            Metric(end+1,1) = metrics(m); %#ok<AGROW>
            Frequency_A_Hz(end+1,1) = freqA; %#ok<AGROW>
            Frequency_B_Hz(end+1,1) = freqB; %#ok<AGROW>
            N(end+1,1) = n; %#ok<AGROW>

            if n == 0
                Mean_A(end+1,1) = NaN; %#ok<AGROW>
                Mean_B(end+1,1) = NaN; %#ok<AGROW>
                Mean_difference_B_minus_A(end+1,1) = NaN; %#ok<AGROW>
                SD_difference(end+1,1) = NaN; %#ok<AGROW>
                SEM_difference(end+1,1) = NaN; %#ok<AGROW>
                Paired_ttest_p(end+1,1) = NaN; %#ok<AGROW>
            else
                Mean_A(end+1,1) = mean(valuesA, 'omitnan'); %#ok<AGROW>
                Mean_B(end+1,1) = mean(valuesB, 'omitnan'); %#ok<AGROW>
                Mean_difference_B_minus_A(end+1,1) = mean(differences, 'omitnan'); %#ok<AGROW>
                SD_difference(end+1,1) = std(differences, 'omitnan'); %#ok<AGROW>
                SEM_difference(end+1,1) = std(differences, 'omitnan') / sqrt(n); %#ok<AGROW>

                if n > 1 && exist('ttest', 'file') == 2
                    [~, pValue] = ttest(valuesB, valuesA);
                    Paired_ttest_p(end+1,1) = pValue; %#ok<AGROW>
                else
                    Paired_ttest_p(end+1,1) = NaN; %#ok<AGROW>
                end
            end
        end
    end

    results.pairedDuringComparisons = table(Metric, Frequency_A_Hz, Frequency_B_Hz, N, ...
        Mean_A, Mean_B, Mean_difference_B_minus_A, SD_difference, SEM_difference, Paired_ttest_p);

end