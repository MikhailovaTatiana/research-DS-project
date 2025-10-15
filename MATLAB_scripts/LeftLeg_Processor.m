% --- MATLAB Script: LeftLeg_ProcessortLeg_Processor.m ---

% Configuration
DATA_ROOT_FOLDER = 'Raw_Data';
TABLE_EMG = 'RightLeg_EMG'; % Wrong (actual) table name in the database
IMU_STRUCTURE_NAME = 'RightLeg_IMU'; % Wrong (actual) table name in the database
IMU_AXES = {'AccX', 'AccY', 'AccZ', 'GyroX', 'GyroY', 'GyroZ'};
% Speed-up controls (set true for quick diagnostics)
FAST_SKIP_IMU = false;           % If true, skip IMU assembly and merge (EMG only)
FAST_LIMIT_AXES = false;         % If true, only build a subset of IMU axes
IMU_AXES_LIMITED = {'AccX', 'AccY'}; % Subset when FAST_LIMIT_AXES is true

ACTIVITY_PATH = {'Level_Ground', 'Walking', 'Self_Selected_Speed'};
MAJOR_LEG_PATHS = {'LeftFoot_GaitCycle_Data'}; 
MERGE_KEYS = {'Participant', 'Overall_Trial_Index', 'Gait_Cycle_Percent'};

GENDER_MAP = containers.Map({'P01', 'P02', 'P03', 'P04', 'P05', 'P06', 'P07', 'P08', 'P09', 'P10'}, ...
                           {'Male', 'Male', 'Male', 'Male', 'Male', 'Female', 'Female', 'Female', 'Female', 'Female'});

PARTICIPANTS = {'P01','P02','P03','P04','P05','P06','P07','P08','P09','P10'};
OUTPUT_FILENAME = 'AllParticipants_LeftLeg_EMG_IMU.csv'; 

% Auto-detect present MAT files (informational only; still iterate all 10)
data_root = fullfile(pwd, DATA_ROOT_FOLDER);
detected_count = 0;
if exist(data_root, 'dir') == 7
    for idx = 1:numel(PARTICIPANTS)
        pid = PARTICIPANTS{idx};
        if exist(fullfile(data_root, pid, [pid '.mat']), 'file') == 2
            detected_count = detected_count + 1;
        end
    end
end
fprintf('Detected %d/%d participants with MAT files.\n', detected_count, numel(PARTICIPANTS));
all_data_tables = {};

fprintf('Starting data aggregation from Pxx.mat files...\n');

