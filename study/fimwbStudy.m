function result = fimwbStudy(action,folder,varargin)
%FIMWBSTUDY Prepare, time and score a four-trial, within-participant comparison.
% fimwbStudy('prepare',newFolder,participantNumber,originalFimDirectory)
% trial = fimwbStudy('start',folder,trialNumber)
% attempt = fimwbStudy('submit',folder,trialNumber,savedCandidateModel)
directory=java.io.File(char(folder));
if ~directory.isAbsolute(),directory=java.io.File(pwd,char(folder));end
folder=char(directory.getCanonicalPath());
switch action
    case 'prepare'
        participant=varargin{1};upstream=varargin{2};
        validateattributes(participant,{'numeric'},{'scalar','positive','integer'});
        assert(isfile(fullfile(upstream,'FISingle.m')) && isfile(fullfile(upstream,'FaultInjector_Master','FInjLib.slx')), ...
            'Supply the original FIM source directory containing FISingle.m.');
        assert(~isfolder(folder)&&~isfile(folder)&&isfolder(fileparts(folder)),'Choose a new study folder.');
        work=tempname(fileparts(folder));mkdir(work);
        cleanup=onCleanup(@()discard(work));
        source=makeFixture(work);
        % Balance tool order and task order separately in blocks of four participants.
        order=[1 4 3 2;3 2 1 4;2 3 4 1;4 1 2 3];
        tools=["FIM","FIM","Workbench","Workbench"];
        tasks=["A","B","A","B"];
        ix=order(1+mod(participant-1,4),:);
        result=table(repmat(participant,4,1),(1:4)',tools(ix)',tasks(ix)', ...
            'VariableNames',{'participant','trial','tool','task'});
        writetable(result,fullfile(work,'schedule.csv'));
        for n=1:height(result)
            run=fullfile(work,sprintf('trial_%d',n));mkdir(fullfile(run,'fixture'));
            copyfile(source,fullfile(run,'fixture','fim_study_plant.slx'));
            if result.tool(n)=="FIM"
                for script={'FISingle','FCSingle','Init_sys_input','fault_suite','replace_suite'}
                    copyfile(fullfile(upstream,[script{1} '.m']),run);
                end
                library=fullfile(run,'FaultInjector_Master');mkdir(library);
                copyfile(fullfile(upstream,'FaultInjector_Master','FInjLib.slx'),library);
                cfg=fullfile(run,'Configuration');mkdir(cfg);
                copyfile(fullfile(upstream,'Configuration','FIToolInitialization.mat'),cfg);
                studyConstant=0;save(fullfile(cfg,'constants.mat'),'studyConstant');
                writecell({'model','constants_thresholds','fault_injector_folder','fault_list'; ...
                    'fixture/fim_study_plant.slx','constants.mat','.','sites.csv'},fullfile(run,'model.csv'));
                writecell({'level','source','destination','parent','fault'},fullfile(cfg,'sites.csv'));
                writecell({'slot','value','onset','effect','duration','operator'},fullfile(cfg,'enable.csv'));
            end
        end
        delete(source);
        java.nio.file.Files.move(java.io.File(work).toPath(),java.io.File(folder).toPath(),javaArray('java.nio.file.CopyOption',0));
    case {'start','submit','stop'}
        schedule=readtable(fullfile(folder,'schedule.csv'),'TextType','string');
        n=varargin{1};validateattributes(n,{'numeric'},{'scalar','integer','>=',1,'<=',height(schedule)});
        run=fullfile(folder,sprintf('trial_%d',n));
        stream=java.io.RandomAccessFile(fullfile(run,'study.lock'),'rw');
        release=onCleanup(@()stream.close());
        lock=stream.getChannel().tryLock();assert(~isempty(lock),'This trial is being updated in another session.');
        state=fullfile(run,'start.mat');log=fullfile(run,'attempts.csv');
        if isfile(log)
            last=readtable(log,'TextType','string');
            assert(~last.passed(end) && last.outcome(end)~="stopped",'This trial has already ended.');
        end
        if strcmp(action,'start')
            if n>1
                previous=fullfile(folder,sprintf('trial_%d',n-1),'attempts.csv');
                assert(isfile(previous),'Finish the preceding trial first.');
                prev=readtable(previous,'TextType','string');
                assert(prev.passed(end) || prev.outcome(end)=="stopped",'Finish the preceding trial first.');
            end
            if ~isfile(state),started=utcNow();save(state,'started');end
            result=table2struct(schedule(n,:));
            result.folder=run;result.source=fullfile(run,'fixture','fim_study_plant.slx');
            [result.target,result.offset,result.onset]=taskDefinition(result.task);
            result.instruction=sprintf('Add a bias of %+g on the wire into Reading %s from %g s to the end. Keep the other output healthy. Save your model.',result.offset,result.target,result.onset);
            fprintf('%s | %s\n%s\n',result.tool,result.folder,result.instruction);
        else
            finished=utcNow();
            assert(isfile(state),'Start the trial before submitting a saved model.');
            s=load(state,'started');elapsed=finished-s.started;
            if isfile(log),elapsed=elapsed-sum(last.grading_s);end
            passed=false;errorValue=NaN;
            attempt=0;if isfile(log),attempt=last.attempt(end);end
            if strcmp(action,'stop')
                outcome="stopped";detail="Trial ended without an accepted model.";
            else
                attempt=attempt+1;
                try
                    [errorValue,points]=score(varargin{2},schedule.task(n),run);
                    passed=errorValue<1e-9;
                    detail=sprintf('Compared %d scalar values. Maximum absolute error %.9g.',points,errorValue);
                catch err
                    detail=err.message;
                end
                if passed,outcome="passed";else,outcome="retry";end
            end
            result=[schedule(n,:),table(attempt,finished,elapsed,utcNow()-finished,passed,outcome,errorValue,string(detail), ...
                'VariableNames',{'attempt','utc_epoch_s','elapsed_s','grading_s','passed','outcome','max_error','detail'})];
            if isfile(log),writetable(result,log,'WriteMode','append','WriteVariableNames',false);
            else,writetable(result,log);end
        end
    otherwise
        error('Use prepare, start, submit or stop.');
