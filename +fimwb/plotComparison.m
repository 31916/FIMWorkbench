function win = plotComparison(folder,visible)
%PLOTCOMPARISON Reopen baseline and case traces directly from an experiment folder.
if nargin<2,visible='on';end
baseline=readTrace(folder,'baseline');
manifest=fullfile(folder,'runs.csv');
if isfile(manifest)
    runs=readtable(manifest,'TextType','string');
    cases=cellstr(runs.run(runs.run~="baseline"));
else
    files=dir(fullfile(folder,'case_*.csv'));cases=erase({files.name},'.csv');
end
assert(~isempty(cases),'This experiment contains no fault cases.');
win=uifigure('Name','Baseline and fault comparison','Visible',visible,'Position',[140 140 850 485]);
layout=uigridlayout(win,[4 1],'RowHeight',{32,32,0,'1x'});
controls=uigridlayout(layout,[1 3],'Padding',0,'ColumnWidth',{36,140,'1x'});
uilabel(controls,'Text','Case');
picker=uidropdown(controls,'Items',cases,'Tag','casePicker','ValueChangedFcn',@loadCase);
search=uieditfield(controls,'text','Tag','signalSearch','Placeholder','Find a signal or source block', ...
    'ValueChangingFcn',@(~,e)filter(e.Value),'ValueChangedFcn',@(src,~)filter(src.Value));
signal=uidropdown(layout,'Tag','signalPicker','ValueChangedFcn',@plotSignal);
notice=uilabel(layout,'Text','','Tag','caseStatus','WordWrap','on');
ax=uiaxes(layout);actual=[];channels=[];shown=[];
loadCase();
    function loadCase(~,~)
        file=fullfile(folder,[picker.Value '.csv']);
        if isfile(file)
            actual=readTrace(folder,picker.Value);
            notice.Text='';layout.RowHeight={32,32,0,'1x'};
        else
            info=jsondecode(fileread(fullfile(folder,[picker.Value '.json'])));
            assert(isfield(info,'status')&&strcmp(info.status,'failed'),'The case trace is missing.');
            actual=baseline([],:);
            notice.Text=['Simulation failed. ' info.diagnostic];notice.Tooltip=notice.Text;
            layout.RowHeight={32,32,58,'1x'};
        end
        channels=unique([baseline(:,{'signal','component'});actual(:,{'signal','component'})],'rows','stable');
        filter(search.Value);
    end
    function filter(query)
        shown=find(contains(channels.signal,strtrim(query),'IgnoreCase',true));
        if isempty(shown)
            signal.Items={'No matching signals'};signal.Enable='off';
            cla(ax);title(ax,'');legend(ax,'off');return
        end
        labels=channels.signal(shown)+" ["+channels.component(shown)+"]";
        old=signal.Value;signal.Enable='on';signal.Items=cellstr(labels);
        if any(labels==string(old)),signal.Value=old;end
        plotSignal();
    end
    function plotSignal(~,~)
        i=shown(strcmp(signal.Items,signal.Value));
        left=baseline(baseline.signal==channels.signal(i) & baseline.component==channels.component(i),:);
        right=actual(actual.signal==channels.signal(i) & actual.component==channels.component(i),:);
        cla(ax);hold(ax,'on');
        plot(ax,left.time_s,left.value,'DisplayName','Baseline (all off)','LineWidth',1.5);
        if ~isempty(right),plot(ax,right.time_s,right.value,'--','DisplayName',picker.Value,'LineWidth',1.5);end
        if any(left.imaginary~=0)||any(right.imaginary~=0)
            plot(ax,left.time_s,left.imaginary,':','DisplayName','Baseline imaginary');
            if ~isempty(right),plot(ax,right.time_s,right.imaginary,'-.','DisplayName','Case imaginary');end
        end
        hold(ax,'off');xlabel(ax,'Time (s)');ylabel(ax,'Signal value');grid(ax,'on');
        legend(ax,'show','Interpreter','none');title(ax,signal.Value,'Interpreter','none');
    end
end

function trace=readTrace(folder,id)
trace=readtable(fullfile(folder,[id '.csv']),'TextType','string');
file=fullfile(folder,[id '.json']);
if ~isfile(file),return;end
info=jsondecode(fileread(file));
if ~isfield(info,'sources') || isempty(info.sources),return;end
% Resolve each CSV identifier once. Equal names on different ports are distinct.
[keys,~,group]=unique(trace.signal,'stable');
labels=keys;
for k=1:numel(keys)
    n=str2double(extractBefore(keys(k),"/"));source=info.sources(n);
    if isempty(source.block)||isempty(source.port),continue;end
    block=regexprep(string(source.block),'[\r\n]+',' ');
    labels(k)=extractAfter(keys(k),"/")+" | "+block+" (port "+source.port+")";
end
[~,~,index]=unique(labels);
counts=accumarray(index,1);duplicate=counts(index)>1;
labels(duplicate)=keys(duplicate)+" | "+labels(duplicate);
trace.signal=labels(group);
end
