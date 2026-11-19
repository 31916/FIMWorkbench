function drawStage(stage,meta)
% Keep the subsystem's external ports intact when toggling or retuning.
f=meta.fault;site=meta.site;
if strcmp(f.type,'asr')
    assert(numel(f.value)==meta.operandCount,'ASR needs one sign per operand.');
end
inside=find_system(stage,'SearchDepth',1,'FindAll','on','Type','line');
for handle=inside(:)'
    if ishandle(handle),delete_line(handle);end
end
blocks=find_system(stage,'SearchDepth',1,'Type','Block');
for n=2:numel(blocks)
    if ~ismember(get_param(blocks{n},'BlockType'),{'Inport','Outport'}),delete_block(blocks{n});end
end
healthy='Original/1';
changed=healthy;
if f.enabled
    input=healthy;
    if (contains(site.dataType,'int') && ismember(f.type,{'bias','gain'})) || ...
            (strcmp(site.dataType,'single') && strcmp(f.type,'noise'))
        add_block('simulink/Signal Attributes/Data Type Conversion',[stage '/ToDouble'],...
            'OutDataTypeStr','double','Position',[65 35 105 62]);
        wire(healthy,'ToDouble/1');input='ToDouble/1';
    end
    switch f.type
        case 'bias'
            op('simulink/Math Operations/Bias','Bias','Bias',number(f.value));
            wire(input,'Bias/1');changed='Bias/1';
        case {'gain','negate'}
            g=f.value;if strcmp(f.type,'negate'),g=-1;end
            op('simulink/Math Operations/Gain','Gain','Gain',number(g),'OutDataTypeStr','Inherit: Same as input');
            wire(input,'Gain/1');changed='Gain/1';
        case 'absolute'
            op('simulink/Math Operations/Abs','Abs');wire(healthy,'Abs/1');changed='Abs/1';
        case {'bit_flip','invert'}
            op('simulink/Logic and Bit Operations/Logical Operator','Not','Operator','NOT','Inputs','1');
            wire(healthy,'Not/1');changed='Not/1';
        case {'stuck_at','package_drop','zero'}
            v=f.value;if strcmp(f.type,'zero'),v=0;end
            literal=number(v);dims=site.dimensions;
            if prod(dims(2:end))>1
                shape=dims(2:end);if dims(1)==1,shape=[1 shape];end
                literal=sprintf('repmat(%s,%s)',literal,mat2str(shape));
            end
            vector1D='off';if dims(1)==1,vector1D='on';end
            op('simulink/Sources/Constant','Replacement','Value',literal,'VectorParams1D',vector1D,'OutDataTypeStr',site.dataType,...
                'SampleTime',replacementTime(site.sampleTime));changed='Replacement/1';
        case 'noise'
            op('simulink/Sources/Band-Limited White Noise','Noise','Cov',number(f.value),...
                'Ts',number(f.period),'seed',number(f.seed));
            op('simulink/Math Operations/Sum','AddNoise','Inputs','++');
            wire(input,'AddNoise/1');wire('Noise/1','AddNoise/2');changed='AddNoise/1';
        case 'hold_last'
            if site.sampleTime(1)>0,lib='simulink/Discrete/Unit Delay';else,lib='simulink/Discrete/Memory';end
            add_block(lib,[stage '/Previous'],'InitialCondition',number(f.value),'Position',[210 130 264 158]);
            changed='Previous/1';
        case 'delay'
            if f.value>0
                if site.sampleTime(1)>0
                    op('simulink/Discrete/Delay','Delay','DelayLength',number(round(f.value/site.sampleTime(1))),...
                        'InitialCondition','0');
                else
                    op('simulink/Continuous/Transport Delay','Delay','DelayTime',number(f.value),'InitialOutput','0');
                end
                wire(healthy,'Delay/1');changed='Delay/1';
            end
        case {'asr','s2p','p2s','ror','lor'}
            switch f.type
                case 'asr',op('simulink/Math Operations/Sum','Mutation','Inputs',f.value);
                case 'p2s',op('simulink/Math Operations/Sum','Mutation','Inputs',repmat('+',1,meta.operandCount));
                case 's2p',op('simulink/Math Operations/Product','Mutation','Inputs',repmat('*',1,meta.operandCount));
                case 'ror',op('simulink/Logic and Bit Operations/Relational Operator','Mutation','Operator',f.value);
                case 'lor',op('simulink/Logic and Bit Operations/Logical Operator','Mutation',...
                        'Operator',f.value,'Inputs',num2str(meta.operandCount),'AllPortsSameDT','off','OutDataTypeStr','boolean');
            end
            for k=1:meta.operandCount
                operand=sprintf('Operand%d/1',k);
                if strcmp(f.type,'p2s') && isfield(site,'booleanOperands') && ismember(k,site.booleanOperands)
                    cast=sprintf('NumericOperand%d',k);y=85+30*k;
                    add_block('simulink/Signal Attributes/Data Type Conversion',[stage '/' cast], ...
                        'OutDataTypeStr',site.dataType,'Position',[65 y 104 y+22]);
                    wire(operand,[cast '/1']);operand=[cast '/1'];
                end
                wire(operand,sprintf('Mutation/%d',k));
            end
            changed='Mutation/1';
    end
    if ~strcmp(changed,healthy)
        op('simulink/Signal Attributes/Data Type Conversion','OutputType','OutDataTypeStr',site.dataType,...
            'RndMeth','Round','SaturateOnIntegerOverflow','on');
        wire(changed,'OutputType/1');changed='OutputType/1';
    end
    if f.start>0 || ~isempty(f.stop) || (strcmp(f.type,'hold_last') && prod(site.dimensions(2:end))>1)
        op('simulink/Sources/Step','Start','Time',number(f.start),'Before','0','After','1');
        gate='Start/1';
        if ~isempty(f.stop)
            op('simulink/Sources/Step','Stop','Time',number(f.stop),'Before','1','After','0');
            op('simulink/Logic and Bit Operations/Logical Operator','Within','Operator','AND','Inputs','2');
            wire(gate,'Within/1');wire('Stop/1','Within/2');gate='Within/1';
        end
        op('simulink/Signal Routing/Switch','Window','Criteria','u2 ~= 0');
        wire(changed,'Window/1');wire(gate,'Window/2');wire(healthy,'Window/3');changed='Window/1';
    end
