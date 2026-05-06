% This script performs individual fMRI analysis
% It first loads configuration file containing individual stats parameters
%  
% This scripts are compatible with both Analyze and NIFTI formats
% To use either format, change the data type in individualstats_config.m
%
% To run individual fMRI analysis, type at Matlab command line: 
% >> individualstats('individualstats_config.m')
% 
% _________________________________________________________________________
% 2009-2012 Stanford Cognitive and Systems Neuroscience Laboratory
%
% $Id:tianwen chen individualstats.m 2012-06-06 
% Rui Yuan, 2018-02-10,  
% -------------------------------------------------------------------------


function individualstats(SubjectI, ConfigFile)



global currentdir idata_type run_img;
currentdir = pwd;

    warning('off', 'MATLAB:FINITE:obsoleteFunction')
    c     = fix(clock);
    disp('==================================================================');
    fprintf('fMRI IndividualStats start at %d/%02d/%02d %02d:%02d:%02d \n',c);
    disp('==================================================================');
    %fname = sprintf('individualstats-%d_%02d_%02d-%02d_%02d_%02.0f.log',c);
    %diary(fname);
    disp(['Current directory is: ',currentdir]);
    fprintf('Script: %s\n', which('individualstats.m'));
    fprintf('Configfile: %s\n', ConfigFile);
    fprintf('\n')
    disp('------------------------------------------------------------------');


% -------------------------------------------------------------------------
% Check existence of the configuration file
% -------------------------------------------------------------------------
    ConfigFile = strtrim(ConfigFile);


      if ~exist(ConfigFile,'file')
          fprintf('Cannot find the configuration file %s ..\n',ConfigFile);
          error('Cannot find the configuration file');
      end
  [ConfigFilePath, ConfigFile, ConfigFileExt] = fileparts(ConfigFile);
    eval(ConfigFile);
    clear ConfigFile;

    
spm_version             = strtrim(paralist.spmversion);
software_path           = '/toolboxes/';
spm_path                = fullfile(software_path, spm_version);
spmindvstatsscript_path   = ['/scsnlscripts/brainImaging/mri/fmri/glmActivation/individualStats/' spm_version];

sprintf('adding SPM path: %s\n', spm_path);
addpath(genpath(spm_path));
sprintf('adding SPM based individual stats scripts path: %s\n', spmindvstatsscript_path);
addpath(genpath(spmindvstatsscript_path)); 
spmpreprocscript_path   = fullfile('/scsnlscripts/brainImaging/mri/fmri/preprocessing/',spm_version);    
sprintf('adding SPM based preprocessing scripts path: %s\n', spmpreprocscript_path);
addpath(genpath(spmpreprocscript_path));    
addpath(genpath('/software/spm8/toolbox/ArtRepair'));

% -------------------------------------------------------------------------
% Read individual stats parameters
% -------------------------------------------------------------------------
% Ignore white space if there is any
    subject_i          = SubjectI;
    subjectlist        = strtrim(paralist.subjectlist);
    runlist            = strtrim(paralist.runlist);
    idata_type         = strtrim(paralist.data_type);
    include_mvmnt       = paralist.include_mvmnt;
    pipeline           = strtrim(paralist.pipeline);

     include_artrepair   = paralist.include_volrepair;
     artpipeline        = strtrim(paralist.volpipeline);
     repaired_folder     = strtrim(paralist.volrepaired_folder);
     repaired_stats      = strtrim(paralist.repaired_stats);

    project_dir        = strtrim(paralist.projectdir);
    preprocessed_folder = strtrim(paralist.preprocessed_folder);
    stats_folder        = strtrim(paralist.stats_folder);
    task_dsgn           = strtrim(paralist.task_dsgn);
    contrastmat         = strtrim(paralist.contrastmat);
    template_path      = strtrim(paralist.batchtemplatepath);
    %spm_version        = strtrim(paralist.spmversion);
    TR                 = double(paralist.TR);
    cvi                = strtrim(paralist.cvi);


    
    [v,r] = spm('Ver','',1);
    fprintf('>>>-------- This SPM is %s V%s ---------------------\n',v,r);

    disp('-------------- Contents of the Parameter List --------------------');
    disp(paralist);
    disp('------------------------------------------------------------------');
    clear paralist;

    if ~exist(template_path,'dir')
      disp('Template folder does not exist!');
      return;
    end

