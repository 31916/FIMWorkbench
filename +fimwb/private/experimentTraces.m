function sources=experimentTraces(dataset,file)
% Keep each component on the time grid Simulink actually returned.
sources=repmat(struct('block','','port',[]),1,dataset.numElements);
for port = 1:dataset.numElements
    element = dataset{port};
    path=element.BlockPath.convertToCell();
    sources(port).block=strjoin(path,' > ');
    sources(port).port=element.PortIndex;
    label = string(element.Name);
    if strlength(label)==0 && element.BlockPath.getLength>0
        block = element.BlockPath.getBlock(element.BlockPath.getLength);
        [~,label] = fileparts(block);
    end
    write(element.Values,string(port)+"/"+label);
end
assert(isfile(file),'No numeric output or logged signal was available to compare.');

    function write(value,label)
        if isstruct(value)
            fields = fieldnames(value);
            for b = 1:numel(value)
                path = label;
                if numel(value)>1,path = path+"("+b+")";end
                for n = 1:numel(fields)
                    write(value(b).(fields{n}),path+"/"+fields{n});
                end
            end
            return
        end
        assert(isa(value,'timeseries'),'Unsupported logging format for %s. Use timeseries logging.',label);
        t = double(value.Time(:));
        if isempty(t),return;end
        samples = value.Data;
        if ~value.IsTimeFirst
            samples = permute(samples,[ndims(samples),1:ndims(samples)-1]);
        end
        samples = reshape(double(samples),numel(t),[]);
        for component = 1:size(samples,2)
            v = samples(:,component);
            block = table(t,repmat(label,size(t)),repmat(component,size(t)),real(v),imag(v), ...
                'VariableNames',{'time_s','signal','component','value','imaginary'});
            if isfile(file)
                writetable(block,file,'WriteMode','append','WriteVariableNames',false);
            else
                writetable(block,file);
            end
        end
    end
end
