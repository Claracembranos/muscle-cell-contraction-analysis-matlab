function saveAllResults(results, videoTable, videoPacks, sharedSelections, settings, resultFolder, excelFile)

% Write Excel results
    readme = {
        'Cell analysis results for all video packs';
        ['Created: ' datestr(now)];
        '';
        'StimIndex 1 = 1 Hz';
        'StimIndex 2 = 50 Hz';
        'StimIndex 3 = 100 Hz';
        '';
        'Each pack is analysed with one shared ROI, one shared cell mask and one shared tracking box.';
        'Contraction metrics come from expansion-contraction cycles detected in the displacement signal.';
        'Movement metrics come from template tracking of the selected cellular pattern.';
        '';
        'Main raw sheet: 01_All_phase_results';
        'Main statistics sheet: 05_Mean_SD_by_freq_phase';
        'Main paired comparison sheet: 09_Paired_during';
        };

    writecell(readme, excelFile, 'Sheet', '00_Read_me');
    writetable(results.finalSummary, excelFile, 'Sheet', '01_All_phase_results');
    writetable(results.during, excelFile, 'Sheet', '02_During_only');
    writetable(results.before, excelFile, 'Sheet', '03_Before_only');
    writetable(results.after, excelFile, 'Sheet', '04_After_only');
    writetable(results.statsByFrequencyPhase, excelFile, 'Sheet', '05_Mean_SD_by_freq_phase');
    writetable(results.statsDuringOnly, excelFile, 'Sheet', '06_Stats_during_only');
    writetable(results.statsBeforeOnly, excelFile, 'Sheet', '07_Stats_before_only');
    writetable(results.statsAfterOnly, excelFile, 'Sheet', '08_Stats_after_only');
    writetable(results.pairedDuringComparisons, excelFile, 'Sheet', '09_Paired_during');
    writetable(results.contractionSummary, excelFile, 'Sheet', '10_Contraction_frequency');
    writetable(results.trackingSummary, excelFile, 'Sheet', '11_Displacement_speed');
    writetable(results.contractionSeries, excelFile, 'Sheet', '12_Contraction_signal');
    writetable(results.detectedContractions, excelFile, 'Sheet', '13_Detected_contractions');
    writetable(results.trackingSeries, excelFile, 'Sheet', '14_Tracking_series');


    % Save workspace results
    save(fullfile(resultFolder, 'all_packs_workspace.mat'), ...
        'results', 'videoTable', 'videoPacks', 'sharedSelections', 'settings');

end