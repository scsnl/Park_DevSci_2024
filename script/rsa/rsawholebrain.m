%-Whole brain similarity analysis
%-Tianwen Chen, 2012-03-29
%__________________________________________________________________________
%-2009-2012 Stanford Cognitive and Systems Neuroscience Laboratory
% Yuan modified on 09-26-2018

function rsa_wholebrain_diff (ConfigFile)

disp('==================================================================');
disp('rsa_wholebrain.m is running');
fprintf('Current directory is: %s\n', pwd);
fprintf('Config file is: %s\n', ConfigFile);
disp('------------------------------------------------------------------');
disp('Send error messages to tianwenc@stanford.edu');
disp('==================================================================');
fprintf('\n');

ConfigFile = strtrim(ConfigFile);
CurrentDir = pwd;
if ~exist(ConfigFile,'file')
  fprintf('Cannot find the configuration file %s ..\n',ConfigFile);
  error('Cannot find the configuration file');
end
[ConfigFilePath, ConfigFile, ConfigFileExt] = fileparts(ConfigFile);
  eval(ConfigFile);
  clear ConfigFile;

ServerPath   = strtrim(paralist.ServerPath);
SubjectList  = strtrim(paralist.SubjectList);
MapType      = strtrim(paralist.MapType);
MapIndex     = paralist.MapIndex;
MaskFile     = strtrim(paralist.MaskFile);
StatsFolder  = strtrim(paralist.StatsFolder); 
TaskName  = strtrim(paralist.TaskName); 
OutputDir    = strtrim(paralist.OutputDir);
SearchShape  = strtrim(paralist.SearchShape);
SearchRadius = paralist.SearchRadius;
SPM_Version  = paralist.spmversion;

addpath(genpath(['/oak/stanford/groups/menon/toolboxes/',SPM_Version]));

disp('-------------- Contents of the Parameter List --------------------');
disp(paralist);
disp('------------------------------------------------------------------');
clear paralist;

Subjects = csvread(SubjectList,1);
NumSubj = size(Subjects, 1); 

NumMap = length(MapIndex);
NumTask = length(TaskName);

if NumMap ~= 1 
  error('Only 1 MapIndex are allowed');
end

if NumTask ~= 2 
  error('Only 2 TaskName are allowed');
end

for iSubj = 1:NumSubj
  PID = num2str(Subjects(iSubj,1));
  VISIT = num2str(Subjects(iSubj,2));
  SESSION = num2str(Subjects(iSubj,3));
%   
%   DataDir = fullfile(ServerPath,PID,['visit',VISIT], ['session',SESSION], ...
%     'glm', 'stats_spm12', StatsFolder);
  
  DataDir = fullfile(ServerPath,PID,['visit',VISIT], ['session',SESSION], ...
     'glm', ['stats_' SPM_Version]);
  load(fullfile(DataDir, StatsFolder{1}, 'SPM.mat'));
  
  VY = cell(NumTask, 1);
  
  MapName = cell(NumTask, 1);
  
  switch lower(MapType)
    case 'tmap'
      for i = 1:NumTask
        VY{i} = fullfile(DataDir, StatsFolder{i}, SPM.xCon(MapIndex).Vspm.fname); 
        MapName{i} = [SPM.xCon(MapIndex).name, '_', TaskName{i}]; 
      end
    case 'conmap'
      for i = 1:NumTask
        VY{i} = fullfile(DataDir, StatsFolder{i}, SPM.xCon(MapIndex).Vcon.fname); 
        MapName{i} = [SPM.xCon(MapIndex).name, '_', TaskName{i}]; 
      end
  end
  
  if isempty(MaskFile)
    VM = fullfile(DataDir, StatsFolder{1}, SPM.VM.fname); 
  else
    VM = MaskFile;
  end
  
  OutputFolder = fullfile(OutputDir, PID,['visit',VISIT], ['session',SESSION],'rsa',['stats_', SPM_Version], [MapName{1}, '_VS_', MapName{2},'_pediatric']);
  if ~exist(OutputFolder, 'dir')
    mkdir(OutputFolder);
  end
  
  OutputFile = fullfile(OutputFolder, 'rsa');
  
  SearchOpt.def = SearchShape;
  SearchOpt.spec = SearchRadius;
  
  scsnl_searchlight(VY, VM, SearchOpt, 'pearson_correlation', OutputFile);
end

disp('-----------------------------------------------------------------');
fprintf('Changing back to the directory: %s \n', CurrentDir);
cd(CurrentDir);
disp('Wholebrain RSA is done.');
clear all;
close all;

end
