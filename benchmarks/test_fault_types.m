function results=test_fault_types(folder)
% Exercise every operator, shift window boundaries, overlaps, plan/sweep and rollback.
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);
assert(~isfolder(folder),'Use a new test directory.');mkdir(folder);
[~,a]=fileattrib(folder);folder=a.Name;old=pwd;c=onCleanup(@()cd(old));cd(folder); %#ok<NASGU>
model='fimwb_fixture';
new_system(model);add_block('simulink/Sources/Digital Clock',[model '/Clock'],'SampleTime','.1');
add_block('simulink/Math Operations/Bias',[model '/Signal'],'Bias','-1');w('Clock/1','Signal/1');
add_block('simulink/Sources/Constant',[model '/Two'],'Value','2');
add_block('simulink/Math Operations/Sum',[model '/Sum'],'Inputs','++');
add_block('simulink/Math Operations/Product',[model '/Product'],'Inputs','**');
add_block('simulink/Logic and Bit Operations/Relational Operator',[model '/Compare'],'Operator','<');
for b={'Sum','Product','Compare'}
    w('Signal/1',[b{1} '/1']);w('Two/1',[b{1} '/2']);
end
names={'Signal','Signal','Sum','Product','Compare','Compare'};
for q=1:numel(names)
    add_block('built-in/Outport',sprintf('%s/Y%d',model,q),'Port',num2str(q),'SampleTime','0.1');
    w([names{q} '/1'],sprintf('Y%d/1',q));
end
set_param(model,'SolverType','Fixed-step','Solver','FixedStepDiscrete','FixedStep','.1','StopTime','2');
file=fullfile(folder,[model '.slx']);save_system(model,file);close_system(model,0);
catalog=fimwb.scan(file);
edge=@(target) lookup(catalog,'endpoint',target);
op=@(target) lookup(catalog,'operator',target);
stem=lookup(catalog,'stem','Signal');
base=readModel(file);x=base(:,1);t=(0:numel(x)-1)'*.1;
profiles={struct('type','bias','values',[-2 3]),struct('type','bit_flip')};
cases=fimwb.plan(file,profiles);
assert(any(strcmp({cases.type},'bit_flip')) && any([cases(strcmp({cases.type},'bias')).value]==3));
batch=fimwb.sweep(file,profiles,fullfile(folder,'sweep'),[1 numel(cases)]);
assert(all(strcmp({batch.status},'compiled')));
repeat=fimwb.sweep(file,profiles,fullfile(folder,'sweep'),[1 numel(cases)]);
assert(all(strcmp({repeat.status},'reused')));
types={'bias','gain','negate','absolute','invert','stuck_at','zero','package_drop','delay','hold_last','bit_flip','asr','s2p','p2s','ror','noise'};
names={'Bias/Offset','gain','Negate','Absolute','Invert','stuck_at','Stuck-at 0','Package Drop',...
    'Time Delay','Stuck-at','Bit Flip','ASR','S2P','P2S','ROR','Noise'};
results=struct('test',{},'max_error',{});
for q=1:numel(types)
    kind=types{q};s=edge('Y1');column=1;val=[];start=0;stop=[];expected=x;
    switch kind
        case 'bias',val=.5;expected=x+.5;
        case 'gain',val=3;expected=x*3;
        case 'negate',expected=-x;
        case 'absolute',expected=abs(x);
        case 'invert',expected=double(~x);
        case 'stuck_at',val=.75;expected(:)=.75;
        case 'zero',expected(:)=0;
        case 'package_drop',val=-3;start=.4;stop=1;expected(t>=.4 & t<1)=val;
        case 'delay',val=.3;expected=[zeros(3,1);x(1:end-3)];
        case 'hold_last',start=.4;stop=1;val=0;expected(t>=.4 & t<1)=x(4);
        case 'bit_flip',s=edge('Y5');column=5;expected=double(~base(:,5));
        case 'asr',s=op('Sum');column=3;val='+-';expected=x-2;
        case 's2p',s=op('Sum');column=3;expected=x*2;
        case 'p2s',s=op('Product');column=4;expected=x+2;
        case 'ror',s=op('Compare');column=5;val='>';expected=double(x>2);
        case 'noise',val=.01;
    end
    fault=struct('site',s,'type',names{q},'enabled',true,'value',val,'start',start,'stop',stop);
    name=['demo_' kind];gen=fullfile(folder,[name '.slx']);fimwb.build(file,struct('faults',fault),gen);
    load_system(gen);clean=onCleanup(@()close_system(name,0));
    got=runOpen(name);
    if strcmp(kind,'noise')
        assert(max(abs(got(:,1)-x))>0.01 && isequal(runOpen(name),got),'Noise seed does not replay.');
        fimwb.setFault(name,1,struct('value',.04));scaled=runOpen(name);
        expected=x+2*(got(:,1)-x);got=scaled;
    end
    target=base;target(:,column)=expected;
    if strcmp(kind,'ror'),target(:,6)=expected;end
    e=max(abs(got-target),[],'all');
    assert(e<2e-10,'%s maximum error %g.',kind,e);
    fimwb.setFault(name,1,struct('enabled',false));
    assert(isequal(runOpen(name),base),'OFF regression for %s.',kind);
    results(end+1)=struct('test',kind,'max_error',e); %#ok<AGROW>
    clear clean;