end
wire(changed,'Result/1');
if f.enabled && strcmp(f.type,'hold_last'),wire(changed,'Previous/1');end
ports=find_system(stage,'SearchDepth',1,'BlockType','Inport');
for n=1:numel(ports)
    ph=get_param(ports{n},'PortHandles');
    if get_param(ph.Outport,'Line')<0
        stub=sprintf('Unused%d',n);y=270+25*n;
        add_block('built-in/Terminator',[stage '/' stub],'Position',[110 y 130 y+12]);
        wire([get_param(ports{n},'Name') '/1'],[stub '/1']);
    end
end
set_param(stage,'UserData',meta,'UserDataPersistent','on');

    function op(lib,name,varargin)
        % Fixed functional columns also make generated subsystems readable.
        names={'Bias','Gain','Abs','Not','Replacement','Noise','Delay','Mutation','AddNoise','OutputType','Start','Stop','Within','Window'};
        locations=[120 45;120 45;120 45;120 45;120 45;100 104;120 45;120 90;205 55;290 54;180 185;180 245;290 195;390 88];
        xy=locations(strcmp(names,name),:);
        add_block(lib,[stage '/' name],'Position',[xy xy+[62 32]],varargin{:});
    end
    function wire(src,dst)
        add_line(stage,src,dst,'autorouting','on');
    end
end

function s=number(v)
s=num2str(double(v),17);
end

function out=replacementTime(ts)
out='-1';
if isnumeric(ts)&&numel(ts)==2 && ts(1)>=0
    if isinf(ts(1)),out='inf';else,out=mat2str(ts,17);end
end
end
