function [videoTable, videoPacks] = buildVideoPacks(dataFolder)

    % Find videos in the data folder and create complete video packs.
    % Expected format:
    %   vidA (1).avi   -> 1 Hz
    %   vidA (2).avi   -> 50 Hz
    %   vidA (3).avi   -> 100 Hz

    if ~exist(dataFolder, 'dir')
        error('The data folder does not exist: %s', dataFolder);
    end

    extensions = {'*.avi', '*.mp4'};

    allFiles = [];

    for e = 1:numel(extensions)
        filesThisExtension = dir(fullfile(dataFolder, extensions{e}));
        allFiles = [allFiles; filesThisExtension]; %#ok<AGROW>
    end

    if isempty(allFiles)
        error('No video files were found in: %s', dataFolder);
    end

    FileName = strings(numel(allFiles), 1); % name of the file
    FullPath = strings(numel(allFiles), 1); % complete path
    GroupID = strings(numel(allFiles), 1); % name of the group
    StimIndex = nan(numel(allFiles), 1); 
    Extension = strings(numel(allFiles), 1);

    for i = 1:numel(allFiles) % process all the found videos

        FileName(i) = string(allFiles(i).name);
        FullPath(i) = string(fullfile(allFiles(i).folder, allFiles(i).name));

        [~, baseName, ext] = fileparts(allFiles(i).name);
        Extension(i) = lower(string(ext));

        token = regexp(baseName, '^(.*?)\s*\((\d+)\)\s*$', 'tokens');

        if isempty(token)
            GroupID(i) = "";
            StimIndex(i) = NaN;
        else
            GroupID(i) = string(strtrim(token{1}{1}));
            StimIndex(i) = str2double(token{1}{2});
        end

    end

    videoTable = table(FileName, FullPath, GroupID, StimIndex, Extension);

    % Keep only valid videos with format: groupName (1), groupName (2), groupName (3)
    validRows = GroupID ~= "" & ~isnan(StimIndex) & ismember(StimIndex, [1 2 3]);
    videoTable = videoTable(validRows, :);

    if isempty(videoTable)
        error('No valid video packs were found. Check that files are named as vidA (1), vidA (2), vidA (3).');
    end

    % If the same video exists as AVI and MP4, prefer MP4 avoiding old
    % corrupted AVI files.
    priority = zeros(height(videoTable), 1);

    for i = 1:height(videoTable)

        switch videoTable.Extension(i)
            case ".mp4"
                priority(i) = 1;
            case ".avi"
                priority(i) = 2;
            otherwise
                priority(i) = 3;
        end

    end

    videoTable.Priority = priority;

    videoTable = sortrows(videoTable, {'GroupID', 'StimIndex', 'Priority'}); %organize

    % Remove duplicated group/stimulation videos, keeping the best priority
    uniqueKey = videoTable.GroupID + "_" + string(videoTable.StimIndex);
    [~, firstIdx] = unique(uniqueKey, 'stable');

    videoTable = videoTable(firstIdx, :);
    videoTable.Priority = [];

    videoTable = sortrows(videoTable, {'GroupID', 'StimIndex'});

    % Detect complete packs
    allGroups = unique(videoTable.GroupID, 'stable');
    videoPacks = strings(0, 1);

    for g = 1:numel(allGroups) 

        groupName = allGroups(g);
        groupRows = videoTable(videoTable.GroupID == groupName, :);

        has1 = any(groupRows.StimIndex == 1);
        has2 = any(groupRows.StimIndex == 2);
        has3 = any(groupRows.StimIndex == 3);

        if has1 && has2 && has3 % Keep complete groups
            videoPacks(end+1, 1) = groupName; %#ok<AGROW>
        else
            fprintf('Incomplete pack skipped: %s\n', groupName);
        end

    end

    if isempty(videoPacks)
        error('No complete video packs were found. Each pack needs (1), (2), and (3).');
    end

end