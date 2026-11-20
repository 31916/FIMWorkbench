function window=chooseValues(parent,setting,site,values,onApply)
% Typed controls keep the stored axis values independent of text serialization.
if isempty(values),values={};end
window=uifigure('Name','Choose sweep values','Position',[220 180 620 400],'WindowStyle','modal');
layout=uigridlayout(window,[5 1],'RowHeight',{62,32,'1x',28,32});
uilabel(layout,'Text',faultDescription(setting.type),'WordWrap','on');
entry=uigridlayout(layout,[1 3],'Padding',0,'ColumnWidth',{'1x',110,110});
choices=operatorChoices(setting.type,site);
if ~isempty(choices)
    value=uidropdown(entry,'Items',choices,'Tag','candidateValue');
elseif ismember(setting.type,{'asr','ror','lor'})
    value=uieditfield(entry,'text','Value',char(setting.value),'Tag','candidateValue');
else
    value=uieditfield(entry,'numeric','Value',double(setting.value),'Tag','candidateValue');
end
uibutton(entry,'Text','Add value','Tag','addValue','ButtonPushedFcn',@addValue);
uibutton(entry,'Text','Remove','Tag','removeValue','ButtonPushedFcn',@removeValue);
list=uilistbox(layout,'Tag','valueList','Multiselect','on');
status=uilabel(layout,'Text','','Tag','valueStatus');
buttons=uigridlayout(layout,[1 3],'Padding',0,'ColumnWidth',{'1x',110,110});
uilabel(buttons,'Text','Each listed value becomes a campaign level.');
uibutton(buttons,'Text','Cancel','ButtonPushedFcn',@(~,~)delete(window));
uibutton(buttons,'Text','Use values','Tag','applyValues','ButtonPushedFcn',@apply);
refresh();
    function refresh()
        list.Items=cellfun(@(v)char(string(v)),values,'UniformOutput',false);
        list.ItemsData=1:numel(values);
    end
    function addValue(~,~)
        try
            candidate=setting;candidate.value=value.Value;candidate=checkFault(candidate,site);
            assert(~any(cellfun(@(v)isequaln(v,candidate.value),values)),'This value is already listed.');
            values{end+1}=candidate.value;refresh();status.Text='';
        catch err
            status.Text=fimwb.internal.diagnosticText(err);
        end
    end
    function removeValue(~,~)
        if isempty(list.Value),return;end
        values(list.Value)=[];refresh();
    end
    function apply(~,~)
        if isvalid(parent),onApply(values);end
        delete(window);
    end
end