end
end

function file=makeFixture(folder)
name='fim_study_plant';
assert(~bdIsLoaded(name),'Close the existing fim_study_plant model first.');
new_system(name);closeModel=onCleanup(@()close_system(name,0));
for letter='AB'
    y=50+100*(letter-'A');
    sensor=['Sensor ' letter];output=['Reading ' letter];
    add_block('simulink/Sources/Digital Clock',[name '/' sensor],'SampleTime','0.01','Position',[35 y 75 y+30]);
    add_block('built-in/Outport',[name '/' output],'Position',[250 y 280 y+20]);
    add_line(name,[sensor '/1'],[output '/1']);
end
set_param(name,'Solver','ode4','FixedStep','0.01','StopTime','10');
file=fullfile(folder,[name '.slx']);save_system(name,file);
end

function [target,offset,onset]=taskDefinition(id)
if id=="A",target='A';offset=2;onset=1;else,target='B';offset=-3;onset=2;end
end

function [worst,points]=score(file,task,run)
library=fullfile(run,'FaultInjector_Master','FInjLib.slx');
if isfile(library)
    opened=~bdIsLoaded('FInjLib');
    if ~opened
        assert(strcmp(get_param('FInjLib','FileName'),library),'Close the FIM library from the other trial.');
    else
        load_system(library);
    end
    locked=get_param('FInjLib','Lock');
    set_param('FInjLib','Lock','off');
    resetLock=onCleanup(@()restoreLibrary(opened,locked));
end
[ok,a]=fileattrib(file);assert(ok && ~a.directory,'Candidate model file not found.');
[~,name]=fileparts(a.Name);
if bdIsLoaded(name)
    assert(strcmp(get_param(name,'FileName'),a.Name)&&strcmp(get_param(name,'Dirty'),'off'), ...
        'Save the candidate and close other copies with the same model name.');
else
    load_system(a.Name);guard=onCleanup(@()close_system(name,0));
end
out=sim(name,'StopTime','10','SaveOutput','on','OutputSaveName','study_result','SaveFormat','Dataset', ...
    'DatasetSignalFormat','timeseries','ReturnWorkspaceOutputs','on','LimitDataPoints','off','Decimation','1');
ds=out.study_result;assert(ds.numElements==2,'Expected the two fixture outputs.');
[target,offset,onset]=taskDefinition(task);
grid=(0:1000)'/100;
worst=0;points=0;
for k=1:2
    ts=ds{k}.Values;expected=grid;
    if k==target-'A'+1,expected=expected+offset*(grid>=onset);end
    assert(numel(ts.Time)==numel(grid)&&max(abs(ts.Time(:)-grid))<1e-11,'Unexpected sample times.');
    v=double(ts.Data(:));assert(numel(v)==numel(grid)&&all(isfinite(v)),'Invalid output.');
    worst=max(worst,max(abs(v-expected)));points=points+numel(v);
end
end

function restoreLibrary(opened,locked)
if opened,close_system('FInjLib',0);else,set_param('FInjLib','Lock',locked);end
end

function t=utcNow()
t=posixtime(datetime('now','TimeZone','UTC'));
end

function discard(folder)
if isfolder(folder),rmdir(folder,'s');end
end
