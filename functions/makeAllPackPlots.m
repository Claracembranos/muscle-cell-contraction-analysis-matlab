function makeAllPackPlots(T, ~, resultFolder, settings)

    % Clear summary plots for phase and stimulation-frequency comparison.
  
    % It creates two figures per metric:
    %   1. Scatter plot with mean +/- SD for each phase and frequency.
    %   2. Heatmap of mean values: phase x frequency.
 

    if isempty(T)
        warning('No final summary results available for plotting.');
        return;
    end
    % folder for plots
    plotFolder = fullfile(resultFolder, 'plots_scatter_mean_sd');

    if ~exist(plotFolder, 'dir')
        mkdir(plotFolder);
    end
    % metrics and labels (y axis)
    metrics = [ ...
        "Mean_contraction_frequency_Hz"; ...
        "Mean_contraction_period_s"; ...
        "Mean_contraction_displacement_px"; ...
        "Mean_contraction_speed_px_s"; ...
        "Mean_displacement_px"; ...
        "Mean_speed_px_s" ...
    ];
    
    yLabels = [ ...
        "Contraction frequency (Hz)"; ...
        "Mean contraction period (s)"; ...
        "Mean contraction displacement (px)"; ...
        "Mean contraction speed (px/s)"; ...
        "Mean displacement from baseline (px)"; ...
        "Mean movement speed (px/s)" ...
    ];
    
    % order of phases
    phaseOrder = string(settings.phaseNames(:))';
    preferredFreqOrder = [1, 50, 100];

    availableFreq = unique(T.StimulationFrequency_Hz(~isnan(T.StimulationFrequency_Hz)))';
    freqOrder = preferredFreqOrder(ismember(preferredFreqOrder, availableFreq));
    extraFreq = setdiff(availableFreq, preferredFreqOrder, 'stable');
    freqOrder = [freqOrder, extraFreq];

    for m = 1:numel(metrics)

        metricName = metrics(m);
        yLabelText = yLabels(m);

        if ~ismember(metricName, string(T.Properties.VariableNames))
            warning('Metric %s was not found in finalSummary and will be skipped.', metricName);
            continue;
        end


        % stadistics matrix
        nPhases = numel(phaseOrder);
        nFreq = numel(freqOrder);

        meanMatrix = nan(nPhases, nFreq);
        sdMatrix = nan(nPhases, nFreq);
        semMatrix = nan(nPhases, nFreq);
        nMatrix = zeros(nPhases, nFreq);

        visualMeanMatrix = nan(nPhases, nFreq);
        visualSdMatrix = nan(nPhases, nFreq);

        for p = 1:nPhases

            for f = 1:nFreq
                
                %selection
                rows = T.StimulationFrequency_Hz == freqOrder(f) & string(T.Phase) == phaseOrder(p);

                values = T.(metricName)(rows);
                values = values(~isnan(values));
                values = values(isfinite(values));

                n = numel(values);
                nMatrix(p, f) = n;

                if n > 0

                    % Full statistics for heatmap and saved results.
                    meanMatrix(p, f) = mean(values, 'omitnan');
                    sdMatrix(p, f) = std(values, 'omitnan');

                    if n > 1
                        semMatrix(p, f) = sdMatrix(p, f) / sqrt(n);
                    else
                        semMatrix(p, f) = 0;
                    end

                    % Remove outliers only for visual mean +/- SD and Y-axis calculation.
                    % Original data are not deleted from the results table or heatmap.

                    cleanValues = values(:);
                    cleanValues = cleanValues(~isnan(cleanValues));
                    cleanValues = cleanValues(isfinite(cleanValues));

                    if numel(cleanValues) >= 4

                        outlierIdx = isoutlier(cleanValues, 'quartiles');
                        cleanValuesNoOutliers = cleanValues(~outlierIdx);

                        if numel(cleanValuesNoOutliers) >= 3
                            cleanValues = cleanValuesNoOutliers;
                        end

                    end

                    visualMeanMatrix(p, f) = mean(cleanValues, 'omitnan');
                    visualSdMatrix(p, f) = std(cleanValues, 'omitnan');

                    if isnan(visualSdMatrix(p, f)) || visualSdMatrix(p, f) == 0
                        visualSdMatrix(p, f) = max(abs(visualMeanMatrix(p, f)) * 0.20, 1e-6);
                    end

                end

            end

        end


        %  make scatter plots
        if ~all(isnan(visualMeanMatrix), 'all')

            fig = figure('Color', 'w', 'Position', [100, 100, 1050, 560]);
            hold on;

            xBase = 1:nPhases;

            if nFreq == 1
                offsets = 0;
            else
                offsets = linspace(-0.25, 0.25, nFreq);
            end

            colors = lines(nFreq);
            legendHandles = gobjects(nFreq, 1);

            rng(1);

            for f = 1:nFreq

                freq = freqOrder(f);

                for p = 1:nPhases

                    phaseName = phaseOrder(p);

                    rows = T.StimulationFrequency_Hz == freq & string(T.Phase) == phaseName;

                    values = T.(metricName)(rows);
                    values = values(~isnan(values));
                    values = values(isfinite(values));

                    if isempty(values)
                        continue;
                    end

                    xCenter = xBase(p) + offsets(f);

                    jitter = (rand(size(values)) - 0.5) * 0.08;

                    hScatter = scatter(xCenter + jitter, values, 42, ...
                        'filled', ...
                        'MarkerFaceColor', colors(f, :), ...
                        'MarkerEdgeColor', colors(f, :), ...
                        'MarkerFaceAlpha', 0.55, ...
                        'MarkerEdgeAlpha', 0.55);

                    if p == 1
                        legendHandles(f) = hScatter;
                    else
                        hScatter.HandleVisibility = 'off';
                    end

                    meanValue = visualMeanMatrix(p, f);
                    sdValue = visualSdMatrix(p, f);

                    if isnan(meanValue) || isnan(sdValue)
                        continue;
                    end

                    % Mean +/- SD rectangle
                    boxWidth = 0.20;
                    
                    boxBottom = meanValue - sdValue;
                    boxTop = meanValue + sdValue;
                    
                    % Avoid negative visual limits for positive variables
                    positiveMetrics = [
                        "Peak_count"
                        "Peak_frequency_Hz"
                        "Mean_period_s"
                        "Mean_peak_value"
                        "Mean_displacement_px"
                        "Mean_speed_px_s"
                        "Max_displacement_px"
                        "Max_speed_px_s"
                    ];
                    
                    if any(strcmp(metricName, positiveMetrics))
                        boxBottom = max(0, boxBottom);
                    end
                    
                    boxHeight = boxTop - boxBottom;
                    
                    if boxHeight <= 0 || isnan(boxHeight)
                        boxHeight = max(abs(meanValue) * 0.15, 1e-6);
                        boxBottom = meanValue - boxHeight/2;
                    end
                    
                    % draw the rectangle
                    rectangle('Position', [xCenter - boxWidth/2, boxBottom, boxWidth, boxHeight], ...
                        'FaceColor', colors(f, :), ...
                        'FaceAlpha', 0.22, ...
                        'EdgeColor', colors(f, :), ...
                        'LineWidth', 1.6);
                    
                    % Mean horizontal line inside the rectangle
                    plot([xCenter - boxWidth/2, xCenter + boxWidth/2], ...
                         [meanValue, meanValue], ...
                         'Color', colors(f, :), ...
                         'LineWidth', 2.4, ...
                         'HandleVisibility', 'off');
                    
                    % Optional black caps at mean +/- SD
                    plot([xCenter - boxWidth/2, xCenter + boxWidth/2], ...
                         [boxBottom, boxBottom], ...
                         'Color', colors(f, :), ...
                         'LineWidth', 1.4, ...
                         'HandleVisibility', 'off');
                    
                    plot([xCenter - boxWidth/2, xCenter + boxWidth/2], ...
                         [boxTop, boxTop], ...
                         'Color', colors(f, :), ...
                         'LineWidth', 1.4, ...
                         'HandleVisibility', 'off');

                end

            end

            % set axis and title
            xticks(xBase);
            xticklabels(phaseOrder);

            xlabel('Experimental phase');
            ylabel(yLabelText);

            title(sprintf('%s: individual values with mean ± SD', yLabelText), ...
                'FontWeight', 'bold');

            validLegend = isgraphics(legendHandles);

            if any(validLegend)
                legend(legendHandles(validLegend), compose('%g Hz', freqOrder(validLegend)), ...
                    'Location', 'bestoutside');
            end


            %get Y Limits From Mean SD
            meanValues = visualMeanMatrix(:);
            sdValues = visualSdMatrix(:);

            valid = ~isnan(meanValues) & isfinite(meanValues) & ~isnan(sdValues) & isfinite(sdValues);

            meanValues = meanValues(valid);
            sdValues = sdValues(valid);

            if isempty(meanValues)

                yLimits = [0 1];

            else

                lowerCandidates = meanValues - sdValues;
                upperCandidates = meanValues + sdValues;

                lowerLimit = min(lowerCandidates);
                upperLimit = max(upperCandidates);

                positiveMetrics = [
                    "Peak_count"
                    "Peak_frequency_Hz"
                    "Mean_period_s"
                    "Mean_peak_value"
                    "Mean_displacement_px"
                    "Mean_speed_px_s"
                    "Max_displacement_px"
                    "Max_speed_px_s"
                ];

                if any(strcmp(metricName, positiveMetrics))
                    lowerLimit = 0;
                end

                yRange = upperLimit - lowerLimit;

                if yRange <= 0 || isnan(yRange)
                    yRange = max(abs(upperLimit), 1);
                end

                upperLimit = upperLimit + 0.15 * yRange;

                if ~any(strcmp(metricName, positiveMetrics))
                    lowerLimit = lowerLimit - 0.05 * yRange;
                end

                yLimits = [lowerLimit upperLimit];

            end

            ylim(yLimits);

            xlim([0.5, nPhases + 0.5]);

            grid on;
            box on;

            set(gca, 'FontSize', 12, 'LineWidth', 1);

            subtitle('Dots represent individual video packs. Black line shows mean ± SD.');


            % savePlot for scatter plot
            fileBaseName = "01_scatter_mean_sd_" + metricName;

            pngPath = fullfile(plotFolder, char(fileBaseName + ".png"));
            figPath = fullfile(plotFolder, char(fileBaseName + ".fig"));

            try
                exportgraphics(fig, pngPath, 'Resolution', 300);
            catch
                saveas(fig, pngPath);
            end

            try
                savefig(fig, figPath);
            catch
                warning('The .fig version could not be saved for %s.', fileBaseName);
            end

            close(fig);

        end


        % make freq heat map
        if all(isnan(meanMatrix), 'all')
            continue;
        end

        fig = figure('Color', 'w', 'Position', [100, 100, 740, 520]);

        imagesc(meanMatrix, 'AlphaData', ~isnan(meanMatrix));
        axis tight;

        colormap(parula);

        c = colorbar;
        c.Label.String = yLabelText;
        c.Label.FontSize = 11;

        % axis of heatmap
        xticks(1:numel(freqOrder));
        xticklabels(compose('%g Hz', freqOrder));

        yticks(1:numel(phaseOrder));
        yticklabels(phaseOrder);

        xlabel('Stimulation frequency');
        ylabel('Experimental phase');

        title(sprintf('%s: mean value heatmap', yLabelText), 'FontWeight', 'bold');

        set(gca, 'FontSize', 12, 'LineWidth', 1);

        finiteValues = meanMatrix(~isnan(meanMatrix));

        if isempty(finiteValues)

            fileBaseName = "02_heatmap_" + metricName;

            pngPath = fullfile(plotFolder, char(fileBaseName + ".png"));
            figPath = fullfile(plotFolder, char(fileBaseName + ".fig"));

            try
                exportgraphics(fig, pngPath, 'Resolution', 300);
            catch
                saveas(fig, pngPath);
            end

            try
                savefig(fig, figPath);
            catch
                warning('The .fig version could not be saved for %s.', fileBaseName);
            end

            close(fig);

            continue;

        end

        colorMidPoint = (min(finiteValues) + max(finiteValues)) / 2;

        for p = 1:numel(phaseOrder)

            for f = 1:numel(freqOrder)

                value = meanMatrix(p, f);

                if isnan(value)

                    labelText = "n/a";
                    textColor = 'k';

                else

                    % format Numbers
                    absValue = abs(value);

                    if absValue >= 100
                        labelText = string(sprintf('%.0f', value));
                    elseif absValue >= 10
                        labelText = string(sprintf('%.1f', value));
                    elseif absValue >= 1
                        labelText = string(sprintf('%.2f', value));
                    else
                        labelText = string(sprintf('%.3f', value));
                    end

                    if value > colorMidPoint
                        textColor = 'w';
                    else
                        textColor = 'k';
                    end

                end

                text(f, p, labelText, ...
                    'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'middle', ...
                    'Color', textColor, ...
                    'FontSize', 11, ...
                    'FontWeight', 'bold');

            end

        end


        %savePlot for heatmap
        fileBaseName = "02_heatmap_" + metricName;

        pngPath = fullfile(plotFolder, char(fileBaseName + ".png"));
        figPath = fullfile(plotFolder, char(fileBaseName + ".fig"));

        try
            exportgraphics(fig, pngPath, 'Resolution', 300);
        catch
            saveas(fig, pngPath);
        end

        try
            savefig(fig, figPath);
        catch
            warning('The .fig version could not be saved for %s.', fileBaseName);
        end

        close(fig);

    end

end