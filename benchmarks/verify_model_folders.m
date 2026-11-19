function verify_model_folders()
%VERIFY_MODEL_FOLDERS Reopen two working copies sharing a relocated companion file.
scratch=tempname;mkdir(scratch);remove=onCleanup(@()rmdir(scratch,'s'));
project=fullfile(scratch,'project');srcFolder=fullfile(project,'source');out=fullfile(project,'runs');
mkdir(srcFolder);mkdir(out);
name='fimwb_path_fixture';assert(~bdIsLoaded(name)&&~bdIsLoaded('fimwb_path_one')&&~bdIsLoaded('fimwb_path_two'));
gain=2;save(fullfile(srcFolder,'fimwb_companion.mat'),'gain');
new_system(name);
add_block('built-in/Constant',[name '/Value'],'Value','1');
add_block('built-in/Outport',[name '/Observation']);add_line(name,'Value/1','Observation/1');
set_param(name,'PreLoadFcn','assert(isfield(load(''fimwb_companion.mat''),''gain''))','Metadata',struct('Owner','Original'));
source=fullfile(srcFolder,[name '.slx']);save_system(name,source);close_system(name,0);
copy='fimwb_path_one.slx';
fimwb.build(source,fullfile(out,copy));
copyfile(fullfile(out,copy),fullfile(out,'fimwb_path_two.slx'));
assert(~onPath(srcFolder));relocated=fullfile(scratch,'relocated');movefile(project,relocated);
srcFolder=fullfile(relocated,'source');out=fullfile(relocated,'runs');
file=fullfile(out,copy);
meta=Simulink.MDLInfo.getMetadata(file);
assert(strcmp(meta.Owner,'Original') && strcmp(meta.FIMWorkbenchSourceModel,'../source/fimwb_path_fixture.slx'));
w1=fimwb.editor(file,'off');w2=fimwb.editor(fullfile(out,'fimwb_path_two.slx'),'off');
delete(w1);close_system('fimwb_path_one',0);assert(onPath(srcFolder));
set_param('fimwb_path_two','SimulationCommand','update');
delete(w2);close_system('fimwb_path_two',0);assert(~onPath(srcFolder) && ~onPath(out));
addpath(srcFolder,'-end');reset=onCleanup(@()rmpath(srcFolder));
w=fimwb.editor(file,'off');delete(w);close_system('fimwb_path_one',0);assert(onPath(srcFolder));
clear reset
fprintf('MODEL_PATH_PASS shared dependency, relocation, metadata and user path ownership\n');
end

function present=onPath(folder)
present=ismember(folder,strsplit(path,pathsep));
end
