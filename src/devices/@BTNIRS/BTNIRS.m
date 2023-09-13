classdef BTNIRS < handle
    
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
        laserstate;
        laserpwr;
        detgains;
        usefilter;
        probe;
        serialport;
        cnt;
        
        numsrc=8;
        numdet=8;
        SPbuffersize = 1024; %*1024;   % serial port buffer size 1 meg byte
        WordsPerRecord; % 2 srcs X 4 dets X 2 sides (=32) + 2.5 Header + 5.5 Trailing ***"16-bitWORDS"
        
        DAQMeasList =table;
        listML1;  % list to hold the instrument to probe mapping
        listML2;
        tcp_connection;
    end
    
    
    methods
        
        function obj=BTNIRS
            obj.isrunning=false;
            
            obj.WordsPerRecord = 5+64*round(obj.sample_rate/10)+11; % 2 srcs X 4 dets X 2 sides (=32) + 2.5 Header + 5.5 Trailing ***"16-bitWORDS"
            
            
            % close down any existing devices
            in=instrfind;
            for i=1:length(in); fclose(in(i)); end;
            
            %% intialize to the serial port
            
            obj.serialport=[];
            if(ispc)
                for i=10:-1:1
                    try
                        disp(['trying COM' num2str(i)])
                        obj.serialport=serial(['COM' num2str(i)]);
                        
                        set(obj.serialport, 'FlowControl', 'none');
                        set(obj.serialport, 'BaudRate', 115200);
                        set(obj.serialport, 'Parity', 'none');
                        set(obj.serialport, 'DataBits', 8);
                        set(obj.serialport, 'StopBit', 1);
                        set(obj.serialport, 'Timeout',10);
                        set(obj.serialport, 'InputBufferSize',obj.SPbuffersize); %number of bytes in input buffer
                        fopen(obj.serialport);
                        obj.comport=['COM' num2str(i)];
                        
                        fprintf(obj.serialport, sprintf('PID\r'));%\n
                        idn = fscanf(obj.serialport);
                        disp(['Version: ' idn(strfind(idn,'NBT'):end-2)]);
                        break;
                    catch
                        obj.serialport=[];
                    end
                end
            end
            
            
            
            if(isempty(obj.serialport))
                warning('Failed to load device');
                %disp(int);
                error('unable to start');
                return;
            end
            
            
            %             else
            %
            %                 b=dir('/dev/cu.Dual-SPP-SerialPort*');
            %                 obj.serialport=serial(b(1).name);
            %                 set(obj.serialport, 'FlowControl', 'none');
            %                 set(obj.serialport, 'BaudRate', 115200);
            %                 set(obj.serialport, 'Parity', 'none');
            %                 set(obj.serialport, 'DataBits', 8);
            %                 set(obj.serialport, 'StopBit', 1);
            %                 set(obj.serialport, 'Timeout',10);
            %
            %                 fopen(obj.serialport);
            %                 obj.comport=b(1).name;
            %             end
            %
            % set(obj.serialport,'byteorder','littleendian');
            
            
            
            
            % make sure all the default settings are ok
            obj.laserstate=false(obj.numsrc,1);
            obj.laserpwr=ones(obj.numsrc,1);
            obj.detgains=ones(obj.numdet,1);
            %%
            
            for i=1:obj.numsrc
                obj.setLaserState(i,obj.laserstate(i));
                obj.setSrcPower(i,obj.laserpwr(i));
            end
            %%
            for i=1:obj.numdet
                obj.setDetectorGain(i,obj.detgains(i));
            end
            obj.usefilter=false;
            obj.Setfilter(obj.usefilter);
            
            % order of measurements in data stream
            byte1=[6 8 10 12 14 16 18 20 22 24 26 28 30 32 34 36 38 40 42 44 46 48 50 52 54 56 58 60 62 64 66 68]';
            byte2=[7 9 11 13 15 17 19 21 23 25 27 29 31 33 35 37 39 41 43 45 47 49 51 53 55 57 59 61 63 65 67 69]';
            
            %probe type4 
            
            detector=  [1 5 1 5 1 5 1 5 2 6 2 6 2 6 2 6 3 7 3 7 3 7 3 7 4 8 4 8 4 8 4 8]';
            source    =[1 3 1 3 2 4 2 4 1 3 1 3 2 4 2 4 1 3 1 3 2 4 2 4 1 3 1 3 2 4 2 4]';
           
            type=      [1 1 2 2 1 1 2 2 1 1 2 2 1 1 2 2 1 1 2 2 1 1 2 2 1 1 2 2 1 1 2 2]';
            type(type==1)=735; type(type==2)=850;
            obj.DAQMeasList=table(source,detector,type,byte1,byte2);
            %obj=obj.updatebattery;
        end
        
        
        function n= get.info(obj)
            n=['Connected: TechEn BTNIRS ' obj.serialport.name];
        end
        
        
        function set.sample_rate(obj,Fs)
            if(ismember(round(Fs),[10:10:80]))
                obj.sample_rate=Fs;
                fprintf(obj.serialport, sprintf('SSR %d\r',round(Fs/10)));%\n
                obj.WordsPerRecord = 5+64*round(obj.sample_rate/10)+11; % 2 srcs X 4 dets X 2 sides (=32) + 2.5 Header + 5.5 Trailing ***"16-bitWORDS"
                
            else
                warning('Bad sample rate value');
                return;
            end
            
            %TODO
            
        end
        
        %% laser states
        function obj=setLaserState(obj,lIdx,state)
            if(lIdx<1 || lIdx>obj.numsrc)
                return
            end
            %init LEDs
            if(~islogical(state))
                state=(state==1);
            end
            
            fprintf(obj.serialport, sprintf('SSO %d %d\r',lIdx, 1*(state))); %not state is a bool
            obj.laserstate(lIdx)=state;
            pause(0.1);
        end
        
        %% laser powers
        
        function obj = setSrcPower(obj,sIdx,pwr)
            if(sIdx<1 || sIdx>obj.numsrc)
                return
            end
            pwr=max(min(pwr,127),1);  % must be between 1-100
            fprintf(obj.serialport, sprintf('SLE %d %2d\r',sIdx,pwr));%\n
            obj.laserpwr(sIdx)=pwr;
            pause(0.1);
            
        end
        
        %% detector gains
        function obj=setDetectorGain(obj,dIdx,gain)
            if(min(dIdx)<1 || max(dIdx)>obj.numdet)
                return
            end
            gain=127-max(min(gain,127),1);  % must be between 1-127
            fprintf(obj.serialport, sprintf('SDG %d %2d\r',dIdx(1),gain));%\n
            obj.detgains(dIdx)=gain;
            pause(0.1);
        end
        
        %% set filter
        function obj = Setfilter(obj,state)
            if(~islogical(state))
                state=(state==1);
            end
            fprintf(obj.serialport, sprintf('SFT %d\r',1*(state)));%\n
            obj.usefilter=state;
        end
        
        %% START ACQ
        function obj = Start(obj)
            obj.isrunning=true;
            obj.cnt=0;
            flushoutput(obj.serialport);
            flushinput(obj.serialport);
            fprintf(obj.serialport, sprintf('RUN\r'));%\n
            pause(0.25); %v1.3 rcd-added 01/10/2017
            obj.tcp_connection = tcpclient("35.186.191.80", 9000);  % Modify this line
        end
        
        %% STOP ACQ
        function obj= Stop(obj);
            obj.isrunning=false;
            fprintf(obj.serialport, sprintf('STP\r'));  %sprintf('STP \r\n '))\n
            clear obj.tcp_connection;
        end
        
        function obj=updatebattery(obj)
            fprintf(obj.serialport, sprintf('BAT\r'));%\n
            idn = fscanf(obj.serialport);
            bat=dec2bin(double(idn(1)));
            obj.battery=10*bin2dec(bat(1:4));
        end
        
        function n= get.isconnected(obj)
            n=true;
        end
        
        function n = get.samples_avaliable(obj)
            n=floor(get(obj.serialport,'BytesAvailable')/obj.WordsPerRecord);
        end
        
        
        %% set the probe
        function obj = sendMLinfo(obj,probe)
            % for consistency with the other instruments, the measurement
            % channel reordering is handled inside the device class.  This
            % sets the probe to measurement info
            
            obj.probe=probe;
            [obj.listML1,obj.listML2]=ismember(probe.link,obj.DAQMeasList(:,1:3));
            
        end
        
        
        
        % This function is used to get samples from the device.
        function [d,t,aux]=get_samples(obj,nsamples)
            % If the number of arguments is 1, set nsamples to 1.
            if(nargin==1)
                nsamples=1;
            end
          
            % Set nsamples to the minimum of nsamples and the number of samples available.
            nsamples=min(nsamples,obj.samples_avaliable);
                
            % Calculate the number of packets by dividing the sample rate by 10.
            npack = round(obj.sample_rate/10);
            % Initialize the data matrix with NaN values.
            d=nan(nsamples*npack,length(obj.listML1));
                
            % Initialize auxiliary structure with ones.
            aux=struct;
            aux.t=ones(nsamples,1);
            aux.BAT=ones(nsamples,1);
            aux.TEMP=ones(nsamples,1);
            aux.stim=ones(nsamples,4);
            aux.ACC=ones(nsamples,3);
                
            cnt=1;
            for i=1:nsamples
                % startpack = dec2hex(256*fread(obj.serialport, 1, 'uint8')+fread(obj.serialport, 1, 'uint8'));  % should be A0A2
                % SeqNum = fread(obj.serialport, 1, 'uint8');
                % LenPack = 256*fread(obj.serialport, 1, 'uint8')+fread(obj.serialport, 1, 'uint8');
                % nsamp = (LenPack - 16)/64;
                % NIRSdata = fread(obj.serialport, 64*nsamp, 'char');
                % Bat= fread(obj.serialport, 1, 'uint8');
                % Temp = fread(obj.serialport, 1, 'char');
                % Reserve = fread(obj.serialport, 1, 'uint8');
                % Reserve = fread(obj.serialport, 1, 'uint8');
                % AccX = fread(obj.serialport, 1, 'uint8');
                % AccY = fread(obj.serialport, 1, 'uint8');
                % AccZ = fread(obj.serialport, 1, 'uint8');
                % CRC = 256*fread(obj.serialport, 1, 'uint8')+fread(obj.serialport, 1, 'uint8');
                % endpack = dec2hex(256*fread(obj.serialport, 1, 'uint8')+fread(obj.serialport, 1, 'uint8'));  % should be B0B3
                % bkey=[0 10 20 30 40 50 55 60 65 70 75 80 85 90 95 100];
                % bat = dec2bin(Bat);
                % stim = bin2dec(bat(5:end));
                % bat = bkey(bin2dec(bat(1:4))+1);
                % d(i,1:32)=NIRSdata(1:2:end)+256*NIRSdata(2:2:end);
                
                % Read the header from the serial port.
                hdr = fread(obj.serialport, 5, 'char');
                for j=1:npack
                    % Read the data from the serial port.
                    a = fread(obj.serialport, 64, 'char');
                    % Store the data in the appropriate location in the data matrix.
                    d(cnt,obj.listML1) = a(obj.DAQMeasList.byte1(obj.listML2)-5)*256+a(obj.DAQMeasList.byte2(obj.listML2)-5);
                    cnt=cnt+1;
                end
                % Read the end of the header from the serial port.
                hdrend=fread(obj.serialport, 11, 'char');
                
            % Define the battery percentage.
            PERC=flipdim([100 95 90 85 80 75 70 65 60 55 50 40 30 20 10 0],2);
                
            % Convert the battery data to binary.
            bat=dec2bin(hdrend(1));
            bat=['000000000' bat];
            bat=bat(end-7:end);
            % Store the battery data in the auxiliary structure.
            aux.BAT(i)=10*bin2dec(bat(1:4));
            % Store the stimulus data in the auxiliary structure.
            aux.stim(i,1)=1*strcmp(bat(5),'1');
            aux.stim(i,2)=1*strcmp(bat(6),'1');
            aux.stim(i,3)=1*strcmp(bat(7),'1');
            aux.stim(i,4)=1*strcmp(bat(8),'1');
                
            % Store the temperature data in the auxiliary structure.
            aux.TEMP(i)=hdrend(2);
            % Store the acceleration data in the auxiliary structure.
            aux.ACC(i,:)=hdrend(5:7);
                
            end
            % Note any measurement requested in the probe but not possible with this system will stay an NaN
            % Calculate the time for each sample.
            t=(obj.cnt+[1:nsamples*npack]')/obj.sample_rate;
            % Update the counter.
            obj.cnt=obj.cnt+nsamples*npack;
            
            % Store the time data in the auxiliary structure.
            aux.t=t(1:npack:end);
            % Update the battery level.
            obj.battery=mean(aux.BAT);

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
    end
end
