function results=checkFimReplacements(folder,profiles)
% Exercise each FIM replacement against a different original operator.
model='fimwb_operator_source';new_system(model);
set_param(model,'SolverType','Fixed-step','Solver','FixedStepDiscrete','FixedStep','1','StopTime','7','BooleanDataType','off');
x=[0;0;0;0;-2;-2;2;2];y=[0;0;3;3;0;0;1;1];z=repmat([0;1],4,1);
inputs={x,y,z};names={'X','Y','Z'};
for k=1:numel(names)
    label=names{k};
    add_block('simulink/Sources/From Workspace',[model '/' label],...
        'VariableName',mat2str([(0:7)' inputs{k}]),'SampleTime','1','Interpolate','off','OutputAfterFinalValue','Holding final value');
    add_block('built-in/DataTypeConversion',[model '/' label 'Bool'],'OutDataTypeStr','boolean');
    connect(label,[label 'Bool'],1);
    add_block('built-in/DataTypeConversion',[model '/' label 'Int'],'OutDataTypeStr','int16');
    connect(label,[label 'Int'],1);
end
add_block('built-in/Mux',[model '/Bits'],'Inputs','3');
for k=1:3,connect([names{k} 'Bool'],'Bits',k);end
two={'XBool','YBool'};three=[two {'ZBool'}];ints={'XInt','YInt'};
gate('And2','AND',two,'boolean');gate('Or2','OR',two,'boolean');
gate('Or3','OR',three,'boolean');gate('Numeric','OR',{'X','Y'},'Inherit: Logical (see Configuration Parameters: Optimization)');
gate('Reduction','AND',{'Bits'},'boolean');gate('ScalarNot','NOT',{'XBool'},'boolean');
gate('VectorNot','NOT',{'Bits'},'boolean');
add_block('built-in/Terminator',[model '/VectorTerm']);connect('VectorNot','VectorTerm',1);
for item={'Greater','Less'}
    name=item{1};original='>';if strcmp(name,'Less'),original='<';end
    add_block('built-in/RelationalOperator',[model '/' name],'Operator',original);
    for k=1:2,connect(ints{k},name,k);end
end
for item={'Plus','Minus'}
    name=item{1};original='++';if strcmp(name,'Minus'),original='--';end
    add_block('built-in/Sum',[model '/' name],'Inputs',original);
    for k=1:2,connect(names{k},name,k);end
end
outputs={'And2','Or2','Or3','Numeric','Reduction','ScalarNot','Greater','Less','Plus','Minus'};
for k=1:numel(outputs)
    label=sprintf('Out%d',k);add_block('built-in/Outport',[model '/' label],'Port',num2str(k));
    connect(outputs{k},label,1);
end
src=fullfile(folder,[model '.slx']);save_system(model,src);
native=sim(model,'SaveOutput','on','OutputSaveName','yout','SaveFormat','Dataset','ReturnWorkspaceOutputs','on');
outputTypes=arrayfun(@(k)string(class(native.yout{k}.Values.Data)),1:numel(outputs));
close_system(model,0);
sites=fimwb.scan(src);ops=sites(strcmp({sites.kind},'operator'));
assert(~ismember('VectorNot',{ops.source}),'A vector NOT cannot be replaced with a scalar reduction.');
ordered=arrayfun(@(k)find(strcmp({ops.source},outputs{k})),1:numel(outputs));
ops=ops(ordered);faults=fimwb.defaultFaults(ops);
choices={'AND','OR','NAND','NOR','XOR','NXOR'};
[planned,excluded]=fimwb.plan(src,profiles);
for k=1:6
    mask=strcmp({planned.type},'lor') & strcmp({planned.site},ops(k).id);
    valid=choices(~strcmp(choices,ops(k).originalOperator));
    if strcmp(outputs{k},'ScalarNot'),valid={'AND','OR'};end
    assert(isequal({planned(mask).value},valid));
    same=strcmp({excluded.type},'lor') & strcmp({excluded.site},ops(k).id);
    assert(sum(same)==numel(choices)-numel(valid));
end
scratch=tempname;mkdir(scratch);cleanup=onCleanup(@()rmdir(scratch,'s')); %#ok<NASGU>
batch=fimwb.sweep(src,struct('type','LOR','values',6),scratch,1);
assert(strcmp(batch.status,'compiled')&&strcmp(batch.fault.value,'NXOR'));
saved=jsondecode(fileread(fullfile(fileparts(batch.file),'configuration.json')));
assert(strcmp(saved.faults.type,'lor')&&strcmp(saved.faults.value,'NXOR'));
variant='demo_fim_replacements';file=fullfile(folder,[variant '.slx']);
fimwb.build(src,struct('faults',faults),file);load_system(file);guard=onCleanup(@()close_system(variant,0)); %#ok<NASGU>
a=logical(x);b=logical(y);c=logical(z);
baseline=double([a&b,a|b,a|b|c,a|b,a&b&c,~a,x>y,x<y,x+y,-x-y]);
results=struct('test',{},'max_error',{});compare('operator_slots_off',baseline);
for k=1:numel(choices)
    slot=1+strcmp(choices{k},'AND');
    trial(slot,k,logic(choices{k},[a b]),['lor_' choices{k}]);
end
trial(3,'XOR',xor(xor(a,b),c),'lor_three_input_xor');
trial(3,'NXOR',~xor(xor(a,b),c),'lor_three_input_nxor');
trial(4,'NAND',~(a&b),'lor_numeric_inputs_inherited_output');
trial(5,'XOR',xor(xor(a,b),c),'lor_vector_reduction');
trial(6,'OR',a,'lor_scalar_not');
for op={'>','<','<=','>=','==','~='}
    value=op{1};slot=7+strcmp(value,'>');
    switch value
        case '>',answer=x>y;label='gt';
        case '<',answer=x<y;label='lt';
        case '<=',answer=x<=y;label='le';
        case '>=',answer=x>=y;label='ge';
        case '==',answer=x==y;label='eq';
        case '~=',answer=x~=y;label='ne';
    end
    order={'>','<','<=','>=','==','~='};
    trial(slot,find(strcmp(order,value)),answer,['ror_' label]);
end
for signs={'+-','--','++','-+'}
    value=signs{1};slot=9+strcmp(value,'++');
    factors=2*(value=='+')-1;
    label=strrep(strrep(value,'+','p'),'-','m');
    order={'+-','--','++','-+'};
    trial(slot,find(strcmp(order,value)),factors(1)*x+factors(2)*y,['asr_' label]);
end
target=baseline;time=(0:7)';during=time>=2 & time<6;
fimwb.setFault(variant,1,struct('value','XNOR','enabled',true,'start',2,'stop',6));
target(during,1)=~xor(a(during),b(during));compare('lor_finite_window',target);
fimwb.setFault(variant,1,struct('stop',[]));target(time>=2,1)=~xor(a(time>=2),b(time>=2));
compare('lor_until_simulation_end',target);
fimwb.setFault(variant,1,struct('enabled',false));compare('lor_disabled_again',baseline);
% Keep a working example with a finite, enabled NXOR substitution.
fimwb.setFault(variant,1,struct('enabled',true,'stop',6));save_system(variant);

    function connect(from,to,port)
        add_line(model,[from '/1'],sprintf('%s/%d',to,port),'autorouting','on');
    end
    function gate(name,op,sources,dataType)
        add_block('built-in/Logic',[model '/' name],'Operator',op,'Inputs',num2str(numel(sources)),...
            'AllPortsSameDT','off','OutDataTypeStr',dataType);
        for input=1:numel(sources),connect(sources{input},name,input);end
    end
    function trial(slot,value,answer,label)
        kind=upper(ops(slot).faults{1});
        fimwb.setFault(variant,slot,struct('type',kind,'value',value,'enabled',true));
        target=baseline;target(:,slot)=answer;compare(label,target);
        fimwb.setFault(variant,slot,struct('enabled',false));
    end
    function compare(label,target)
        out=sim(variant,'SaveOutput','on','OutputSaveName','yout','SaveFormat','Dataset','ReturnWorkspaceOutputs','on');
        ds=out.yout;
        actual=zeros(size(target));
        for j=1:ds.numElements
            assert(isequal(ds{j}.Values.Time,(0:7)'));
            assert(strcmp(class(ds{j}.Values.Data),outputTypes(j)),'The replacement changed the output type.');
            actual(:,j)=double(ds{j}.Values.Data(:));
        end
        err=max(abs(actual-target),[],'all');assert(err==0,'%s maximum error %g.',label,err);
        results(end+1)=struct('test',label,'max_error',err);
    end
end

function expected=logic(op,bits)
switch op
    case 'AND',expected=all(bits,2);
    case 'OR',expected=any(bits,2);
    case 'NAND',expected=~all(bits,2);
    case 'NOR',expected=~any(bits,2);
    case 'XOR',expected=mod(sum(bits,2),2)==1;
    case 'NXOR',expected=mod(sum(bits,2),2)==0;
end
end
