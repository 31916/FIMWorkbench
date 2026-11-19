function stages = build(modelFile, configuration, outputFile)
%BUILD Generate and compile a new Simulink model with editable fault slots.
% fimwb.build(source,output) installs one disabled fault at every eligible site.
% fimwb.build(source,configuration,output) accepts a struct or JSON file.
if nargin==2,outputFile=configuration;end
[~,source,sourceCleanup]=openSource(modelFile); %#ok<ASGLU>
[folder,name,ext]=fileparts(char(outputFile));
if isempty(folder),folder=pwd;end
[ok,attr]=fileattrib(folder);
assert(ok && attr.directory,'Output directory must exist.');
folder=attr.Name;
[~,original,originalExt]=fileparts(source);
assert(isvarname(name)&&~strcmp(name,original)&&~bdIsLoaded(name),...
    'Choose a distinct, unused MATLAB model name.');
assert(ismember(lower(ext),{'.mdl','.slx'}),'Output extension must be .mdl or .slx.');
outputFile=fullfile(folder,[name ext]);
assert(~isfile(outputFile),'Output already exists. Use fimwb.setFault to edit it, or choose a new file.');
if nargin==2
    sites=fimwb.scan(source);
    raw=fimwb.defaultFaults(sites);
    assert(~isempty(raw),'No compatible fault injection sites were found in this model.');
else
    if ischar(configuration)||isStringScalar(configuration)
        configuration=jsondecode(fileread(configuration));
    end
    assert(isstruct(configuration)&&isscalar(configuration)&&isfield(configuration,'faults')&&...
        all(ismember(fieldnames(configuration),{'faults','sourceSha256'})),'Expected a configuration object containing faults.');
    if isfield(configuration,'sourceSha256')
        assert(strcmpi(configuration.sourceSha256,fimwb.fileHash(source)),'Source SHA-256 differs from configuration.');
    end
    sites=fimwb.scan(source);
    raw=configuration.faults;
end
if isstruct(raw),raw=num2cell(raw);end
assert(isempty(raw)||iscell(raw),'faults must be an array of fault objects.');
settings=cell(size(raw));selected=cell(size(raw));priority=zeros(numel(raw),1);
for k=1:numel(raw)
    assert(isfield(raw{k},'site'),'Missing site in fault %d.',k);
    match=find(strcmp({sites.id},raw{k}.site));
    assert(isscalar(match),'Unknown site in fault %d.',k);
    selected{k}=sites(match);
    settings{k}=checkFault(raw{k},selected{k});
    priority(k)=find(strcmp({'operator','stem','endpoint'},sites(match).kind));