for i = 1:length(PARTICIPANTS)
    pID = PARTICIPANTS{i};
    mat_path = fullfile(pwd, DATA_ROOT_FOLDER, pID, [pID, '.mat']);
    
    fprintf('-> Processing %s...\n', pID);

    try
        if ~exist(mat_path, 'file'), error('MAT file not found.'); end
        t_load_start = tic;
        S = load(mat_path);
        fprintf('  load: %.2fs\n', toc(t_load_start));
        
        data_struct = S;
        top_level_fields = fieldnames(S);
        
        % 1. Handle single top-level variable name (e.g., 'P01')
        if length(top_level_fields) == 1, data_struct = S.(top_level_fields{1}); end
        
        % 2. SAFE unwrap to scalar: only shrink structs when numel > 1
        temp_struct = data_struct;
        while true
            changed = false;
            if iscell(temp_struct) && ~isempty(temp_struct)
                temp_struct = temp_struct{1};
                changed = true;
            elseif isstruct(temp_struct) && numel(temp_struct) > 1
                temp_struct = temp_struct(1);
                changed = true;
            end
            if ~changed, break; end
        end
        data_struct = temp_struct;
        % Diagnostics about root structure
        try
            root_fields = fieldnames(data_struct);
            fprintf('  root has %d fields\n', numel(root_fields));
            fprintf('  has LeftFoot_GaitCycle_Data: %d\n', isfield(data_struct,'LeftFoot_GaitCycle_Data'));
        catch
        end
        
        % Custom check for non-struct type at the root
        if ~isstruct(data_struct)
            error('Custom Error: Top-level variable is type "%s", expected struct.', class(data_struct));
        end

        EMG_data_cells = {};
        IMU_data_cells = {};

        for k = 1:length(MAJOR_LEG_PATHS)
            current_path_root = MAJOR_LEG_PATHS{k};
            
            if ~isfield(data_struct, current_path_root)
                fprintf('  missing field: %s\n', current_path_root);
                continue; 
            end
            
            % Access the major leg path
            current_struct = data_struct.(current_path_root);

            % 3. SAFE unwrap: only shrink structs when numel > 1
            temp_struct = current_struct;
            while true
                changed = false;
                if iscell(temp_struct) && ~isempty(temp_struct)
                    temp_struct = temp_struct{1};
                    changed = true;
                elseif isstruct(temp_struct) && numel(temp_struct) > 1
                    temp_struct = temp_struct(1);
                    changed = true;
                end
                if ~changed, break; end
            end
            current_struct = temp_struct;

            t_traverse = tic;
            % --- Explicit nested traversal (avoids extra looping) ---
            % RightFoot_GaitCycle_Data -> Level_Ground -> Walking -> Self_Selected_Speed
            temp_struct = current_struct;
            if ~isfield(temp_struct, 'Level_Ground')
                fprintf('  missing field: Level_Ground\n');
                % Create one-row NaN segment so participant is still represented
                nanEmg = array2table(nan(1,64), 'VariableNames', cellstr(strcat("EMG", string(1:64))));
                EMG_data_cells{end+1} = nanEmg;
                if ~FAST_SKIP_IMU
                    IMU_data_cells{end+1} = table(nan(1,1),nan(1,1),nan(1,1),nan(1,1),nan(1,1),nan(1,1), ...
                        'VariableNames', {'AccX','AccY','AccZ','GyroX','GyroY','GyroZ'});
                end
                continue; 
            end
            temp_struct = temp_struct.Level_Ground;
            if iscell(temp_struct) && ~isempty(temp_struct), temp_struct = temp_struct{1}; end
            if isstruct(temp_struct) && numel(temp_struct) == 1, temp_struct = temp_struct(1); end

            if ~isfield(temp_struct, 'Walking')
                fprintf('  missing field: Walking\n');
                nanEmg = array2table(nan(1,64), 'VariableNames', cellstr(strcat("EMG", string(1:64))));
                EMG_data_cells{end+1} = nanEmg;
                if ~FAST_SKIP_IMU
                    IMU_data_cells{end+1} = table(nan(1,1),nan(1,1),nan(1,1),nan(1,1),nan(1,1),nan(1,1), ...
                        'VariableNames', {'AccX','AccY','AccZ','GyroX','GyroY','GyroZ'});
                end
                continue; 
            end
            temp_struct = temp_struct.Walking;
            if iscell(temp_struct) && ~isempty(temp_struct), temp_struct = temp_struct{1}; end
            if isstruct(temp_struct) && numel(temp_struct) == 1, temp_struct = temp_struct(1); end

            if ~isfield(temp_struct, 'Self_Selected_Speed')
                fprintf('  missing field: Self_Selected_Speed\n');
                nanEmg = array2table(nan(1,64), 'VariableNames', cellstr(strcat("EMG", string(1:64))));
                EMG_data_cells{end+1} = nanEmg;
                if ~FAST_SKIP_IMU
                    IMU_data_cells{end+1} = table(nan(1,1),nan(1,1),nan(1,1),nan(1,1),nan(1,1),nan(1,1), ...
                        'VariableNames', {'AccX','AccY','AccZ','GyroX','GyroY','GyroZ'});
                end
                continue; 
            end
            fprintf('  reached: Level_Ground -> Walking -> Self_Selected_Speed\n');
            current_struct = temp_struct.Self_Selected_Speed;
            if iscell(current_struct) && ~isempty(current_struct), current_struct = current_struct{1}; end
            if isstruct(current_struct) && numel(current_struct) == 1, current_struct = current_struct(1); end

            fprintf('  traverse: %.2fs\n', toc(t_traverse));
            
            % 5. Final SAFE unwrap before data extraction
            temp_struct = current_struct;
            while true
                changed = false;
                if iscell(temp_struct) && ~isempty(temp_struct)
                    temp_struct = temp_struct{1};
                    changed = true;
                elseif isstruct(temp_struct) && numel(temp_struct) > 1
                    temp_struct = temp_struct(1);
                    changed = true;
                end
                if ~changed, break; end
            end
            current_struct = temp_struct;

            % Check for final tables
            if ~isfield(current_struct, TABLE_EMG)
                % No EMG: create one-row NaN EMG and optional NaN IMU
                nanEmg = array2table(nan(1,64), 'VariableNames', cellstr(strcat("EMG", string(1:64))));
                EMG_data_cells{end+1} = nanEmg;
                if ~FAST_SKIP_IMU
                    IMU_data_cells{end+1} = table(nan(1,1),nan(1,1),nan(1,1),nan(1,1),nan(1,1),nan(1,1), ...
                        'VariableNames', {'AccX','AccY','AccZ','GyroX','GyroY','GyroZ'});
                end
                continue;
            end
            % IMU is optional; if missing, we'll proceed with EMG-only for this segment
            imu_available = isfield(current_struct, IMU_STRUCTURE_NAME);

            % EXTRACT EMG TABLE (normalize to table)
            raw_emg = current_struct.(TABLE_EMG);
            T_EMG_current = [];
            try
                if istable(raw_emg)
                    T_EMG_current = raw_emg;
                elseif istimetable(raw_emg)
                    T_EMG_current = timetable2table(raw_emg);
                elseif isstruct(raw_emg)
                    % If it's a struct array, struct2table produces rows; if scalar struct, still yields a single row with array vars
                    T_EMG_current = struct2table(raw_emg);
                elseif iscell(raw_emg)
                    T_EMG_current = cell2table(raw_emg);
                elseif isnumeric(raw_emg)
                    % Numeric EMG: convert to table with sensible column names
                    [m,n] = size(raw_emg);
                    if m < n, raw_emg = raw_emg'; [m,n] = size(raw_emg); end
                    varNames = strcat("EMG", string(1:n));
                    T_EMG_current = array2table(raw_emg, 'VariableNames', cellstr(varNames));
                    fprintf('  EMG numeric -> table: %dx%d\n', m, n);
                else
                    error('Unsupported EMG type: %s', class(raw_emg));
                end
            catch convErr
                fprintf('  EMG normalize failed: %s\n', convErr.message);
                rethrow(convErr);
            end
            
            % EXTRACT and RE-ASSEMBLE IMU DATA (optional fast skip/limit)
            EMG_data_cells{end+1} = T_EMG_current;
            if ~FAST_SKIP_IMU && imu_available
            IMU_PARENT_STRUCT = current_struct.(IMU_STRUCTURE_NAME);
            % 6. SAFE unwrap IMU structure
            temp_struct = IMU_PARENT_STRUCT;
            while true
                changed = false;
                if iscell(temp_struct) && ~isempty(temp_struct)
                    temp_struct = temp_struct{1};
                    changed = true;
                elseif isstruct(temp_struct) && numel(temp_struct) > 1
                    temp_struct = temp_struct(1);
                    changed = true;
                end
                if ~changed, break; end
            end
            IMU_PARENT_STRUCT = temp_struct;
            
            T_IMU_current = table();
                axes_list = IMU_AXES;
                if FAST_LIMIT_AXES, axes_list = IMU_AXES_LIMITED; end
                t_imu = tic;
                for axis_name = axes_list
                axis_name = axis_name{1};
                if ~isfield(IMU_PARENT_STRUCT, axis_name), error('IMU axis field not found: %s', axis_name); end
                current_axis_data = IMU_PARENT_STRUCT.(axis_name);
                if size(current_axis_data, 1) < size(current_axis_data, 2)
                    current_axis_data = current_axis_data';
                end
                T_axis = table(current_axis_data, 'VariableNames', {axis_name});
                if isempty(T_IMU_current)
                    T_IMU_current = T_axis;
                else
                    T_IMU_current = [T_IMU_current, T_axis];
                end
            end
                fprintf('  imu: %.2fs (axes=%d)\n', toc(t_imu), width(T_IMU_current));
            IMU_data_cells{end+1} = T_IMU_current;
            elseif ~FAST_SKIP_IMU && ~imu_available
                % Insert a one-row NaN IMU to keep alignment with EMG segment
                IMU_data_cells{end+1} = table(nan(1,1),nan(1,1),nan(1,1),nan(1,1),nan(1,1),nan(1,1), ...
                    'VariableNames', {'AccX','AccY','AccZ','GyroX','GyroY','GyroZ'});
            end
            % continue to process any additional matching segments if present
        end

        if isempty(EMG_data_cells)
            fprintf('  ❗ No EMG segments extracted. Check printed missing-field breadcrumbs above.\n');
            error('No Right Leg data found.');
        end

        % Build per-segment merged tables (horizontal) with Participant/Gender
        all_segment_tables = {};
        num_segments = numel(EMG_data_cells);
        for segIdx = 1:num_segments
            T_emg = EMG_data_cells{segIdx};
            if ~FAST_SKIP_IMU && ~isempty(IMU_data_cells)
                T_imu = IMU_data_cells{min(segIdx, numel(IMU_data_cells))};
                n = min(height(T_emg), height(T_imu));
                T_emg = T_emg(1:n, :);
                T_imu = T_imu(1:n, :);
                T_seg = [T_emg, T_imu];
            else
                T_seg = T_emg;
            end
            % Add metadata (use string columns for consistent vertical concat)
            T_seg.Participant = repmat(string(pID), height(T_seg), 1);
            T_seg.Gender = repmat(string(GENDER_MAP(pID)), height(T_seg), 1);
            all_segment_tables{end+1} = T_seg;
        end

        % Concatenate all segments vertically for this participant
        T_participant = vertcat(all_segment_tables{:});
        T_participant.Leg = repmat(string('Right'), height(T_participant), 1);
        all_data_tables{end+1} = T_participant;

    catch ME
        % Use custom error messages if they were triggered
        if contains(ME.message, 'Custom Error') || contains(ME.message, 'Indexing failure')
            fprintf('CRITICAL STRUCTURAL FAILURE for %s. Error: %s\n', pID, ME.message);
        else
            fprintf('Error processing %s. Skipped. Error: %s\n', pID, ME.message);
        end
    end
