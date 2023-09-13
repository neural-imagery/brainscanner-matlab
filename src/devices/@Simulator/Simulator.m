classdef Simulator < handle
    properties
        sample_rate;
        isrunning;
        comport;
         battery;
    end
    properties( Dependent = true )
        samples_avaliable;
        isconnected;
        info;
       
    end
    
    
    properties(Hidden = true)
       data;
       nmeas;
       cnt;
       timer;
       probe;
       tcp_connection;
    end
    methods
        function obj=Simulator
            obj.comport='Simulator';
            obj.isrunning=false;
            obj.sample_rate=4;
            obj.nmeas=0;
            obj.timer=timer;
            obj.cnt=0;
            obj.battery=100;
            set(obj.timer,'ExecutionMode','fixedRate');
            set(obj.timer,'Period',1/obj.sample_rate);
            set(obj.timer,'TimerFcn',@timerfcn);
             
            % Create a TCP/IP client connection
            obj.createTCPDefault();
        end
        
       function obj=createTCPDefault(obj)
            obj.tcp_connection = tcpclient("35.186.191.80", 9000);  % Modify this line
        end

         function n= get.info(obj)
            n='Connected: Data Simulator';
        end
        
         function n= get.isconnected(obj)
            n=true;
        end
                   
        function n = get.samples_avaliable(obj)
            n=min(get(obj.timer,'TasksExecuted')-obj.cnt,length(obj.data.time));
        end
       function obj=setLaserState(obj,lIdx,state)
            % do nothing
       end
   
       function obj=setDetectorGain(obj,dIdx,gain)
           % do nothing
       end
       function obj = setSrcPower(obj,sIdx,val)
           % do nothing
       end
       
       function obj = sendMLinfo(obj,probe)
           obj.nmeas=height(probe.link);
           obj.probe=probe;
       end
       
       function obj = Start(obj)
           obj.cnt=0;
           obj.isrunning=true;
           obj.data = nirs.testing.simARNoise( obj.probe, [0:30000]/obj.sample_rate);
           j=nirs.modules.Resample;
           j.Fs=obj.sample_rate;
           obj.data=j.run(obj.data);
           obj.timer=timer;
           obj.cnt=0;
           set(obj.timer,'ExecutionMode','fixedRate');
           set(obj.timer,'Period',1/obj.sample_rate);
           set(obj.timer,'TimerFcn',@timerfcn);
           obj.createTCPDefault();
           start(obj.timer);
       end
       
       
       function obj= Stop(obj);
           obj.isrunning=false;
           % Close the connection
           clear obj.tcp_connection;
           stop(obj.timer);
       end
       
       function [d,t]=get_samples(obj,nsamples)
            if(nargin==1)
                nsamples=1;
            end
            nsamples=min(nsamples,obj.samples_avaliable);
            obj.cnt=obj.cnt+nsamples;
            if(nsamples==0)
                t=[];
                d=zeros(0,obj.nmeas);
                return
            end
            t=obj.data.time(1:nsamples);
            d=obj.data.data(1:nsamples,:); 
            obj.data.time(1:nsamples)=[];
            obj.data.data(1:nsamples,:)=[];

            disp("Data:");
            disp(d);

            % Simulate sample aux data
            aux=struct;
            aux.t=ones(nsamples,1);
            aux.BAT=ones(nsamples,1);
            aux.TEMP=ones(nsamples,1);
            aux.stim=ones(nsamples,4);
            aux.ACC=ones(nsamples,3);

            % Convert the collected data to uint8 and write to the server
            % Convert the 2D arrays into cell arrays of cell arrays
            d_cell = num2cell(d, 2);
            % Create structures with the cell arrays
            d_struct = struct('data', d_cell);
            % Combine the structures into a larger structure
            combined_struct = struct('d', {d_struct}, 'aux', {aux});
            % Serialize the structure into a JSON string
            json_str = jsonencode(combined_struct);
            obj.sendOverTCP(json_str);
            disp("Done writing");
       end
       
       function obj=sendOverTCP(obj,json_str)
            try
                disp("Sending...");
                disp(num2str(length(json_str)));
                message = [num2str(length(json_str)) ' ' json_str];
                write(obj.tcp_connection, message);
                disp("Sent!");
            catch ME
                disp('Error occurred while writing data:');
                disp(ME.message);
                disp(ME.stack(1));  % Display where the error occurred
                disp(ME.identifier);
                disp(ME);
                % Check if the error is due to the server resetting the connection
                if contains(ME.identifier, 'writeFailed') || contains(ME.identifier, 'Reset')
                    disp('Server reset the connection. Attempting to reconnect...');

                    % Attempt to reconnect
                    try
                        obj.createTCPDefault();
                        disp('Reconnected successfully.');
                    catch ME
                        disp('Failed to reconnect:');
                        disp(ME.message);
                    end
                end
            end
        end
    end
end

function timerfcn(varargin)

end

