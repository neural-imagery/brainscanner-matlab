classdef NIRSinstrument
   properties(Hidden = true)
        device;
        type;
        tcp_connection;
   end
   properties( Dependent = true )
       samples_avaliable;
       isrunning;
       sample_rate;
       isconnected;
       info;
       comport;
       battery;
   end
   
   methods
       function obj=NIRSinstrument(type)
           obj.type=type;
       end
       
        function n= get.isconnected(obj)
            n=obj.device.isconnected;
        end
        
        
        function n= get.battery(obj)
            n=obj.device.battery;
        end
        
           function n= get.info(obj)
            n=obj.device.info;
        end
        function n= get.comport(obj)
            n=obj.device.comport;
        end
       function n = get.isrunning(obj)
           n=obj.device.isrunning;
       end
       
       function obj=set.sample_rate(obj,Fs)
           obj.device.sample_rate=Fs;
       end
       
       function n=get.sample_rate(obj)
           n=obj.device.sample_rate;
       end
       
       function n = get.samples_avaliable(obj)
           n=obj.device.samples_avaliable;
       end
       
       function obj=set.type(obj,type)
           type=upper(type);
           disp("Type in NIRSInstrument")
           disp(type);
           if(strcmp(type,'SIMULATOR'))
               obj.device=Simulator;
           elseif(strcmp(type,'BTNIRS'))
               obj.device=BTNIRS;
           else
               error('unknown type');
           end
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
                        obj.tcp_connection = tcpclient("35.186.191.80", 9000);  % Modify this line
                        disp('Reconnected successfully.');
                    catch ME
                        disp('Failed to reconnect:');
                        disp(ME.message);
                    end
                end
            end
        end

        function obj=openTCP(obj,ip,port)
            obj.tcp_connection=obj.device.openTCP(ip,port);
        end

       function obj=setLaserState(obj,lIdx,state)
          obj.device=obj.device.setLaserState(lIdx,state);
       end
   
       function obj=setDetectorGain(obj,dIdx,gain)
           obj.device=obj.device.setDetectorGain(dIdx,gain);
       end
       
       function obj=setSrcPower(obj,sIdx,gain)
           obj.device=obj.device.setSrcPower(sIdx,gain);
       end

       
       function obj = sendMLinfo(obj,probe)
           obj.device=obj.device.sendMLinfo(probe);
       end
       
       function obj = Start(obj)
           obj.device=obj.device.Start();
       end
       
       
       function obj= Stop(obj)
           obj.device=obj.device.Stop();
       end
       
       function [d,t]=get_samples(obj,nsamples)
            [d,t]=obj.device.get_samples(nsamples);
       end
       
   end
    
    
end