% -------------------------------------------------------------------------
% Read in subjects and sessions
% Get the subjects, sesses in cell array format
        subjectlist       = csvread(subjectlist,1);
        subject           = subjectlist(subject_i);
        subject           = char(string(subject));
        subject           = char(pad(string(subject),4,'left','0'));%<<<<<<<<<<<<<<<<<<<<<<<<<<<<
        visit             = num2str(subjectlist(subject_i,2));
        session           = num2str(subjectlist(subject_i,3));

        numsub           = 1;
        runs              = ReadList(runlist);
        numrun            = length(runs);

        if isempty(contrastmat) && (numrun > 1)
          disp('Contrastmat file is not specified for more than two runs.');
          disp('-----------------------------------------------------------');
        %   diary off; 
          return;
        end

% -------------------------------------------------------------------------
% Start Individual Stats Processing
% -------------------------------------------------------------------------
for subcnt = 1:numsub
    
  fprintf('Processing Subject: %s \n',subject);
  disp('--------------------------------------------------------------');
  
  sub_dir = fullfile(project_dir, '/results/taskfmri/participants', subject, ['visit',visit],['session',session],'glm');
  sub_stats_dir = fullfile(sub_dir, ['stats_', spm_version], stats_folder);
  
  %------ Create stats folder.
  fprintf('>>> Creating the directory:\n %s \n\n', sub_stats_dir);
  mkdir(sub_stats_dir);
  
  %------ Change to stats folder
  fprintf('>>> Changing to directory:\n %s \n\n', sub_stats_dir);
  cd (sub_stats_dir);
  
  %------ If stats folder contains SPM.mat file and others, they will be deleted
  if exist('SPM.mat', 'file')
    disp('The stats directory contains SPM.mat. It will be deleted.');
    disp('-----------------------------------------------------------')
    unix('/bin/rm -rf *');
  end
  
  run_img = cell(numrun,1);
  run_raw_dir = cell(numrun,1);
  
  % In the stats folder
  for irun = 1:numrun
      
    %--------  run folder (preprocessed)
     run_raw_dir{irun} = fullfile(project_dir, '/data/imaging/participants/', subject, ...
                        ['visit',visit], ['session',session], 'fmri', runs{irun});
                    
    %-------- run_img: directory of subject/run in stats server
    run_img{irun} = fullfile(run_raw_dir{irun}, preprocessed_folder);
    run_img_dir = run_img{irun};

    %-------- If there is a ".m" at the end remove it.
%     if(~isempty(regexp(task_dsgn, '\.m$', 'once' )))
%       task_dsgn = task_dsgn(1:end-2);
%     end
    
    %-------- Check task_design file 
    addpath(fullfile(run_raw_dir{irun}, 'task_design'));
    str = which(task_dsgn);
    fprintf('>>>> str is %s \n',str);
    if isempty(str)
       error('Cannot find task design file in task_design folder.');
       cd(currentdir);
%        diary off; 
       return;
    end
    
  
    
    %%%-------------load task design file ---------------
    
    [filepath,name,ext] = fileparts(task_dsgn);
    fprintf('>>> pwd is %s \n',pwd);
    fprintf('>>>> task_desgin file is %s %s %s \n',filepath, name, ext);
    if(strcmp(ext,'.mat'))
        load(str);
        fprintf('<><> \n');
    else
        error('task design file type should be *.mat');
    end
        rmpath(fullfile(run_raw_dir{irun}, 'task_design'));
    
    %-------- Check the existence of preprocessed folder
    if ~exist(run_img_dir, 'dir')
      fprintf('Cannot find %s \n', run_img_dir);
      cd(currentdir);
%       diary off; 
      return;
    end
    %--------- Unzip files if needed
    system(sprintf('gunzip -fq %s', fullfile(run_img_dir,[pipeline, 'I.nii.gz'])));

    %-------- Update the design with the movement covariates
    if(include_mvmnt == 1)       
      %load task_design
      fprintf('run_img_dir is: %s \n',run_img_dir);
      reg_file = spm_select('FPList', run_img_dir, '^rp_I');
      system(sprintf('gunzip -fq %s', reg_file));
      reg_file = spm_select('FPList', run_img_dir, '^rp_I');
      if isempty(reg_file)
          disp('Cannot find the movement files');
          cd(currentdir);
