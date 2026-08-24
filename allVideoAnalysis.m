clear; close all; clc;

%% Main settings

% This script analyses all complete video packs inside the OFICIAL folder.
% Each pack contains three videos with the same base name:

%   vidA (1) -> 1 Hz
%   vidA (2) -> 50 Hz
%   vidA (3) -> 100 Hz

% The workflow is separated into four clear steps:
%   1. Find complete video packs and create the result folder.
%   2. Select all manual regions for each pack.
%   3. Analyse all videos automatically.
%   4. Organise, save and plot the results.

settings.mainFolder = pwd;
settings.dataFolder = fullfile(settings.mainFolder, 'OFICIAL');
settings.selectionFolder = fullfile(settings.mainFolder, 'KLT_shared_selections');

% Add the folder that contains the larger section-based functions.

functionsFolder = fullfile(settings.mainFolder, 'functions');

if exist(functionsFolder, 'dir')
    addpath(functionsFolder);
end

% Video preprocessing.

settings.sigmaBlur = 2;

% Manual selection settings.

settings.maskTime_s = 15;     % frame time used to draw the cell line
settings.patchTime_s = 0;     % frame time used to tracking box
settings.tubeRadius = 6;      % thickness of the cell mask around the drawn line
settings.maxVideoTime_s = 30;

% Experimental phases.

settings.phaseNames = ["Before"; "During"; "After"];
settings.phaseStart = [0; 10; 20];
settings.phaseEnd   = [10; 20; 30];

% File index to stimulation frequency.

settings.stimIndexToFrequency = containers.Map({1,2,3}, [1,50,100]);

% Tracking settings.

settings.maxBidirectionalError = 4;
settings.maxTrackingPoints = 10;

% Saved ROI/mask/box selections are reused because of "True".
settings.reuseSavedSelections = true;

if ~exist(settings.selectionFolder, 'dir')
    mkdir(settings.selectionFolder);
end

%% Step 1: find videos and create results folder

[videoTable, videoPacks] = buildVideoPacks(settings.dataFolder);
[resultFolder, excelFile] = createAnalysisFolders(settings.mainFolder);

fprintf('\nFound %d complete video packs.\n', numel(videoPacks));
fprintf('Results will be saved in:\n%s\n', resultFolder);

%% Step 2: select all ROIs, cell masks and tracking boxes

sharedSelections = selectAllSharedSelections(videoTable, videoPacks, settings, resultFolder);

fprintf('\nAll manual selections are finished.\n');
fprintf('Starting automatic analysis of all videos...\n');

%% Step 3: analyse all videos using the saved selections

results = analyseAllVideoPacks(videoTable, videoPacks, sharedSelections, settings);

%% Step 4: organise results and calculate statistics

results = organiseAndComputeStatistics(results, settings);

saveAllResults(results, videoTable, videoPacks, sharedSelections, settings, resultFolder, excelFile);
makeAllPackPlots(results.finalSummary, results.statsByFrequencyPhase, resultFolder, settings);

fprintf('\nFinished. Results folder:\n%s\n', resultFolder);

fprintf('\nExcel file:\n%s\n', excelFile);
