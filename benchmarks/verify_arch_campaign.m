function results=verify_arch_campaign(outputCsv)
%VERIFY_ARCH_CAMPAIGN Compare 48 campaign cases against independent reference runs.
scratch=tempname;mkdir(scratch);cleanup=onCleanup(@()rmdir(scratch,'s'));
ids={'AT','AFC','NN','CC','SC','PM','SB1','SB2','SB3','SB4','SB5','F16'};
results=table();
for k=1:numel(ids)
    id=ids{k};dataRoot=fimwb.benchmarkFolder(id);
    suite=fullfile(dataRoot,'verification','arch2026',id);
    info=jsondecode(fileread(fullfile(suite,'result.json')));
    traces=load(fullfile(suite,'traces.mat'),'baseline');
    catalog=jsondecode(fileread(fullfile(suite,'sites.json')));
    [win,file]=fimwb.openBenchmark(id,fullfile(scratch,id),'off');
    [~,name]=fileparts(file);closeModel=onCleanup(@()closePair(win,name));
    tbl=findall(win,'Tag','faultTable');sink=tbl.Data{strcmp(tbl.Data(:,2),info.sink_site),1};
    site=catalog(strcmp({catalog.id},info.sink_site));
    port=str2double(get_param([name '/' site.destinations.path],'Port'));
    change=fimwb.setFault(name,sink,struct('type','bias','enabled',false,'value',0));assert(~change.enabled);
    toggled=sink;inner=traces.baseline;
    if ~isempty(info.internal_site)
        toggled=tbl.Data{strcmp(tbl.Data(:,2),info.internal_site),1};
        site=catalog(strcmp({catalog.id},info.internal_site));v=1/64;
        if contains(site.dataType,'int'),v=1;end
        fimwb.setFault(name,toggled,struct('type','bias','enabled',false,'value',v));
        archive=load(fullfile(suite,'traces.mat'),'internal');inner=archive.internal;
    end
    axes=struct('slot',{toggled,sink},'field',{'enabled','value'},'levels',{[false true],[0 2]});
    folder=fullfile(scratch,id,'cases');report=fimwb.experiment(name,folder,axes);
    count=0;worst=0;
    for n=0:report.caseCount
        idCase='baseline';ref=traces.baseline;bias=0;
        if n>0
            idCase=sprintf('case_%04d',n);
            if mod(n,2)==0,ref=inner;end
            if n>=3 && (toggled~=sink || mod(n,2)==0),bias=2;end
        end
        data=load(fullfile(folder,[idCase '.mat']),'dataset');ds=data.dataset;
        actual=cell(1,ds.numElements);
        for j=1:numel(actual),actual{j}=benchTrace(ds{j}.Values);end
        check=benchCompare(ref,actual,port,bias,1,idCase);
        count=count+check.samples_compared;worst=max(worst,check.max_abs_error);
    end
    row=table(string(id),numel(unique([toggled sink])),report.caseCount,count,worst, ...
        'VariableNames',{'model','distinct_sites','fault_cases','scalar_values_with_baseline','max_error'});
    results=[results;row]; %#ok<AGROW>
    fprintf('ARCH_CAMPAIGN_PASS %s %d values\n',id,count);clear closeModel
end
writetable(results,outputCsv);
end

function closePair(win,model)
delete(win);close_system(model,0);
end
