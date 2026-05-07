
% /Users/yuanzh/Desktop/Sherlock /oak/stanford/groups/menon

%-Please specify parallel or nonparallel
%-e.g. for individualstats, set to 1 (parallel)
%-for groupstats, set to 0 (nonparallel)
paralist.parallel = '0';

% Please specify the path to the folder holding subjects
paralist.ServerPath = ' ';

% Please specify the path to your main project directory
paralist.projectdir = ' ';

% Plese specify the list of subjects or a cell array
paralist.SubjectList = ' ';


% Please specify the stats folder name from SPM analysis (only 2 allowed)
paralist.StatsFolder = {'stats_spm12_swgcar_pediatric_comp_dot','stats_spm12_swgcar_pediatric_comp_num'};

% Please specify the task name for each stats folder (only 2 allowed)
paralist.TaskName = {'comp_dot','comp_num'};

% Please specify whether to use t map or beta map ('tmap' or 'conmap')
paralist.MapType = 'conmap';

% Please specify the index of tmap or contrast map (only 1 allowed) 
paralist.MapIndex = [11];  %% near vs far 
%
% Please specify the mask file, if it is empty, it uses the default one from SPM.mat
paralist.MaskFile = '';

% Please specify the path to the folder holding analysis results
paralist.OutputDir = ' ';

% Please specify the version of spm to run
paralist.spmversion = 'spm12';

%--------------------------------------------------------------------------
paralist.SearchShape = 'sphere';
paralist.SearchRadius = 6; % in mm
%-------------------------------------------------------------------------
