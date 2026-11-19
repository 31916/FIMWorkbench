function sites = scan(modelFile)
%SCAN List compiled signal endpoints, common stems and replaceable operators.
[model,~,loaded] = openSource(modelFile); %#ok<ASGLU>
sites=scanNormal(model);
end

function sites=scanNormal(model)
mode=get_param(model,'SimulationMode');dirty=get_param(model,'Dirty');
reset=onCleanup(@() restoreMode(model,mode,dirty)); %#ok<NASGU>
if ~strcmp(mode,'normal'),set_param(model,'SimulationMode','normal');end
sites=collect(model);
end

function restoreMode(model,mode,dirty)
if ~strcmp(get_param(model,'SimulationMode'),mode),set_param(model,'SimulationMode',mode);end
set_param(model,'Dirty',dirty);
end

function sites=collect(model)
feval(model,[],[],[],'compile');
compiled = onCleanup(@() feval(model,[],[],[],'term')); %#ok<NASGU>
blocks = find_system(model,'SearchUnderMasks','all','SearchInsideLibraryLinks','on',...
    'MatchFilter',@Simulink.match.activeVariants,'Type','Block');
empty = struct('id','','kind','','source','','port',0,'destinations',[],...
    'operandCount',0,'originalOperator','','replacementOperators',{{}},...
    'dataType','','dimensions',[],'sampleTime',[],'faults',{{}},'reason','');
rows = {};
for b = 1:numel(blocks)
    block = blocks{b};
    ports = get_param(block,'PortHandles');
    sid = get_param(block,'SID');
    transient = transientPredictionWiring(get_param(block,'Parent'),model);
    for k = 1:numel(ports.Outport)
        output = ports.Outport(k);
        line = get_param(output,'Line');
        if line <= 0, continue; end
        dst = get_param(line,'DstPortHandle');
        dst = dst(dst>0);
        if isempty(dst), continue; end
        base = empty;
        base.source = block(numel(model)+2:end);
        base.port = k;
        base.dataType = get_param(output,'CompiledPortDataType');
        base.dimensions = get_param(output,'CompiledPortDimensions');
        base.sampleTime = get_param(output,'CompiledSampleTime');
        width = get_param(output,'CompiledPortWidth');
        [base.faults,base.reason] = signalFaults(base,width,get_param(output,'CompiledPortComplexSignal'),...
            get_param(output,'CompiledPortDimensionsMode'));
        if transient && ~isempty(base.faults)
            base.faults={};base.reason='prediction block regenerates this MATLAB Function implementation wire; use the boundary port';
        end
        destinations = struct('path',{},'port',{},'kind',{},'sid',{});
        for n=1:numel(dst)
            parent=get_param(dst(n),'Parent');
            address=struct('path',parent(numel(model)+2:end),'port',get_param(dst(n),'PortNumber'),...
                'kind',get_param(dst(n),'PortType'),'sid',get_param(parent,'SID'));
            destinations(end+1)=address; %#ok<AGROW>
            site=base; site.kind='endpoint'; site.destinations=address;
            site.id=sprintf('E%s_%d__%s_%s%d',sid,k,address.sid,address.kind,address.port);
            if ~strcmp(address.kind,'inport')
                site.faults={}; site.reason=['control port: ' address.kind];
            end
            rows{end+1}=site; %#ok<AGROW>
        end
        if numel(dst)>1
            site=base;site.kind='stem';site.destinations=destinations;
            site.id=sprintf('T%s_%d',sid,k);
            if ~all(strcmp({destinations.kind},'inport'))
                site.faults={}; site.reason='fanout includes a control port';
            end
            rows{end+1}=site; %#ok<AGROW>
        end
        if ~transient && k==1 && numel(ports.Outport)==1
            site=base;site.kind='operator';site.id=['O' char(sid)];site.destinations=destinations;
            site.operandCount=numel(ports.Inport);site.faults=operatorFaults(block,ports,site);
            if ~isempty(site.faults)
                if ismember(get_param(block,'BlockType'),{'RelationalOperator','Logic'})
                    site.originalOperator=get_param(block,'Operator');
                elseif strcmp(get_param(block,'BlockType'),'Sum')
                    pattern=strrep(get_param(block,'Inputs'),'|','');
                    if all(isstrprop(pattern,'digit')),pattern=repmat('+',1,numel(ports.Inport));end
                    site.originalOperator=pattern;
                end
                if strcmp(site.faults{1},'lor')
                    choices=operatorChoices('lor');
                    if site.operandCount==1 && (get_param(ports.Inport(1),'CompiledPortWidth')==1 || ...
                            get_param(ports.Inport(1),'CompiledPortDimensionsMode'))
                        choices={'AND','OR'};
                    end
                    site.replacementOperators=choices(~strcmp(choices,site.originalOperator));
                else
                    site.replacementOperators=operatorChoices(site.faults{1},site);
                end
                site.reason='';rows{end+1}=site; %#ok<AGROW>
            end
        end
    end
