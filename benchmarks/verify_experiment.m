function result = verify_experiment(outputCsv)
%VERIFY_EXPERIMENT Check factorial cases, vector outputs, frozen inputs and rollback.
scratch=tempname;mkdir(scratch);
cleanup=onCleanup(@()discard(scratch));
src='fimwb_experiment_fixture';name='fimwb_experiment_cases';
assert(~bdIsLoaded(src)&&~bdIsLoaded(name),'Close the existing experiment fixtures first.');
new_system(src);
for side={'Left','Right'}
    label=side{1};
    add_block('built-in/Inport',[src '/' label],'SampleTime','0.1');
    add_block('built-in/Outport',[src '/' label ' result']);
    add_line(src,[label '/1'],[label ' result/1']);
end
set_param([src '/Right'],'PortDimensions','2');
set_param(src,'Solver','FixedStepDiscrete','FixedStep','0.1','StopTime','2');
file=fullfile(scratch,[src '.slx']);save_system(src,file);close_system(src,0);
sites=fimwb.scan(file);
a=sites(strcmp({sites.source},'Left')&strcmp({sites.kind},'endpoint'));
b=sites(strcmp({sites.source},'Right')&strcmp({sites.kind},'endpoint'));
settings={struct('site',a.id,'type','bias','enabled',true,'value',2,'start',0.5,'stop',1.5), ...
    struct('site',b.id,'type','gain','enabled',false,'value',1)};
copy=fullfile(scratch,[name '.slx']);paths=fimwb.build(file,struct('faults',{settings}),copy);
load_system(copy);closed=onCleanup(@()close_system(name,0));
[~,token]=fileparts(tempname);key=matlab.lang.makeValidName(['fimwb_fixture_' token]);
received=0;assignin('base',key,@inputData);
removeInput=onCleanup(@()evalin('base',['clear ' key]));
set_param(name,'LoadExternalInput','on','ExternalInput',[key '()'],'Description','unsaved user edit');
saved=cellfun(@(p)get_param(p,'UserData'),paths);
before=rng;hash=fimwb.fileHash(copy);
axes=struct('slot',{1,2,2},'field',{'enabled','value','enabled'},'levels',{[false true],[0.5 2],[false true]});
folder=fullfile(scratch,'factorial');
report=fimwb.experiment(name,folder,axes);
assert(received==1&&report.caseCount==8&&isequal(before,rng));
remember=load(fullfile(folder,'inputs.mat'),'externalInputs');
assert(numel(remember.externalInputs)==1 && size(remember.externalInputs{1},2)==4);
results=zeros(9,3);
for n=0:8
    if n==0,id='baseline';else,id=sprintf('case_%04d',n);end
    trace=readtable(fullfile(folder,[id '.csv']),'TextType','string');
    idx=max(n-1,0);leftOn=bitget(idx,1);rightOn=bitget(idx,3);
    factor=1;if rightOn,options=[0.5 2];factor=options(1+bitget(idx,2));end
    left=startsWith(trace.signal,"1/");right=~left;t=trace.time_s;
    expected=1+t;expected(left)=expected(left)+leftOn*2*(t(left)>=0.5 & t(left)<1.5);
    expected(right & trace.component==1)=10*factor;
    expected(right & trace.component==2)=0.5*t(right & trace.component==2)*factor;
    err=max(abs(trace.value-expected));assert(height(trace)==63 && err<1e-12);
    results(n+1,:)=[n,height(trace),err];
end
win=fimwb.plotComparison(folder,'off');viewer=onCleanup(@()delete(win));
pick=findall(win,'Tag','casePicker');pick.Value='case_0008';feval(pick.ValueChangedFcn,pick,[]);
signal=findall(win,'Tag','signalPicker');assert(numel(signal.Items)==3);
signal.Value=signal.Items{end};feval(signal.ValueChangedFcn,signal,[]);
assert(numel(findall(win,'Type','line'))==2);
assert(isequaln(saved,cellfun(@(p)get_param(p,'UserData'),paths)) && strcmp(get_param(name,'Dirty'),'on'));
assert(strcmp(get_param(name,'Description'),'unsaved user edit') && strcmp(hash,fimwb.fileHash(copy)));
set_param(name,'Dirty','off');
failure=fullfile(scratch,'cancelled');
try
    fimwb.experiment(name,failure,axes,@cancelAfterBaseline);
    error('Test cancellation failed.');
catch err
    assert(strcmp(err.identifier,'fimwb:TestCancel'),'%s',err.message);
end
assert(received==2 && ~isfolder(failure) && strcmp(get_param(name,'Dirty'),'off') && isequal(before,rng));
assert(isequaln(saved,cellfun(@(p)get_param(p,'UserData'),paths)));
bad=axes;bad(2).levels=[1 NaN];
try
    fimwb.experiment(name,failure,bad);error('fimwb:TestInvalid','Bad axis accepted.');
catch err
    assert(~strcmp(err.identifier,'fimwb:TestInvalid'));
end
assert(~isfolder(failure) && received==2);
% A rejected simulation between two valid levels keeps both neighboring results.
callback=sprintf("if get_param('%s','UserData').fault.enabled && get_param('%s','UserData').fault.value==3, error('fimwb:TestCase','Requested test failure.'); end",paths{2},paths{2});
set_param(name,'StartFcn',char(callback));
axis=struct('slot',2,'field','value','levels',[1 3 2]);
recorded=fimwb.experiment(name,fullfile(scratch,'recorded'),axis,[],'record');
assert(recorded.completedCases==2 && recorded.failedCases==1);
runs=readtable(fullfile(recorded.folder,'runs.csv'),'TextType','string');
assert(isequal(runs.status,["completed";"completed";"failed";"completed"]));
assert(contains(runs.diagnostic(3),'Requested test failure') && ~isfile(fullfile(recorded.folder,'case_0002.csv')));
plotWin=fimwb.plotComparison(recorded.folder,'off');plotGuard=onCleanup(@()delete(plotWin));
casePicker=findall(plotWin,'Tag','casePicker');casePicker.Value='case_0002';feval(casePicker.ValueChangedFcn,casePicker,[]);
assert(numel(findall(plotWin,'Type','line'))==1 && contains(findall(plotWin,'Tag','caseStatus').Text,'Requested test failure'));
assert(isequaln(saved,cellfun(@(p)get_param(p,'UserData'),paths)));
result=array2table(results,'VariableNames',{'case_index','scalar_values','max_error'});
writetable(result,outputCsv);fprintf('EXPERIMENT_PASS 8 cases and baseline, one input evaluation\n');
clear removeInput closed

    function data=inputData()
        received=received+1;
        t=(0:0.1:2)';
        data=[t,received+t,repmat(10,size(t)),0.5*t];
    end
end

function cancelAfterBaseline(done,~)
if done==1,error('fimwb:TestCancel','Cancel after the baseline.');end
end

function discard(folder)
if isfolder(folder),rmdir(folder,'s');end
end
