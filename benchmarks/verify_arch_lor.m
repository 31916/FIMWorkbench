function verify_arch_lor(outputCsv)
% Compare every planned ARCH-COMP LOR with a native Simulink block replacement.
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);
ids={'AT','AFC','NN','CC','SC','PM','F16','SB1','SB2','SB3','SB4','SB5'};
rows=struct('model',{},'site',{},'original',{},'replacement',{},'local_samples',{},'output_samples',{},'max_error',{});
scratch=tempname;mkdir(scratch);cleanup=onCleanup(@()rmdir(scratch,'s')); %#ok<NASGU>
for k=1:numel(ids)
    id=ids{k};catalog=jsondecode(fileread(fullfile(root,'verification','arch2026',id,'sites.json')));
    sites=catalog(arrayfun(@(s)any(strcmp('lor',s.faults),'all'),catalog));
    if isempty(sites),continue;end
    working=fullfile(scratch,id);mkdir(working);
    [src,T,u]=benchSource(id,root,working);
    rows=[rows compareModel(id,src,sites,T,u,working)]; %#ok<AGROW>
end
writetable(struct2table(rows,'AsArray',true),outputCsv);
end

function rows=compareModel(id,src,sites,T,u,working)
[~,~,ext]=fileparts(src);ref='fimwb_native_logic';variant='fimwb_injected_logic';
nativeFile=fullfile(working,[ref ext]);copyfile(src,nativeFile);
file=fullfile(working,[variant ext]);faults=fimwb.defaultFaults(sites);
paths=fimwb.build(src,struct('faults',faults),file);
load_system(nativeFile);window=fimwb.editor(file,'off');guard=onCleanup(@()closeModels(window,ref,variant)); %#ok<NASGU>
grid=findall(window,'Type','uitable');picker=findall(window,'Tag','operatorPicker');
rows=struct('model',{},'site',{},'original',{},'replacement',{},'local_samples',{},'output_samples',{},'max_error',{});
for k=1:numel(sites)
    site=sites(k);block=[ref '/' site.source];stage=paths{k};
    origInputs=get_param(block,'Inputs');original=get_param(block,'Operator');
    assert(strcmp(site.originalOperator,original));
    select=struct('Indices',[k 5]);feval(grid.CellSelectionCallback,grid,select);
    opts=reshape(site.replacementOperators,1,[]);
    assert(strcmp(picker.Enable,'on')&&isequal(picker.Items,opts));
    native=get_param(block,'PortHandles');injected=get_param(stage,'PortHandles');
    logPort(native.Outport,'on');logPort(injected.Outport,'on');
    for j=1:numel(opts)
        op=opts{j};
        set_param(block,'Inputs',num2str(site.operandCount),'Operator',op);
        picker.Value=op;feval(picker.ValueChangedFcn,picker,[]);
        setCell(grid,k,4,true);
        status=findall(window,'Tag','status');
        assert(strcmp(grid.Data{k,5},op)&&grid.Data{k,4},'%s %s: %s',site.id,op,status.Text);
        [expected,refSignal]=benchSim(ref,T,u,'fimwb_logic_trace');
        [actual,slotSignal]=benchSim(variant,T,u,'fimwb_logic_trace');
        assert(strcmp(refSignal.type,slotSignal.type));
        local=benchCompare({refSignal},{slotSignal},1,0,1,'logical operator output');
        full=benchCompare(expected,actual,1,0,1,'root outputs with LOR enabled');
        rows(end+1)=struct('model',id,'site',site.id,'original',original,'replacement',op,...
            'local_samples',local.samples_compared,'output_samples',full.samples_compared,...
            'max_error',max(local.max_abs_error,full.max_abs_error)); %#ok<AGROW>
    end
    % An invalid cell edit must retain both the previous operator and the picker selection.
    setCell(grid,k,5,'invalid');assert(strcmp(grid.Data{k,5},op)&&strcmp(picker.Value,op));
    setCell(grid,k,4,false);assert(~grid.Data{k,4});
    logPort(native.Outport,'off');logPort(injected.Outport,'off');
    set_param(block,'Operator',original,'Inputs',origInputs);
    fprintf('LOR_PASS %s %s %d replacements\n',id,site.id,numel(opts));
end
end

function logPort(port,mode)
set_param(port,'DataLogging',mode,'DataLoggingNameMode','Custom','DataLoggingName','fimwb_logic_trace');
end

function setCell(grid,row,col,value)
data=grid.Data;data{row,col}=value;grid.Data=data;
feval(grid.CellEditCallback,grid,struct('Indices',[row col]));
end

function closeModels(win,ref,variant)
delete(win);close_system(variant,0);close_system(ref,0);
end
