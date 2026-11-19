function window = FIMWorkbench()
%FIMWorkbench Open a benchmark or create a fault-enabled copy of a Simulink model.
% Open FIMWorkbench from the MATLAB Apps tab or the Command Window.
window=uifigure('Name','FIM Workbench','Position',[120 120 640 300]);
layout=uigridlayout(window,[3 1]);
layout.RowHeight={68,150,'1x'};
benchmarks=uipanel(layout,'Title','ARCH-COMP benchmarks');
benchGrid=uigridlayout(benchmarks,[1 2]);
benchGrid.ColumnWidth={'1x',160};
models={'AT','AFC','NN','CC','SC','PM','F16','SB1','SB2','SB3','SB4','SB5'};
benchmark=uidropdown(benchGrid,'Items',models,'Value','PM','Tag','benchmark');
uibutton(benchGrid,'Text','Open benchmark','Tag','openBenchmark', ...
    'ButtonPushedFcn',@(~,~) openModel('benchmark'));

custom=uipanel(layout,'Title','Your Simulink model');
form=uigridlayout(custom,[3 3]);
form.ColumnWidth={100,'1x',110};
uilabel(form,'Text','Source model');
source=uieditfield(form,'text','Tag','source','ValueChangedFcn',@(~,~) suggestOutput());
uibutton(form,'Text','Browse...','ButtonPushedFcn',@(~,~) browseSource());
uilabel(form,'Text','Working copy');
output=uieditfield(form,'text','Tag','output');
uibutton(form,'Text','Save as...','ButtonPushedFcn',@(~,~) browseOutput());
buttons=uigridlayout(form,[1 2],'Padding',0);
buttons.Layout.Column=[1 3];
uibutton(buttons,'Text','Create working copy','Tag','build', ...
    'ButtonPushedFcn',@(~,~) openModel('build'));
uibutton(buttons,'Text','Open saved copy...','Tag','reopen', ...
    'ButtonPushedFcn',@(~,~) openModel('reopen'));
footer=uigridlayout(layout,[1 2],'Padding',0,'ColumnWidth',{'1x',155});
status=uilabel(footer,'Text','','Tag','status');
if ~isfolder(fullfile(fileparts(mfilename('fullpath')),'verification','all_sites','AT'))
    uihyperlink(footer,'Text','Get benchmark data (.zip)','Tag','benchmarkDownload', ...
        'URL','https://github.com/31916/FIMWorkbench/archive/refs/tags/v2.2.0.zip');
end

    function browseSource()
        [name,folder]=uigetfile({'*.slx;*.mdl','Simulink (*.slx, *.mdl)'},'Select a source model');
        if isequal(name,0),return;end
        source.Value=fullfile(folder,name);
        suggestOutput();
    end

    function suggestOutput()
        [folder,name,ext]=fileparts(source.Value);
        if isempty(name),return;end
        output.Value=fullfile(folder,[name '_fi' ext]);
    end

    function browseOutput()
        [name,folder]=uiputfile({'*.slx;*.mdl','Simulink (*.slx, *.mdl)'}, ...
            'Save the new working copy',output.Value);
        if ~isequal(name,0),output.Value=fullfile(folder,name);end
    end

    function openModel(action)
        status.Text='';
        window.Pointer='watch';
        finish=onCleanup(@()set(window,'Pointer','arrow')); %#ok<NASGU>
        try
            switch action
                case 'benchmark'
                    try
                        fimwb.benchmarkFolder(benchmark.Value);
                    catch err
                        if ~strcmp(err.identifier,'fimwb:BenchmarkFolder'),rethrow(err);end
                        folder=uigetdir(pwd,'Select the extracted FIM Workbench checkout containing verification');
                        if isequal(folder,0),return;end
                        fimwb.benchmarkFolder(benchmark.Value,folder);
                    end
                    try
                        [~,file]=fimwb.openBenchmark(benchmark.Value);
                    catch err
                        if ~strcmp(err.identifier,'fimwb:SbWeightsPath'),rethrow(err);end
                        folder=uigetdir(pwd,'Choose a working folder with an ASCII-only path for the SB weights');
                        if isequal(folder,0),return;end
                        [~,file]=fimwb.openBenchmark(benchmark.Value,folder);
                    end
                case 'build'
                    assert(isfile(source.Value),'Select a source model.');
                    file=output.Value;
                    assert(~isempty(file),'Choose where to save the working copy.');
                    status.Text='Finding injection sites and creating the working copy...';
                    drawnow limitrate nocallbacks
                    fimwb.build(source.Value,file);
                    fimwb.editor(file);
                case 'reopen'
                    [name,folder]=uigetfile({'*.slx;*.mdl','Simulink (*.slx, *.mdl)'}, ...
                        'Select a saved working copy');
                    if isequal(name,0),return;end
                    file=fullfile(folder,name);
                    fimwb.editor(file);
            end
            open_system(file);
            status.Text=file;
            status.Tooltip=file;
        catch err
            status.Text=err.message;
            status.Tooltip=err.message;
            uialert(window,err.message,'Could not open model');
        end
    end
end
