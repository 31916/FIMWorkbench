function win = plotComparison(folder,visible)
%PLOTCOMPARISON Reopen baseline and case traces directly from an experiment folder.
if nargin<2,visible='on';end
baseline=readtable(fullfile(folder,'baseline.csv'),'TextType','string');
cases=dir(fullfile(folder,'case_*.csv'));
assert(~isempty(cases),'This experiment contains no completed cases.');
win=uifigure('Name','Baseline and fault comparison','Visible',visible,'Position',[140 140 850 485]);
layout=uigridlayout(win,[2 1],'RowHeight',{34,'1x'});
controls=uigridlayout(layout,[1 4],'Padding',0,'ColumnWidth',{36,140,45,'1x'});
uilabel(controls,'Text','Case');
picker=uidropdown(controls,'Items',erase({cases.name},'.csv'),'Tag','casePicker','ValueChangedFcn',@loadCase);
uilabel(controls,'Text','Signal');
signal=uidropdown(controls,'Tag','signalPicker','ValueChangedFcn',@plotSignal);
ax=uiaxes(layout);actual=[];channels=[];
loadCase();
    function loadCase(~,~)
        actual=readtable(fullfile(folder,[picker.Value '.csv']),'TextType','string');
        channels=unique([baseline(:,{'signal','component'});actual(:,{'signal','component'})],'rows','stable');
        labels=channels.signal+" ["+channels.component+"]";
        old=signal.Value;
        signal.Items=cellstr(labels);
        if any(labels==string(old)),signal.Value=old;end
        plotSignal();
    end
    function plotSignal(~,~)
        i=find(strcmp(signal.Items,signal.Value),1);
        left=baseline(baseline.signal==channels.signal(i) & baseline.component==channels.component(i),:);
        right=actual(actual.signal==channels.signal(i) & actual.component==channels.component(i),:);
        cla(ax);hold(ax,'on');
        plot(ax,left.time_s,left.value,'DisplayName','Baseline (all off)','LineWidth',1.5);
        plot(ax,right.time_s,right.value,'--','DisplayName',picker.Value,'LineWidth',1.5);
        if any(left.imaginary~=0)||any(right.imaginary~=0)
            plot(ax,left.time_s,left.imaginary,':','DisplayName','Baseline imaginary');
            plot(ax,right.time_s,right.imaginary,'-.','DisplayName','Case imaginary');
        end
        hold(ax,'off');xlabel(ax,'Time (s)');ylabel(ax,'Signal value');grid(ax,'on');
        legend(ax,'show','Interpreter','none');title(ax,signal.Value,'Interpreter','none');
    end
end
