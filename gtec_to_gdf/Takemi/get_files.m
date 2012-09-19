function my_files = get_files(filedir,extension)
    filedir = dir([filedir,filesep,'*.',extension]);
    f_names = {filedir.name};
    f_dates = {filedir.date};
    %Pull out the condition (RC, 5, 15) from the filename.
    match = '\((\w{1,5})';
    output = regexpi(f_names,match,'tokens');
    condition=NaN(length(output),1);
    for oo=1:length(output)
        if ~isempty(output{oo})
            if strcmp(output{oo}{1},'5') || strcmpi(output{oo}{1},'ERD5')
                condition(oo)=5;
            elseif strcmp(output{oo}{1},'15') || strcmpi(output{oo}{1},'ERD15')
                condition(oo)=15;
            elseif strcmpi(output{oo}{1},'rc')
                condition(oo)=0;
            end
        end
    end
    [condition, I] = sort(condition);
    f_names = f_names(I);
    %my_files=NaN(1,length(f_names));
    for ff=1:length(f_names)
        my_files(ff).name = f_names(ff);
        my_files(ff).condition = condition(ff);
        my_files(ff).date = f_dates{ff};
    end
end