end
% Branch-specific fault is listed before the stem in the config. It must
% still act downstream, and the changed operand must reach the active Sum mutation.
a=struct('site',edge('Sum'),'type','gain','enabled',true,'value',2);
b=struct('site',stem,'type','bias','enabled',true,'value',1);
d=struct('site',op('Sum'),'type','asr','enabled',true,'value','+-');
combo=fullfile(folder,'demo_overlap.slx');fimwb.build(file,struct('faults',{{a,b,d}}),combo);
got=readModel(combo);expected=[x+1,x+1,2*(x+1)-2,2*(x+1),double(x+1<2),double(x+1<2)];
e=max(abs(got-expected),[],'all');assert(e<1e-12,'Branch/operator overlap failed.');
results(end+1)=struct('test','stem_branch_operator','max_error',e);
a.site=edge('Y1');b.site=a.site;
reverse=fullfile(folder,'demo_order.slx');fimwb.build(file,struct('faults',{{a,b}}),reverse);
gotReversed=readModel(reverse);e=max(abs(gotReversed(:,1)-(2*x+1)));
assert(e<1e-12);results(end+1)=struct('test','same_site_order','max_error',e);
% A rejected setting leaves neither a destination file nor a damaged working model.
bad=fullfile(folder,'bad_setting.slx');failed=false;
try, fimwb.build(file,struct('faults',struct('site',edge('Y1'),'type','bit_flip')),bad);
catch,failed=true;end
assert(failed && ~isfile(bad));
load_system(combo);clean=onCleanup(@()close_system('demo_overlap',0));
failed=false;try,fimwb.setFault('demo_overlap',3,struct('value','++-'));catch,failed=true;end
assert(failed&&isequal(runOpen('demo_overlap'),got));
clear clean;
% Continuous Transport Delay uses elapsed seconds on a ramp. Reconfigure
% the same slot to verify hold-last uses the preceding major solver step.
cm='fimwb_continuous_source';new_system(cm);
add_block('simulink/Sources/Clock',[cm '/Time']);
add_block('built-in/Outport',[cm '/Y']);add_line(cm,'Time/1','Y/1');
set_param(cm,'SolverType','Fixed-step','Solver','ode4','FixedStep','0.1','StopTime','1');
cf=fullfile(folder,[cm '.slx']);save_system(cm,cf);close_system(cm,0);
cs=fimwb.scan(cf);site=lookup(cs,'endpoint','Y');variant='demo_continuous';
fault=struct('site',site,'type','delay','enabled',true,'value',.2);
vf=fullfile(folder,[variant '.slx']);fimwb.build(cf,struct('faults',fault),vf);load_system(vf);
release=onCleanup(@()close_system(variant,0));original=readModel(cf);sample=runOpen(variant);
e=max(abs(sample-max(0,original-.2)));assert(e<1e-10);
results(end+1)=struct('test','continuous_delay','max_error',e);
fimwb.setFault(variant,1,struct('type','hold_last','value',0,'start',.5,'stop',.8));
sample=runOpen(variant);expected=original;expected(original>=.5 & original<.8)=.4;
e=max(abs(sample-expected));assert(e<1e-10);
results(end+1)=struct('test','continuous_hold_last','max_error',e);clear release;
results=[results checkFimReplacements(folder,fullfile(root,'examples','profiles.json')) checkArrayFaults(folder)];
writetable(struct2table(results),fullfile(folder,'results.csv'));disp(struct2table(results));
    function w(from,to),add_line(model,from,to,'autorouting','on');end
end

function id=lookup(sites,kind,key)
mask=strcmp({sites.kind},kind);s=sites(mask);
if strcmp(kind,'endpoint')
    idx=find(arrayfun(@(v)strcmp(v.destinations.path,key),s));
    if numel(idx)>1,idx=idx(arrayfun(@(i)strcmp(s(i).source,'Signal'),idx));end
else
    idx=find(strcmp({s.source},key));
end
assert(isscalar(idx));id=s(idx).id;
end

function y=readModel(file)
[~,name]=fileparts(file);load_system(file);c=onCleanup(@()close_system(name,0)); %#ok<NASGU>
y=runOpen(name);
end
function y=runOpen(name)
out=sim(name,'SaveOutput','on','OutputSaveName','yout','SaveFormat','Dataset','ReturnWorkspaceOutputs','on');
ds=out.yout;y=[];for k=1:ds.numElements,y(:,k)=double(ds{k}.Values.Data(:));end
end