%           diary off; 
          return;
      end
      % Regressor names, ordered according regressor file structure
      reg_names = {'movement_x','movement_y','movement_z','movement_xr','movement_yr','movement_zr'}; 
      % 0 if regressor of no interest, 1 if regressor of interest
      reg_vec   = [0 0 0 0 0 0];
      disp('>>> Updating the task design with movement covariates');     
      %save task_design.mat sess_name names onsets durations rest_exists reg_file reg_names reg_vec
      save task_design.mat sess_name names onsets durations rest_exists reg_file reg_names reg_vec
    end
    
    if(numrun > 1)
      % Rename the task design file
      fprintf('pwd is %s \n', pwd);
      newtaskdesign = ['task_design_run' num2str(irun) '.mat'];
      movefile('task_design.mat', newtaskdesign);
    end
    % clear the variables used in input task_design.m file
    clear sess_name names onsets durations rest_exists reg_file reg_names reg_vec
  end
  
  %---------------------------------------------------------------------
  %--- Get the contrast file
  %[pathstr, contrast_fname, contrast_fext, versn] = fileparts(contrastmat);
  [pathstr, contrast_fname, contrast_fext] = fileparts(contrastmat);
  
  if(isempty(pathstr) && ~isempty(contrast_fname))
    contrastmat = [currentdir '/' contrastmat];
  end
  
  cd(sub_stats_dir);
  foname    = cell(1,2);
  foname{1} = template_path;
  foname{2} = preprocessed_folder;
  
  %------- Call the N session batch script
  %numrun
  individualfmri(pipeline, numrun, contrastmat,foname,TR,cvi);



   %-------- Volume repair deweight ------------
  if include_artrepair == 1
    repaired_folder_dir = cell(numrun, 1);
    for scnt = 1:numrun
      repaired_folder_dir{scnt} = fullfile(run_raw_dir{scnt}, ...
                                           repaired_folder);
      unix(sprintf('gunzip -fq %s', fullfile(repaired_folder_dir{scnt}, ...
                     '*.txt.gz')));
      unix(sprintf('gunzip -fq %s', fullfile(repaired_folder_dir{scnt}, ...
                     [artpipeline,'I*'])));
    end
    repaired_stats_dir = fullfile(sub_dir, ['stats_', spm_version], repaired_stats);
    if exist(repaired_stats_dir, 'dir')
      disp('------------------------------------------------------------');
      fprintf('%s already exists! Get deleted \n', repaired_stats_dir);
      disp('------------------------------------------------------------');
      unix(sprintf('/bin/rm -rf %s', repaired_stats_dir));
    end
    mkdir(repaired_stats_dir);
    scsnl_art_redo(sub_stats_dir, artpipeline, repaired_stats_dir, ...
                   repaired_folder_dir);
    % copy contrasts.mat, task_design, batch_stats
    unix(sprintf('/bin/cp -af %s %s', fullfile(sub_stats_dir, ['contrasts', '*']), ...
                 repaired_stats_dir));
    unix(sprintf('/bin/cp -af %s %s', fullfile(sub_stats_dir, ['task_design', '*']), ...
                 repaired_stats_dir));
    unix(sprintf('/bin/cp -af %s %s', fullfile(sub_stats_dir, 'batch_stats*'), ...
                 repaired_stats_dir));
    % remove temporary stats
    unix(sprintf('/bin/rm -rf %s', sub_stats_dir));
    for scnt = 1:numrun
      unix(sprintf('gzip -fq %s', fullfile(repaired_folder_dir{scnt}, ...
                 [artpipeline,'I*'])));
    end
  end



end

% Change back to the directory from where you started.
fprintf('Changing back to the directory: %s \n', currentdir);
c     = fix(clock);
disp('==================================================================');
fprintf('fMRI Individual Stats finished at %d/%02d/%02d %02d:%02d:%02d \n',c);
disp('==================================================================');
cd(currentdir);
% diary off;
delete(get(0,'Children'));
clear all;
close all;

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% individualfmri is called by invidualstats.m to creates individual fMRI
% model.
% It updates batch file with model specification, estimation and contrasts
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function individualfmri (pipeline,numsess,contrastmat,foname,TR,cvi)

% -------------------------------------------------------------------------
% Initialization
% -------------------------------------------------------------------------
    spm('defaults', 'fmri');
    global idata_type run_img;

    % Subject statistics folder
    statsdir = pwd;
    template_path = foname{1};

% -----------------------------------------------------------------------------
% fMRI design specification
% -----------------------------------------------------------------------------
    load(fullfile(template_path,'batch_stats.mat'));

    % Get TR value: initialized to 2 but will be update by calling GetTR.m
    %TR = 2.0;
    display('------- please check TR  TR  TR  ! --------------');
    fprintf('>>>>> TR is %d  \n',TR);
    matlabbatch{1}.spm.stats.fmri_spec.timing.RT = TR; 
    % Initializing scans
    matlabbatch{1}.spm.stats.fmri_spec.sess(1).scans = {};
    matlabbatch{1}.spm.stats.fmri_spec.cvi= cvi;
    %matlabbatch{1}.spm.stats.fmri_spec.bases.hrf.derivs = [1,0];

