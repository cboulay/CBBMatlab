addpath(strcat('..',filesep,'..'))
tools_paths;

%Set some parameters that will be necessary for converting the data files.
params.datadir = 'G:\Studies\Takemi_ERD_TMS\data';
params.outdir = fullfile(pwd,'gdfout');
params.rc_isis = [0 2 3 5 10 15];
params.ch_offset = 19;
params.trial_col = 1;
params.p2p_col = 6; %Column in excel file to find the peak-to-peak amplitude.
params.emg_fs = 1000; %Hz
params.eeg_fs = 600;
params.emg_channel_labels = {'FCR';'ECR'};
params.eeg_channel_labels = {'FC3';'C5';'CP3';'C1';'C3';'task';'trigger'};%task 0 = rest, 3 = imagery
params.spat_filt = [-0.25 -0.25 -0.25 -0.25 1 0 0];

%Load some subject specific details.
get_subject_info;

for ss=1:length(subjects_info)
    sub = subjects_info(ss);
    sub.data_dir = fullfile(params.datadir,[sub.name,'(',sub.date,')']);
    sub.CSVFiles = get_files(sub.data_dir,'csv');
    sub.EEGFiles = get_files(sub.data_dir,'mat');
    
    %Extract the MEP values from the CSV file.
    mep_output=[];
    for ff = 1:length(sub.CSVFiles)
        this_file = sub.CSVFiles(ff);
        f_name = fullfile(sub.data_dir,this_file.name{:});
        %csvread does not like the Japanese text
        %Thus we need to specify row numbers
        %Row numbers depend on the file type because
        %RC file has more ISIs.
        if this_file.condition==0
            my_isis = params.rc_isis;
            my_row_starts = sub.row_numbers{1};
        else
            my_isis = [0 sub.sici_isi sub.icf_isi];
            my_row_starts = sub.row_numbers{2};
        end
        if any(strfind('ECR',sub.muscle))
            my_row_starts = my_row_starts + params.ch_offset;
        end
        for isi=1:length(my_isis)
            row = my_row_starts(isi);
            row_bounds = [row-1 0 row+8 5];
            if strcmpi(sub.name,'terasaki') && cc==1 && isi==5
                row_bounds = [row-1 0 row+7 5];
            elseif strcmpi(sub.name,'yazaki') && cc==3
                row_bounds = [row-1 0 row+4 5];
            end
            my_csv = csvread(f_name, row-1, 0, row_bounds);
            n_trials = size(my_csv,1);
            mep_output = [mep_output; repmat(this_file.condition,n_trials,1), repmat(my_isis(isi),n_trials,1), my_csv(:,1), my_csv(:,6)];
        end
    end
    clear my_csv my_isis my_row_starts n_trials row row_bounds ff isi
    
    %Limit ourselves to only those files that were RC, ERD5, or ERD15.
    conditions = [sub.EEGFiles.condition]; %0=RC, 5=ERD5, 15=ERD15
    my_eeg_files = sub.EEGFiles(~isnan(conditions));
    cond_list = unique([my_eeg_files.condition]);
    
    %Some trials have no TMS pulse, the CSV file is unaware of
    %these. Thus we need to increment trial_ix_eeg and trial_ix_mep
    %separately. Furthermore, these indexes will be different for
    %each condition, so we will have one more global index.
    trial_ix_eeg = [0 0 0]; %Total trials per condition
    trial_ix_mep = [0 0 0]; %TMS trials per condition.
    trial_ix_global = 0; %Total trials across all conditions.
    
    for ff=1:length(my_eeg_files)
        cond_ix = find(cond_list==my_eeg_files(ff).condition);%For indexing trial_ix_eeg/mep
        %Load the raw data
        f_name = fullfile(sub.data_dir,my_eeg_files(ff).name{:});
        temp = load(f_name);
        %t_vec = temp.simout.time;
        signals = squeeze(temp.simout.signals.values(1,:,:)); %chans x samples

        %Identify trial starts and stops
        task_starts = find(diff(signals(6,:))>0);
        task_stops = find(diff(signals(6,:))<0);
        trial_starts = [1 task_stops(1:end-1)];
        trigger_starts = NaN(size(trial_starts));
        for tt=1:length(trial_starts)
            %Examine the data from this trial's task_start to the
            %next trial's task_start for a trigger. Note that the trigger
            %(ch 7) does not seem to be entirely reliable. There seems to
            %be a variable delay between the trigger and the artifact.
            if tt<length(trial_starts)
                trig_ix = task_starts(tt):task_starts(tt+1);
            else
                trig_ix = task_starts(tt):size(signals,2);
            end
            trig_sig = signals(7,trig_ix);
            test_sig = signals(5,trig_ix) - signals(5,trig_ix(1));
            if any(trig_sig>0)
                trigger_detect = find(test_sig>3000,1,'first');
                if any(trigger_detect)
                    trigger_starts(tt) = trig_ix(1) + trigger_detect - 1;
                else
                    trigger_starts(tt) = trig_ix(1) + find(diff(trig_sig)<0,1,'first');
                end
                if tt<length(trial_starts)
                    trial_starts(tt+1) = trigger_starts(tt) + 1;
                end
            end
        end
        trial_stops = [trial_starts(2:end) task_stops(end)];
        trial_stops(~isnan(trigger_starts)) = trigger_starts(~isnan(trigger_starts));

        file_t_vec = 1/params.eeg_fs:1/params.eeg_fs:size(signals,2)/params.eeg_fs;
        file_datetime = my_eeg_files(ff).date;

        eeg_trials = [];
        for tt=1:length(trial_starts)

            %Increment our trial counters.
            trial_ix_eeg(cond_ix) = trial_ix_eeg(cond_ix) + 1;
            trial_ix_mep(cond_ix) = trial_ix_mep(cond_ix) + 1*~isnan(trigger_starts(tt));
            trial_ix_global = trial_ix_global + 1;
            
            new_trial.file_ix = ff;
            new_trial.eeg_ix = trial_ix_eeg(cond_ix);
            new_trial.task_ix = cond_list(cond_ix);
            if ~isnan(trigger_starts(tt))
                new_trial.mep_ix = trial_ix_mep(cond_ix);
                mep_ix = find(mep_output(:,1) == new_trial.task_ix ...
                    & mep_output(:,3) == new_trial.mep_ix);
            else
                new_trial.mep_ix = NaN;
            end
            
            %Now that we have the mep_ix, get the actual isi and mep
            %values.
            if any(~isnan(mep_ix)) && any(mep_ix)
                new_trial.isi = mep_output(mep_ix,2);
                new_trial.mep = mep_output(mep_ix,4);
            else
                new_trial.isi = NaN; 
                new_trial.mep = NaN;
            end
            
            %Get the sample index for the task start and trigger start for
            %this trial.
            new_trial.trigger_start = trial_stops(tt) - trial_starts(tt);
            new_trial.task_start = task_starts(tt) - trial_starts(tt);
            
            %accumulate trials
            eeg_trials=[eeg_trials;new_trial];
            clear new_trial;
        end
        
        %eeg_trials contains the sample index for task_start,
        %trigger_start, the mep value and the isi for each trial.
        %Use this information, combined with signals, to write a GDF file.
        
    end
end