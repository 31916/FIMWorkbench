function [signals,logging]=benchSim(name,T,u,withLog,useModelSettings)
if nargin<5,useModelSettings=false;end
options={'SaveOutput','on','OutputSaveName','yout','SaveFormat','Dataset','ReturnWorkspaceOutputs','on',...
    'SaveTime','on','TimeSaveName','fimwb_tout','SignalLoggingName','fimwb_logs'};
if ~useModelSettings
    assignin('base','u',u);assignin('base','T',T);
    if isempty(find_system(name,'SearchDepth',1,'BlockType','Inport')),ext='off';else,ext='on';end
    options=[options,{'SimulationMode','normal','StopTime',num2str(T),'LoadExternalInput',ext,'ExternalInput','u'}];
end
if ischar(withLog)||withLog,mode='on';else,mode='off';end
out=sim(name,options{:},'SignalLogging',mode);
finished=double(out.fimwb_tout(end));assert(abs(finished-T)<=1e-8*max(1,T),'Simulation stopped at %g instead of %g.',finished,T);
ds=out.yout;signals=cell(1,ds.numElements);
for k=1:ds.numElements,signals{k}=unpack(ds{k}.Values);end
logging=struct();
if ischar(withLog)
    logging=unpack(out.fimwb_logs.getElement(withLog).Values);
elseif withLog
    logs=out.fimwb_logs;
    logging.input=unpack(logs.getElement('fimwb_original').Values);
    logging.output=unpack(logs.getElement('fimwb_faulty').Values);
end
end

function s=unpack(ts)
t=double(ts.Time(:));v=ts.Data;
if ~ts.IsTimeFirst && ndims(v)>1,v=permute(v,[ndims(v) 1:ndims(v)-1]);end
values=reshape(double(v),numel(t),[]);
assert(~isempty(t)&&all(isfinite(t))&&all(isfinite(values),'all'),'Invalid or empty trace.');
s=struct('time',t,'values',values,'type',class(ts.Data));
end

