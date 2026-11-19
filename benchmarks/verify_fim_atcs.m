function result=verify_fim_atcs(upstream,folder)
%VERIFY_FIM_ATCS Exercise the authors' additional transmission example on its own inputs.
sources=fullfile(upstream,'Autotrans_fault_injector','cav_benchmark');
source=fullfile(sources,'AutotransModel.slx');
assert(strcmp(fimwb.fileHash(source),'0565ca33f84f80e6f28146b6e75d789b39cbe8f22bfd457d4777c820a9c59629'));
assert(~isfolder(folder)&&~isfile(folder),'Choose a new results folder.');
assert(~bdIsLoaded('AutotransModel') && ~bdIsLoaded('fim_paper_atcs'),'Close the existing transmission study models.');
prepared=fullfile(folder,'source');mkdir(prepared);
copyfile(source,prepared);
% The pinned model workspace requests this filename. Its bytes ship as autotrans_data.mat.
copyfile(fullfile(sources,'autotrans_data.mat'),fullfile(prepared,'sldemo_autotrans_data.mat'));
file=fullfile(prepared,'AutotransModel.slx');
sites=fimwb.scan(file);target=sites(arrayfun(@(s)strcmp(s.kind,'endpoint') && isscalar(s.destinations) && strcmp(s.destinations.path,'speed'),sites));
assert(isscalar(target),'Expected one connection to the speed output.');
setting=struct('site',target.id,'type','bias','value',1,'start',7,'stop',10,'enabled',true);
copy=fullfile(folder,'fim_paper_atcs.slx');fimwb.build(file,struct('faults',setting),copy);
comparison=fimwb.experiment(copy,fullfile(folder,'comparison'));
% Independently simulate the unmodified source with its original throttle and brake.
onPath=ismember(prepared,strsplit(path,pathsep));
if ~onPath,addpath(prepared,'-end');reset=onCleanup(@()rmpath(prepared));end
load_system(file);closeOriginal=onCleanup(@()close_system('AutotransModel',0));
reference=sim('AutotransModel','ReturnWorkspaceOutputs','on','SaveOutput','on','OutputSaveName','ref', ...
    'SaveFormat','Dataset','DatasetSignalFormat','timeseries','LimitDataPoints','off','Decimation','1');
load0=load(fullfile(comparison.folder,'baseline.mat'),'dataset');load1=load(fullfile(comparison.folder,'case_0001.mat'),'dataset');
base=load0.dataset;active=load1.dataset;out=reference.ref;
port=str2double(get_param('AutotransModel/speed','Port'));points=0;err=0;baselineError=0;
assert(out.numElements==4 && base.numElements==4 && active.numElements==4);
for k=1:out.numElements
    a=out{k}.Values;b=base{k}.Values;c=active{k}.Values;
    assert(isequal(a.Time,b.Time) && isequal(a.Time,c.Time));
    v=double(a.Data);baselineError=max(baselineError,max(abs(double(b.Data)-v),[],'all'));
    if k==port,v=v+reshape(double(a.Time>=7 & a.Time<10),size(v));end
    err=max(err,max(abs(double(c.Data)-v),[],'all'));points=points+numel(v);
end
assert(max(err,baselineError)<1e-9);
result=table(string(target.id),out.numElements,points,baselineError,err,'VariableNames', ...
    {'site','output_count','scalar_values_per_run','baseline_max_error','active_max_error'});
writetable(result,fullfile(folder,'summary.csv'));
fprintf('FIM_ATCS_PASS %d scalar values per run\n',points);
end
