function [win,file]=openBenchmark(id,workingDir,visible)
%OPENBENCHMARK Open the fault editor on a reusable working copy of a tested model.
root=fileparts(fileparts(mfilename('fullpath')));
id=upper(char(id));
assert(ismember(id,{'AT','AFC','NN','CC','SC','PM','F16','SB1','SB2','SB3','SB4','SB5'}),'Unknown benchmark.');
if nargin<3,visible='on';end
verified=fullfile(root,'verification','all_sites',id);
pattern=['all_' lower(id) '_*'];
models=[dir(fullfile(verified,[pattern '.mdl']));dir(fullfile(verified,[pattern '.slx']))];
assert(isscalar(models),'Expected exactly one verified all-sites model in %s.',verified);
[~,~,ext]=fileparts(models.name);name=['edit_' lower(id)];
template=fullfile(verified,models.name);source=template;
if nargin<2 || isempty(workingDir)
    folders=strsplit(userpath,pathsep);personal=folders{1};
    if isempty(personal),personal=prefdir;end
    workingDir=fullfile(personal,'FIMWorkbench',id);
    % On the first open, import a saved personal or ZIP working copy.
    previous={fullfile(personal,'GRFaultInjector',id),fullfile(root,'work',id)};
    for k=1:numel(previous)
        saved=fullfile(previous{k},[name ext]);
        if isfile(saved),source=saved;break;end
    end
end
if ~isfolder(workingDir),mkdir(workingDir);end
[ok,attr]=fileattrib(workingDir);assert(ok);workingDir=attr.Name;
file=fullfile(workingDir,[name ext]);
if bdIsLoaded(name),assert(strcmp(get_param(name,'FileName'),file),'Another working copy with this model name is open.');end
addpath(root,fullfile(root,'benchmarks'));
[~,horizon,input]=benchSource(id,root,workingDir,true);
inputName=['fimwb_' lower(id) '_input'];assignin('base',inputName,input);
if ~isfile(file)
    % Stage first-use setup so a failed initialization can be retried.
    newFolder=tempname(workingDir);mkdir(newFolder);guard=onCleanup(@()clean(newFolder,name));
    staged=fullfile(newFolder,[name char(ext)]);copyfile(source,staged);
    assert(java.io.File(staged).setWritable(true),'Cannot make the working copy writable: %s',staged);
    load_system(staged);
    if strcmp(source,template)
        set_param(name,'SimulationMode','normal','StopTime',num2str(horizon));
        if ~strcmp(id,'F16'),set_param(name,'LoadExternalInput','on','ExternalInput',inputName);end
    else
        updateInput(name,id,inputName);upgradeMeasurement(name);
    end
    save_system(name);close_system(name,0);
    try
        java.nio.file.Files.move(java.io.File(staged).toPath(),java.io.File(file).toPath(),javaArray('java.nio.file.CopyOption',0));
    catch err
        if ~isfile(file),rethrow(err);end
    end
    clear guard;
end
if ~bdIsLoaded(name),load_system(file);end
updateInput(name,id,inputName);
win=fimwb.editor(file,visible);
end

function updateInput(model,id,inputName)
if strcmp(get_param(model,'ExternalInput'),['grfi_' lower(id) '_input'])
    set_param(model,'ExternalInput',inputName);
end
end

function clean(folder,name)
if bdIsLoaded(name),close_system(name,0);end
if isfolder(folder),rmdir(folder,'s');end
end
