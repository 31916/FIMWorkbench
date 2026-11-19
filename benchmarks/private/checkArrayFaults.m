function results=checkArrayFaults(folder)
% Verify fixed-size signal shape, timing and data type with active faults.
model='fimwb_array_source';new_system(model);
t=(0:4)';x=[t-2 2*t];
add_block('simulink/Sources/From Workspace',[model '/Source'],'VariableName',mat2str([t x]),...
    'SampleTime','1','Interpolate','off','OutputAfterFinalValue','Holding final value');
add_block('built-in/Reshape',[model '/Column'],'OutputDimensionality','Column vector (2-D)');
add_block('built-in/DataTypeConversion',[model '/Single'],'OutDataTypeStr','single');
add_block('built-in/DataTypeConversion',[model '/Integer'],'OutDataTypeStr','int64');
add_block('built-in/Outport',[model '/MatrixOut'],'Port','1');
add_block('built-in/Outport',[model '/IntegerOut'],'Port','2');
add_line(model,'Source/1','Column/1');add_line(model,'Column/1','Single/1');add_line(model,'Single/1','MatrixOut/1');
add_line(model,'Source/1','Integer/1');add_line(model,'Integer/1','IntegerOut/1');
set_param(model,'SolverType','Fixed-step','Solver','FixedStepDiscrete','FixedStep','1','StopTime','4');
file=fullfile(folder,[model '.slx']);save_system(model,file);close_system(model,0);
sites=fimwb.scan(file);ends=sites(strcmp({sites.kind},'endpoint'));
to=arrayfun(@(p)string(p.destinations.path),ends);
settings=fimwb.defaultFaults([ends(to=="MatrixOut");ends(to=="IntegerOut")]);
variant='demo_array_faults';target=fullfile(folder,[variant '.slx']);
fimwb.build(file,struct('faults',settings),target);load_system(target);
guard=onCleanup(@()close_system(variant,0)); %#ok<NASGU>
results=struct('test',{},'max_error',{});[ordinary,shapes]=read();
assert(isequal(ordinary{1},x)&&isequal(ordinary{2},x));
trial(1,'zero',[],0,[],zeros(size(x)),'matrix_zero');
trial(1,'package_drop',-3,1,3,[x(1,:);-3 -3;-3 -3;x(4:5,:)],'matrix_package_drop');
trial(1,'hold_last',7,0,[],7*ones(size(x)),'matrix_hold_initial');
trial(1,'hold_last',0,2,4,[x(1:2,:);x(2,:);x(2,:);x(5,:)],'matrix_hold_window');
trial(1,'delay',2,0,[],[zeros(2);x(1:3,:)],'matrix_delay');
trial(2,'invert',[],0,[],double(~x),'int64_vector_invert');
trial(2,'stuck_at',-4,0,[],-4*ones(size(x)),'int64_vector_stuck_at');
fimwb.setFault(variant,1,struct('type','noise','enabled',true,'value',.01,'period',1));
[first,current]=read();assert(isequal(current,shapes)&&any(first{1}~=x,'all'));
fimwb.setFault(variant,1,struct('value',.04));
[second,current]=read();assert(isequal(current,shapes));
err=max(abs(second{1}-(x+2*(first{1}-x))),[],'all');
assert(err<1e-6);results(end+1)=struct('test','single_matrix_noise_power','max_error',err);
fimwb.setFault(variant,1,struct('enabled',false));[after,current]=read();
assert(isequal(after,ordinary)&&isequal(current,shapes));

    function trial(slot,kind,value,start,stop,expected,label)
        fimwb.setFault(variant,slot,struct('type',kind,'value',value,'start',start,'stop',stop,'enabled',true));
        [ys,current]=read();assert(isequal(current,shapes),'%s changed the signal shape.',label);
        err=max(abs(ys{slot}-expected),[],'all');assert(err==0,'%s maximum error %g.',label,err);
        assert(isequal(ys{3-slot},ordinary{3-slot}));
        results(end+1)=struct('test',label,'max_error',err);
        fimwb.setFault(variant,slot,struct('enabled',false));
    end
    function [signals,dimensions]=read()
        simout=sim(variant,'SaveOutput','on','OutputSaveName','yout','SaveFormat','Dataset','ReturnWorkspaceOutputs','on');
        log=simout.yout;signals=cell(1,2);dimensions=cell(1,2);
        for j=1:2
            s=log{j}.Values;
            if j==1,assert(isa(s.Data,'single'));else,assert(isa(s.Data,'int64'));end
            dimensions{j}=size(s.Data);assert(isequal(s.Time,t));
            values=double(s.Data);
            if ~s.IsTimeFirst,values=permute(values,[ndims(values) 1:ndims(values)-1]);end
            signals{j}=reshape(values,numel(t),[]);
        end
    end
end
