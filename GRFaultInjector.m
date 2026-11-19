function window = GRFaultInjector()
%GRFaultInjector Open a benchmark or create a fault-enabled copy of a Simulink model.
% MATLABの「アプリ」タブまたは GRFaultInjector コマンドで起動します。
window=uifigure('Name','GR Fault Injector','Position',[120 120 640 300]);
layout=uigridlayout(window,[3 1]);
layout.RowHeight={68,150,'1x'};
benchmarks=uipanel(layout,'Title','ARCH-COMP ベンチマーク');
benchGrid=uigridlayout(benchmarks,[1 2]);
benchGrid.ColumnWidth={'1x',160};
models={'AT','AFC','NN','CC','SC','PM','F16','SB1','SB2','SB3','SB4','SB5'};
benchmark=uidropdown(benchGrid,'Items',models,'Tag','benchmark');
uibutton(benchGrid,'Text','ベンチマークを開く','Tag','openBenchmark', ...
    'ButtonPushedFcn',@(~,~) openModel('benchmark'));

custom=uipanel(layout,'Title','自分のSimulinkモデル');
form=uigridlayout(custom,[3 3]);
form.ColumnWidth={76,'1x',110};
uilabel(form,'Text','元モデル');
source=uieditfield(form,'text','Tag','source','ValueChangedFcn',@(~,~) suggestOutput());
uibutton(form,'Text','参照…','ButtonPushedFcn',@(~,~) browseSource());
uilabel(form,'Text','作業用コピー');
output=uieditfield(form,'text','Tag','output');
uibutton(form,'Text','保存先…','ButtonPushedFcn',@(~,~) browseOutput());
buttons=uigridlayout(form,[1 2],'Padding',0);
buttons.Layout.Column=[1 3];
uibutton(buttons,'Text','作業用コピーを作成','Tag','build', ...
    'ButtonPushedFcn',@(~,~) openModel('build'));
uibutton(buttons,'Text','保存したコピーを開く…','Tag','reopen', ...
    'ButtonPushedFcn',@(~,~) openModel('reopen'));
status=uilabel(layout,'Text','','Tag','status');

    function browseSource()
        [name,folder]=uigetfile({'*.slx;*.mdl','Simulink (*.slx, *.mdl)'},'元モデルを選択');
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
            '新しい作業用コピーの保存先',output.Value);
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
                        [~,file]=grfi.openBenchmark(benchmark.Value);
                    catch err
                        if ~strcmp(err.identifier,'grfi:SbWeightsPath'),rethrow(err);end
                        folder=uigetdir(pwd,'SB用に英数字のパスを持つ作業フォルダを選択');
                        if isequal(folder,0),return;end
                        [~,file]=grfi.openBenchmark(benchmark.Value,folder);
                    end
                case 'build'
                    assert(isfile(source.Value),'元モデルを選択してください。');
                    file=output.Value;
                    assert(~isempty(file),'作業用コピーの保存先を指定してください。');
                    status.Text='注入箇所を調べて作業用コピーを作成しています。';
                    drawnow limitrate nocallbacks
                    grfi.build(source.Value,file);
                    grfi.editor(file);
                case 'reopen'
                    [name,folder]=uigetfile({'*.slx;*.mdl','Simulink (*.slx, *.mdl)'}, ...
                        '故障を設定した作業用コピーを選択');
                    if isequal(name,0),return;end
                    file=fullfile(folder,name);
                    grfi.editor(file);
            end
            open_system(file);
            status.Text=file;
            status.Tooltip=file;
        catch err
            status.Text=err.message;
            status.Tooltip=err.message;
            uialert(window,err.message,'モデルを開けませんでした');
        end
    end
end
