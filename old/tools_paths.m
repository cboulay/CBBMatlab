temp.currdir = pwd;
if ispc
    temp.root = temp.currdir(1:3);
else
    temp.root = filesep;
end
%addpath(genpath(fullfile(temp.root,'Tools','chronux')));
addpath(fullfile(temp.root,'Tools','mym'));
addpath(genpath(fullfile(temp.root,'Tools','MyMatlabApps')));
addpath(fullfile(temp.root,'BCI2000','tools','matlab'));
bci2000path -AddToMatlabPath tools/mex     % binary mex-files (load_bcidat and friends)
bci2000path -AddToMatlabPath tools/matlab  % matlab m-files
bci2000path -AddToMatlabPath tools/OfflineAnalysis  % matlab m-files
bci2000path -AddToSystemPath tools/cmdline % binary executables (command-line utilities)
clear temp