end
if isempty(rows), sites=repmat(empty,0,1);return;end
sites=vertcat(rows{:});
[~,order]=sort({sites.id});
sites=sites(order);
assert(numel(unique({sites.id}))==numel(sites),'Duplicate site identifiers in %s.',model);
end

function [kinds,reason]=signalFaults(site,width,complex,variableSize)
kinds={};reason='';
if width<1 || complex
    reason='requires a real signal of known width';return
end
switch site.dataType
    case 'boolean'
        kinds={'bit_flip','invert','stuck_at','zero','package_drop'};
    case {'double','single'}
        kinds={'bias','gain','negate','absolute','invert','stuck_at','zero','package_drop'};
    case {'int8','uint8','int16','uint16','int32','uint32'}
        kinds={'bias','gain','invert','stuck_at','zero','package_drop'};
    case {'int64','uint64'}
        kinds={'invert','stuck_at','zero','package_drop'};
    otherwise
        reason=['unsupported signal type: ' site.dataType];return
end
if variableSize
    kinds=kinds(~ismember(kinds,{'zero','stuck_at','package_drop'}));
    return
end
ts=site.sampleTime;
if isnumeric(ts) && numel(ts)==2 && isfinite(ts(1)) && ts(1)>=0
    if any(strcmp(site.dataType,{'double','single'}))
        kinds{end+1}='noise';
    end
    if ts(1)>0 || strcmp(site.dataType,'double'), kinds{end+1}='delay';kinds{end+1}='hold_last';end
end
end

function kinds=operatorFaults(block,ports,site)
kinds={};
type=get_param(block,'BlockType');
if ~ismember(type,{'Logic','RelationalOperator','Sum','Product'}) || isempty(ports.Inport) || ...
        ~all(strcmp({site.destinations.kind},'inport')),return;end
numericTypes={'double','single','boolean','int8','uint8','int16','uint16','int32','uint32','int64','uint64'};
for input=ports.Inport(:)'
    dt=get_param(input,'CompiledPortDataType');
    if get_param(input,'Line')<0 || get_param(input,'CompiledPortComplexSignal') || ~ismember(dt,numericTypes),return;end
    if ismember(type,{'Sum','Product'}) && (get_param(input,'CompiledPortWidth')~=1 || ~ismember(dt,{'double','single'})),return;end
end
if strcmp(type,'Logic')
    % A one-port non-NOT operator reduces a vector, whereas NOT is elementwise.
    if strcmp(get_param(block,'Operator'),'NOT') && (get_param(ports.Inport(1),'CompiledPortWidth')~=1 || ...
            get_param(ports.Inport(1),'CompiledPortDimensionsMode')),return;end
    kinds={'lor'};return
end
if numel(ports.Inport)<2,return;end
switch type
    case 'Sum', kinds={'asr','s2p'};
    case 'Product', kinds={'p2s'};
    case 'RelationalOperator'
        if numel(ports.Inport)==2,kinds={'ror'};end
end
end

function transient=transientPredictionWiring(parent,model)
transient=false;
if strcmp(parent,model) || ~strcmp(get_param(parent,'SFBlockType'),'MATLAB Function'),return;end
ancestor=get_param(parent,'Parent');
while ~strcmp(ancestor,model)
    if ismember(get_param(ancestor,'MaskType'),{'Stateful Predict','Predict'})
        transient=true;return
    end
    ancestor=get_param(ancestor,'Parent');
end
end