end

if isempty(all_data_tables)
    error('CRITICAL FAILURE: No data tables were processed.');
end

T_final_all_data = vertcat(all_data_tables{:});
% Ensure IMU 6 axes columns exist (if missing, fill with NaN) for consistency
imuCols = {'AccX','AccY','AccZ','GyroX','GyroY','GyroZ'};
for c = 1:numel(imuCols)
    col = imuCols{c};
    if ~ismember(col, T_final_all_data.Properties.VariableNames)
        T_final_all_data.(col) = NaN(height(T_final_all_data), 1);
    end
end

% Reorder columns: Participant/Gender/Leg first, then IMU (6), then remaining (EMG)
preferredFront = {'Participant','Gender','Leg'};
frontExisting = preferredFront(ismember(preferredFront, T_final_all_data.Properties.VariableNames));
imuExisting = imuCols(ismember(imuCols, T_final_all_data.Properties.VariableNames));
remaining = setdiff(T_final_all_data.Properties.VariableNames, [frontExisting, imuExisting], 'stable');
T_final_all_data = T_final_all_data(:, [frontExisting, imuExisting, remaining]);

% Ensure front columns are strings for consistent type
for nf = 1:numel(frontExisting)
    col = frontExisting{nf};
    if ~isstring(T_final_all_data.(col))
        T_final_all_data.(col) = string(T_final_all_data.(col));
    end
end
writetable(T_final_all_data, OUTPUT_FILENAME);

fprintf('\nSUCCESS: Data saved to: %s\n', OUTPUT_FILENAME);