for sess = 1:numsess
      % Set preprocessed folder
      datadir = run_img{sess};

      %------------------------------------------------------------------------
      % Check the data type
      if isempty(idata_type)
        fselect = spm_select('List',datadir,['^',pipeline,'I']);
        [strpath, fname, fext] = fileparts(fselect(1,:));
        if ismember(fext, {'.img', '.hdr'})
          data_type = 'img';
          error('Error: IMG format is not supported. Please convert your files to 4D NIFTI format');     
        else
          data_type = 'nii';
        end
      else
        data_type = idata_type;
      end
  %------------------------------------------------------------------------
  
    %  switch data_type
    %    case 'img'
    %      files = spm_select('ExtFPList', datadir, ['^',pipeline,'I.*\.img']);
    %      nscans       = size(files,1);            
    %    case 'nii'
          nifti_file = spm_select('ExtFPList', datadir, ['^',pipeline,'I.nii']);
          nifti_file
          V       = spm_vol(deblank(nifti_file));
          %nframes = V(1).private.dat.dim(4);
          nframes = length(V);
          files = spm_select('ExtFPList', datadir, ['^',pipeline,'I.nii'],1:nframes);
          nscans = size(files,1);
          clear nifti_file V nframes;
    %  end
  files 
  matlabbatch{1}.spm.stats.fmri_spec.sess(sess) = matlabbatch{1}.spm.stats.fmri_spec.sess(1);
  matlabbatch{1}.spm.stats.fmri_spec.sess(sess).scans = {};

      % Input preprocessed images
        fprintf('>>> The First File Is: \n %s \n\n',files(1,:));
        %fprintf('fils are %s \n',files(300,:));
      for nthfile = 1:nscans
        matlabbatch{1}.spm.stats.fmri_spec.sess(sess).scans{nthfile,1} = deblank(files(nthfile,:)); 
      end

  
      if(numsess == 1)
        taskdesign_file = fullfile(statsdir, 'task_design.mat');
        fprintf('>>> Task_design File Is: \n %s\n\n', taskdesign_file);
      else
        taskdesign_file = sprintf('%s/task_design_run%d.mat', statsdir, sess);
      end
  
      reg_file = '';
      load(taskdesign_file);
      matlabbatch{1}.spm.stats.fmri_spec.sess(sess).multi{1}  = taskdesign_file;
    %   reg_file1 = dlmread(reg_file);
    %   reg_file1
      matlabbatch{1}.spm.stats.fmri_spec.sess(sess).multi_reg = {reg_file};

end

    matlabbatch{1}.spm.stats.fmri_spec.dir = {statsdir};

    %--------------------------------------------------------------------------
    % Estimation Setup
    %--------------------------------------------------------------------------
    matlabbatch{2}.spm.stats.fmri_est.spmmat{1} = strcat(statsdir,'/SPM.mat'); 

    %--------------------------------------------------------------------------
    % Contrast Setup
    %--------------------------------------------------------------------------
    matlabbatch{3}.spm.stats.con.spmmat{1} = strcat(statsdir,'/SPM.mat'); 

    % Built the standard contrats only if the number of sessions is one
    % else use the user provided contrast file
    if isempty(contrastmat)
      if (numsess >1 )
        disp(['The number of session is more than 1, No automatic contrast' ...
              ' generation option allowed, please spcify the contrast file']);
    %     diary off; 
        return;
      else
        build_contrasts(matlabbatch{1}.spm.stats.fmri_spec.sess);
      end
    else
      fprintf('>>> The contrastmat Is: \n %s \n\n',contrastmat);
      fprintf('>>> PWD Is :\n %s \n\n',pwd);
      copyfile(contrastmat, 'contrasts.mat','f');
    end

load contrasts.mat;

    for i=1:length(contrastNames)
      if (i <= numTContrasts)
        matlabbatch{3}.spm.stats.con.consess{i}.tcon.name   = contrastNames{i};
        matlabbatch{3}.spm.stats.con.consess{i}.tcon.convec = contrastVecs{i};
      elseif (i > numTContrasts)
        matlabbatch{3}.spm.stats.con.consess{i}.fcon.name = contrastNames{i};
        for j=1:length(contrastVecs{i}(:,1))
          matlabbatch{3}.spm.stats.con.consess{i}.fcon.convec{j} = ...
          contrastVecs{i}(j,:);
        end
      end
    end

    save batch_stats matlabbatch
    % Initialize the batch system
    spm_jobman('initcfg');
    delete(get(0,'Children'));
    % Run analysis
    spm_jobman('run', './batch_stats.mat');

    for sess = 1:numsess
      % Set scan data and stats directory
      datadir = run_img{sess}; 
      unix(sprintf('gzip -fq %s', fullfile(datadir, [pipeline, 'I*'])));
    end

end

