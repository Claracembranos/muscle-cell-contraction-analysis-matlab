function [resultFolder, excelFile] = createAnalysisFolders(mainFolder)

    % One timestamped folder is created for the full batch analysis.
    resultFolder = fullfile(mainFolder, ['all_packs_results_' datestr(now,'yyyymmdd_HHMMSS')]);
    mkdir(resultFolder);

    excelFile = fullfile(resultFolder, 'all_packs_results.xlsx'); %Keep the complete path for the Excel file.
end
