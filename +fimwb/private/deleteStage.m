function deleteStage(stage)
% Delete connected stage branches without leaving dangling Simulink lines.
parent=get_param(stage,'Parent');ports=get_param(stage,'PortHandles');
for input=reshape(ports.Inport,1,[])
    line=get_param(input,'Line');
    if line~=-1
        source=get_param(line,'SrcPortHandle');
        if source>0,delete_line(parent,source,input);else,delete_line(line);end
    end
end
for output=reshape(ports.Outport,1,[])
    line=get_param(output,'Line');
    if line~=-1,delete_line(line);end
end
delete_block(stage);
end