end
ops=find(priority==1);
operatorIDs=cellfun(@(s)s.id,selected(ops),'UniformOutput',false);
assert(numel(unique(operatorIDs))==numel(ops),'Choose one replacement per operator.');
% Stage beside the target so a failed compile cannot publish a partial model.
work=tempname(folder);mkdir(work);
release=onCleanup(@() discard(name,work)); %#ok<NASGU>
workingSource=fullfile(work,[name originalExt]);
[ok,msg]=copyfile(source,workingSource);assert(ok,'%s',msg);
assert(java.io.File(workingSource).setWritable(true),'Cannot make the working copy writable: %s',workingSource);
load_system(workingSource);
stages=cell(numel(raw),1);
[~,order]=sortrows([priority,(1:numel(raw))'],[1,2]);
for k=order'
    stages{k}=insertStage(name,selected{k},settings{k},k);
end
% Tap operands after the signal stages. A modified operand therefore reaches
% both the original operation and its alternative.
for k=ops(:)'
    block=[name '/' selected{k}.source];
    originalPorts=get_param(block,'PortHandles');target=get_param(stages{k},'PortHandles');
    parent=get_param(block,'Parent');
    for j=1:numel(originalPorts.Inport)
        ln=get_param(originalPorts.Inport(j),'Line');
        add_line(parent,get_param(ln,'SrcPortHandle'),target.Inport(j+1),'autorouting','on');
    end
end
% Resolve companion MAT files and classes relative to the final working copy.
metadata=get_param(name,'Metadata');
if isempty(metadata),metadata=struct();end
origin=java.io.File(source).toPath();
target=java.io.File(folder).toPath();
if origin.getRoot().equals(target.getRoot())
    ref=char(target.relativize(origin).toString());
else
    ref=source;
end
metadata.FIMWorkbenchSourceModel=strrep(ref,filesep,'/');
set_param(name,'Metadata',metadata);
staged=fullfile(work,[name ext]);
save_system(name,staged);
close_system(name,0);
load_system(staged);
set_param(name,'SimulationCommand','update');
for k=1:numel(stages)
    h=getSimulinkBlockHandle(stages{k});
    assert(h~=-1 && strcmp(get_param(h,'Tag'),sprintf('fimwb.fault.%d',k)),...
        'Simulink regenerated the injection site %s during compilation.',settings{k}.site);
    m=get_param(h,'UserData');
    assert(isequaln(m.fault,settings{k}),'Fault configuration did not survive reload: %s',settings{k}.site);
end
close_system(name,0);
% Publish without replacing another process's completed file.
try
    java.nio.file.Files.createLink(java.io.File(outputFile).toPath(),java.io.File(staged).toPath());
catch err
    % Some filesystems do not support hard links. Java move without
    % REPLACE_EXISTING refuses an existing destination.
    if isfile(outputFile),rethrow(err);end
    java.nio.file.Files.move(java.io.File(staged).toPath(),java.io.File(outputFile).toPath(),...
        javaArray('java.nio.file.CopyOption',0));
end
end

function stage=insertStage(model,site,f,k)
block=[model '/' site.source];
parent=get_param(block,'Parent');unlockCopy(parent,model);
targets=zeros(numel(site.destinations),1);
for d=1:numel(targets)
    ref=site.destinations(d);
    ph=get_param([model '/' ref.path],'PortHandles');targets(d)=ph.Inport(ref.port);
end
src=get_param(get_param(targets(1),'Line'),'SrcPortHandle');
for t=targets'
    assert(get_param(get_param(t,'Line'),'SrcPortHandle')==src,'Destination no longer shares the expected signal.');
end
originalName=get_param(get_param(src,'Line'),'Name');
stage=[parent '/' sprintf('FIMWB_%03d',k)];
assert(getSimulinkBlockHandle(stage)==-1,'Generated block name is already in use: %s',stage);
xy=get_param(block,'Position');pos=[xy(3)+25 xy(2)+35];
add_block('built-in/Subsystem',stage,'Position',[pos pos+[80 36]],...
    'Tag',sprintf('fimwb.fault.%d',k));
add_block('built-in/Inport',[stage '/Original'],'Port','1','Position',[20 48 48 62]);
operandCount=0;
if strcmp(site.kind,'operator')
    ph=get_param(block,'PortHandles');operandCount=numel(ph.Inport);
    for n=1:operandCount
        y=76+30*n;
        add_block('built-in/Inport',sprintf('%s/Operand%d',stage,n),'Port',num2str(n+1),...
            'Position',[20 y 48 y+14]);
    end
end
add_block('built-in/Outport',[stage '/Result'],'Position',[520 52 550 66]);
meta=struct('fault',f,'site',site,'slot',k,'operandCount',operandCount);
drawStage(stage,meta);
ph=get_param(stage,'PortHandles');
for t=targets',delete_line(parent,src,t);end
add_line(parent,src,ph.Inport(1),'autorouting','on');
newLine=get_param(src,'Line');
if ~isempty(originalName) && ~strcmp(get_param(newLine,'Name'),originalName) && ...
        ~strcmp(get_param(get_param(src,'Parent'),'BlockType'),'BusSelector')
    set_param(newLine,'Name',originalName);
end
for t=targets',add_line(parent,ph.Outport(1),t,'autorouting','on');end
end

function unlockCopy(parent,model)
ancestors={};
while ~strcmp(parent,model)
    ancestors=[{parent},ancestors]; %#ok<AGROW>
    parent=get_param(parent,'Parent');
end
for k=1:numel(ancestors)
    if strcmp(get_param(ancestors{k},'LinkStatus'),'resolved')
        set_param(ancestors{k},'LinkStatus','none');
    end
end
end

function discard(model,folder)
if bdIsLoaded(model),close_system(model,0);end
if isfolder(folder),rmdir(folder,'s');end
end
