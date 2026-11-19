function results=verify_fim_study(upstream,outputCsv)
%VERIFY_FIM_STUDY Run the real FISingle/FCSingle and Workbench workflows.
% Only the disposable trial directories contain files the upstream tools modify.
models={'FInjLib','fim_study_plant','fim_study_plant_copy','fim_study_workbench'};
assert(~any(cellfun(@bdIsLoaded,models)),'Close any existing study models and FInjLib before verification.');
scratch=tempname;mkdir(scratch);
cleanup=onCleanup(@()rmdir(scratch,'s'));
folder=fullfile(scratch,'scripted');
fimwbStudy('prepare',folder,1,upstream);
results=table();
for n=1:4
    trial=fimwbStudy('start',folder,n);
    bad=fimwbStudy('submit',folder,n,trial.source);
    assert(~bad.passed && isfinite(bad.max_error),'A healthy model must fail the fault task.');
    clock=tic;
    if trial.tool=="FIM",file=originalFim(trial);else,file=workbench(trial);end
    setup=toc(clock);
    direct=fimwbStudy('submit',folder,n,file);
    assert(isfinite(direct.max_error),'Direct candidate did not simulate: %s',direct.detail);
    corrected=direct;
    if trial.tool=="FIM" && ~direct.passed
        syncOriginalInstance(trial,file);
        corrected=fimwbStudy('submit',folder,n,file);
    end
    assert(corrected.passed,'%s %s: %s',trial.tool,trial.task,corrected.detail);
    row=table(trial.tool,trial.task,setup,2002,direct.max_error,~direct.passed,corrected.max_error,bad.max_error, ...
        'VariableNames',{'tool','task','scripted_setup_s','scalar_values','direct_max_error','instance_correction','final_max_error','healthy_control_error'});
    results=[results;row]; %#ok<AGROW>
    fprintf('STUDY_PASS %s %s %g\n',trial.tool,trial.task,direct.max_error);
end
writetable(results,outputCsv);
end

function file=originalFim(trial)
old=pwd;oldPath=path;flags=warning;
reset=onCleanup(@()restore(old,oldPath,flags));
cd(trial.folder);
cfg=fullfile(trial.folder,'Configuration');
writecell({'NA','NA',['Reading ' char(trial.task)],'NA','Bias/Offset'},fullfile(cfg,'sites.csv'),'WriteMode','append');
writecell({1,trial.offset,trial.onset,'Infinite time',0,1},fullfile(cfg,'enable.csv'),'WriteMode','append');
FISingle('model.csv','injections');
FCSingle('model.csv','injections','enable.csv');
file=fullfile(trial.folder,'fixture','fim_study_plant_copy.slx');
end

function syncOriginalInstance(trial,file)
% The pinned mask writes these two parameters into the library definition.
% Apply the requested settings to the disconnected instance for a separate check.
library=fullfile(trial.folder,'FaultInjector_Master','FInjLib.slx');
load_system(library);set_param('FInjLib','Lock','off');load_system(file);
guard=onCleanup(@()closeCopies());
slots=readtable(fullfile(trial.folder,'injections','Fault_table.xls'));
block=char(string(slots{1,3})+"/"+string(slots{1,2}));
set_param([block '/Fault value'],'Value',get_param(block,'FaultValue'));
set_param([block '/Faulttype'],'Value','1');
save_system(bdroot(block));
end

function closeCopies()
close_system('fim_study_plant_copy',0);close_system('FInjLib',0);
end

function restore(folder,oldPath,flags)
for m={'fim_study_plant_copy','fim_study_plant','FInjLib'}
    if bdIsLoaded(m{1}),close_system(m{1},0);end
end
cd(folder);path(oldPath);warning(flags);
end

function file=workbench(trial)
sites=fimwb.scan(trial.source);
site=sites(strcmp({sites.source},['Sensor ' char(trial.task)]) & strcmp({sites.kind},'endpoint'));
fault=struct('site',site.id,'type','bias','value',trial.offset,'start',trial.onset);
file=fullfile(trial.folder,'fim_study_workbench.slx');
fimwb.build(trial.source,struct('faults',fault),file);
end
