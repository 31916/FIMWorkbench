function [file,T,u,scope] = benchSource(id,root,work,inputsOnly)
if nargin<4,inputsOnly=false;end
base=fullfile(root,'verification','sources');
arch=fullfile(base,'ARCH');
scope='native Simulink';
switch id
    case 'AT'
        file=fullfile(arch,'transmission','Autotrans_shift.mdl');T=33;
        u=steps(T,[0 5 10 15 20 25 30],[20 45 30 60 35 45 25;0 0 20 0 30 0 0]');
        data=fullfile(base,'at_data');
        if isfolder(data),addpath(data,'-end');end
        if isempty(which('sldemo_autotrans_data.mat'))
            original=fullfile(fileparts(root),'AT_ARCH2026_Instance2_FIM_UR_20261115','original','sldemo_autotrans_data.mat');
            if isfile(original),copyfile(original,fullfile(work,'sldemo_autotrans_data.mat'));end
        end
    case 'AFC'
        file=fullfile(arch,'powertrain','AbstractFuelControl_M1.slx');T=51;
        init=fullfile(arch,'powertrain','init_powertrain.m');
        evalin('base',sprintf('run(''%s'');',strrep(init,'''','''''')));
        u=steps(T,0:5:45,[(20+5*mod(0:9,3));repmat(1000,1,10)]');
    case 'NN'
        file=fullfile(arch,'neural','narmamaglev_v1.slx');T=40;
        assignin('base','u_ts',0.001);
        u=steps(T,[0 14 27],[2;2.05;1.95]);
    case 'CC'
        file=fullfile(arch,'chasing-cars','cars.mdl');T=100;
        u=steps(T,0:5:95,[0.35+0.08*mod(0:19,3);0.10+0.03*mod(0:19,4)]');
    case 'SC'
        file=fullfile(arch,'steam-condenser','steamcondense_RNN_22.slx');T=35;
        u=steps(T,(0:19)*35/20,(4+.002*mod(0:19,3))');
    case 'PM'
        file=fullfile(base,'PM','Model1_Scenario1_Faulty.slx');T=10;
        u=steps(T,0:2:8,[68;72;65;75;70]);
    case 'F16'
        T=15;
        % The benchmark is an ODE. Execute it through a model source on every
        % simulation and independently obtain the reference returned by that ODE.
        file='';u=[];
        if ~inputsOnly
            u=fimwb_f16_measurement();
            name='bench_f16_observation';file=fullfile(work,[name '.slx']);
            new_system(name);c=onCleanup(@() close_system(name,0)); %#ok<NASGU>
            add_block('simulink/Sources/From Workspace',[name '/Measurement'],...
                'VariableName','fimwb_f16_measurement()','SampleTime','0.01','Interpolate','on','OutputAfterFinalValue','Holding final value');
            add_block('built-in/Outport',[name '/RecordedValue']);
            add_line(name,'Measurement/1','RecordedValue/1');
            set_param(name,'SolverType','Fixed-step','Solver','FixedStepDiscrete','FixedStep','0.01');
            save_system(name,file);clear c;
        end
        scope='official ODE executed by Simulink; observation signal only';
    otherwise
        assert(startsWith(id,'SB'));
        index=str2double(id(3:end));names={'phi1_m2_vr001_k5_2','phi2_m1_vr01_k2_2',...
            'phi3_m2_vr001_k3_2','phi4_m2_vr001_k5_3','phi5_m1_vr01_k5_2'};
        name=names{index};source=fullfile(base,'SB',[name '.slx']);
        useSbWeights(fullfile(base,'SB'),work,[name '.mat']);
        file=source;
        if ~inputsOnly
            file=fullfile(work,[name '.slx']);copyfile(source,file);
            load_system(file);c=onCleanup(@() close_system(name,0));
            set_param([name '/StatefulPredict'],'NetworkFilePath',[name '.mat']);
            save_system(name);clear c;
        end
        T=24;dims=[2 1 2 2 1];
        vals=[.2 .45 .7 .35;.65 .25 .55 .4]';
        u=steps(T,[0 6 12 18],vals(:,1:dims(index)));
end
if ~inputsOnly,assignin('base','T',T);assignin('base','u',u);end
end

function u=steps(horizon,breaks,levels)
t=(0:0.01:horizon)';u=[t,interp1(breaks(:),levels,t,'previous','extrap')];
end
