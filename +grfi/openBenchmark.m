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
if nargin<2 || isempty(workingDir)
    % Reopen saved models from an earlier ZIP installation.
    workingDir=fullfile(root,'work',id);
    if ~isfile(fullfile(workingDir,[name ext]))
        folders=strsplit(userpath,pathsep);
        personal=folders{1};
        if isempty(personal),personal=prefdir;end
        workingDir=fullfile(personal,'GRFaultInjector',id);
    end
end
if ~isfolder(workingDir),mkdir(workingDir);end
[ok,attr]=fileattrib(workingDir);assert(ok);workingDir=attr.Name;
file=fullfile(workingDir,[name ext]);
if bdIsLoaded(name),assert(strcmp(get_param(name,'FileName'),file),'Another working copy with this model name is open.');end
addpath(root,fullfile(root,'benchmarks'));
[~,horizon,input]=benchSource(id,root,workingDir,true);
inputName=['grfi_' lower(id) '_input'];assignin('base',inputName,input);
if ~isfile(file)
    % Stage first-use setup so a failed initialization can be retried.
    newFolder=tempname(workingDir);mkdir(newFolder);guard=onCleanup(@()clean(newFolder,name));
    staged=fullfile(newFolder,[name char(ext)]);copyfile(fullfile(verified,models.name),staged);
    assert(java.io.File(staged).setWritable(true),'Cannot make the working copy writable: %s',staged);
    load_system(staged);
    set_param(name,'SimulationMode','normal','StopTime',num2str(horizon));
    if ~strcmp(id,'F16'),set_param(name,'LoadExternalInput','on','ExternalInput',inputName);end
    save_system(name);close_system(name,0);
    java.nio.file.Files.move(java.io.File(staged).toPath(),java.io.File(file).toPath(),javaArray('java.nio.file.CopyOption',0));
    clear guard;
end
win=grfi.editor(file,visible);
end

function clean(folder,name)
if bdIsLoaded(name),close_system(name,0);end
if isfolder(folder),rmdir(folder,'s');end
end
