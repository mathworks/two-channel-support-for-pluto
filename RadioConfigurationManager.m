classdef RadioConfigurationManager < handle
  %RadioConfigurationManager ADALM-PLUTO radio configuration manager
  
  %Copyright 2017-2024 The MathWorks, Inc.
  properties
    RadioID
  end

  properties (SetAccess = private)
    SerialNum
  end
  
  properties (Access=private)
    SerialConnection
    OriginalLibraryPath = 'DEFAULT'
    MessageLogger
    AboutToReset = false
  end
  
  methods
    function obj = RadioConfigurationManager(varargin)
      if nargin > 0
        obj.RadioID = varargin{1};
      end
      
      obj.MessageLogger = ...
        plutoradio.internal.Logger('Radio configuration manager');
    end
    
    function success = set(obj, chipset)
      openLogFile(obj.MessageLogger);
      closeLogFileCleanup = onCleanup(@()closeLogFile(obj.MessageLogger));
      
      handleToWaitBar = waitbar(0, ...
        message('plutoradio:hwsetup:ConfigureHardware_CheckingUSBConnection').getString, ...
        'Name', 'ADALM-PLUTO Radio Configuration');
      handleToText = uicontrol(handleToWaitBar,'style','text','position',[240 60 120 15]);
      
      if isunix
        if ~ismac
          % Get handle of the text
          h = get(findobj(handleToWaitBar, 'Type', 'axes'),'title');
          h.FontSize = 8;
          handleToText.FontSize = 8;
        end
      end
      delText = onCleanup(@()handleToText.delete);
      delWaitbar = onCleanup(@()handleToWaitBar.delete);
      closeConnection = onCleanup(@()disconnectRadio(obj));
      
      % Check USB connection
      success = checkUSBConnection(obj);
      pause(2)
      
      if success == true
        waitbar(0.25, handleToWaitBar,...
          message('plutoradio:hwsetup:ConfigureHardware_ConnectingToHW').getString);
        connected = connectToRadio(obj);
        
        if connected
          waitbar(0.50, handleToWaitBar,...
            message('plutoradio:hwsetup:ConfigureHardware_ConnectedToHW').getString);
          pause(2)
          
          waitbar(0.75, handleToWaitBar,...
            message('plutoradio:hwsetup:ConfigureHardware_ConfiguringRadio').getString);
          success = configureHW(obj, chipset);
        else
          error(message('plutoradio:hwsetup:CannotConnect'));
        end
        
        disconnectRadio(obj)
      else
        error(message('plutoradio:hwsetup:USBConnectionFailed', obj.RadioID));
      end
      
      waitbar(1.0, handleToWaitBar,...
        message('plutoradio:hwsetup:ConfigureHardware_Done').getString);
    end

    function status = set2r2tMode(obj)
        success = checkUSBConnection(obj);
        pause(2)

        if success == true
            connected = connectToRadio(obj);
        end
        if connected
            out = serialWriteRead(obj, "fw_setenv attr_name compatible");
            if ~contains(out, "fw_setenv attr_name compatible")
                status = false;
                return
            end
            out = serialWriteRead(obj, "fw_setenv attr_val ""ad9361""");
             if ~contains(out, "fw_setenv attr_val ""ad9361""")
                status = false;
                return
            end
            out = serialWriteRead(obj, "fw_setenv compatible ""ad9361""");
            if ~contains(out, "fw_setenv compatible ""ad9361""")
                status = false;
                return
            end
            out = serialWriteRead(obj, "fw_setenv mode ""2r2t""");
            if ~contains(out, "fw_setenv mode ""2r2t""")
                status = false;
                return
            end
            status = true;
            obj.AboutToReset = true;
            serialWrite(obj, "pluto_reboot reset");
            pause(2)
            obj.AboutToReset = false;
           
            disconnectRadio(obj);
        else
            status = false;
        end
    end
    
    function chipset = get(obj)
      openLogFile(obj.MessageLogger);
      closeLogFileCleanup = onCleanup(@()closeLogFile(obj.MessageLogger));
      
      success = checkUSBConnection(obj);
      pause(2)
      
      if success == true
        connected = connectToRadio(obj);
        
        if connected
          [success,chipset] = getHWConfiguration(obj);
        else
          success = false;
        end
        
        disconnectRadio(obj)
      else
        success = false;
      end
      
      if ~success
        chipset = 'Unknown';
      end
    end
  end
  
  methods(Access=private)
    function connected = connectToRadio(obj)
      connected = false;
      
      % Get list of serial devices
      serialDevices = serialportlist;
      logMessage(obj.MessageLogger, ...
        sprintf('Serial devices: %s\n', sprintf('%s, ',serialDevices)));
      
      if isempty(serialDevices)
        error(message('plutoradio:hwsetup:SerialConnectionFailed'));
      end
      
      % Search for Pluto
      for p=1:length(serialDevices)
          
        if ismac
          % In MAC OS, tty devices cause a hang. Skip them. We will use cu
          % devices.
          if contains(serialDevices(p), "tty")
            continue
          end
        end
        
        foundPlutoLogin = false;
        plutoLoggedIn = false;
        foundPasswordPrompt = false;
        logMessage(obj.MessageLogger, ...
          sprintf('Trying serial connection %s\n', serialDevices(p)))
        try
          obj.SerialConnection = ...
            serialport(serialDevices(p), 115200);
          % Use the error handling callback to filter out connection lost
          % error, if it is as a resutl of the reset.
          obj.SerialConnection.ErrorOccurredFcn = @(eh)handleSerialError(obj,eh);
          logMessage(obj.MessageLogger, ...
            sprintf('serial function returned for %s\n', serialDevices(p)))
          connectionSuccessful = true;
        catch
          connectionSuccessful = false;
          logMessage(obj.MessageLogger, ...
            sprintf('Cannot create serial port for %s\n', serialDevices(p)))
        end
        
        if connectionSuccessful
          pause(1)
          % Send login name first
          out = serialWriteRead(obj, "root");
          if ~isempty(regexp(out, "# $", 'once'))
            plutoLoggedIn = true;
            logMessage(obj.MessageLogger, ...
              sprintf('Pluto logged in\n'))
          elseif ~isempty(regexp(out, "Password: ", 'once'))
            foundPasswordPrompt = true;
            logMessage(obj.MessageLogger, ...
              sprintf('Found password prompt\n'))
          elseif ~isempty(regexp(out, "pluto login: ", 'once'))
            foundPlutoLogin = true;
            logMessage(obj.MessageLogger, ...
              sprintf('Found Pluto login\n'))
          end
        end
        
        if foundPlutoLogin || foundPasswordPrompt
          if foundPlutoLogin
            serialWriteRead(obj, "root");
          end
          out = serialWriteRead(obj, "analog");
          if contains(out, "#")
            plutoLoggedIn = true;
            logMessage(obj.MessageLogger, ...
              sprintf('Pluto logged in\n'))
          end
        end
        
        plutoSerialNumMatches = false;
        if plutoLoggedIn
          out = serialWriteRead(obj, "iio_attr -C hw_serial");
          token = 'hw_serial: ';
          if contains(out, token)
            parts = strip(split(out, token)); 
            parts = strip(split(parts{2}, "#"));
            serialNum = parts{1};
            if strcmp(serialNum, obj.SerialNum)
              logMessage(obj.MessageLogger, ...
                sprintf('Pluto serial number matches\n'))
              plutoSerialNumMatches = true;
            end
          end
        end
        
        if plutoSerialNumMatches
          break
        end
        logMessage(obj.MessageLogger, ...
          sprintf('Not the radio we are looking for. Close connection.\n'))
        delete(obj.SerialConnection);
      end
      
      if plutoSerialNumMatches
        logMessage(obj.MessageLogger, ...
          sprintf('Connected to the radio.\n'))
        connected = true;
      end
    end
    
    function reply = serialWriteRead(obj, command)
      logMessage(obj.MessageLogger, ...
        sprintf('writeline(obj.SerialConnection,''%s'')\n', command))
      writeline(obj.SerialConnection,command);

      pause(1)

      reply = "";
      for count = 1:2
        while (obj.SerialConnection.NumBytesAvailable > 0)
          out = read(obj.SerialConnection, obj.SerialConnection.NumBytesAvailable, 'string');
          logMessage(obj.MessageLogger, ...
            sprintf('read returned: %s\n', strrep(out,'\','\\')))
          reply = append(reply, out);
          break
        end
        pause(1)
      end
    end
    
    function serialWrite(obj, command)
      logMessage(obj.MessageLogger, ...
        sprintf('writeline(obj.SerialConnection,''%s'')\n', command))
      writeline(obj.SerialConnection,command);
    end
    
    function disconnectRadio(obj)
      if isa(obj.SerialConnection, 'internal.Serialport')
        logMessage(obj.MessageLogger, ...
          sprintf('Close serial connection.\n'))
        delete(obj.SerialConnection);
      end
    end
    
    function success = configureHW(obj, chipset)
      try
        [success, currentConfig] = getHWConfiguration(obj);
        if success && ~strcmp(currentConfig, chipset)
          success = setHWConfiguration(obj, chipset);
        end
      catch
        success = false;
      end
    end


    
    function [success,currentConfig] = getHWConfiguration(obj)
      success = true;
      currentConfig = 'AD9363';
      
      try
        out = serialWriteRead(obj, "fw_printenv attr_name");
        compatibleMode = contains(out, 'attr_name=compatible') && ...
          ~contains(out, 'Error: "attr_name" not defined');
        
        if compatibleMode
          out = serialWriteRead(obj, "fw_printenv attr_val");
          if contains(out, 'attr_val=')
            compatibleValue = regexp(out, "ad93\d{2}", "match");
          end
        end
        
        if compatibleMode && strcmp(compatibleValue, 'ad9364')
          currentConfig = 'AD9364';
        end
      catch
        success = false;
      end
    end

    function success = setHWConfiguration(obj, chipset)
      switch chipset
        case 'AD9364'
          out = serialWriteRead(obj, "fw_setenv attr_name compatible");
          if ~contains(out, "fw_setenv attr_name compatible")
            success = false;
            return
          end
          
          out = serialWriteRead(obj, "fw_setenv attr_val ""ad9364""");
          if ~contains(out, "fw_setenv attr_val ""ad9364""")
            success = false;
            return
          end

          obj.AboutToReset = true;
          serialWrite(obj, "pluto_reboot reset");
          pause(2)
          obj.AboutToReset = false;
          
          disconnectRadio(obj);
          pause(15)
          success = connectToRadio(obj);
        case 'AD9363'
          out = serialWriteRead(obj, "fw_setenv attr_name """"");
          if ~contains(out, "fw_setenv attr_name """"")
            success = false;
            return
          end
          
          out = serialWriteRead(obj, "fw_setenv attr_val """"");
          if ~contains(out, "fw_setenv attr_val """"")
            success = false;
            return
          end

          obj.AboutToReset = true;
          serialWrite(obj, "pluto_reboot reset");
          pause(2)
          obj.AboutToReset = false;
          
          disconnectRadio(obj);
          pause(13)
          success = connectToRadio(obj);
      end
    end
    
    function success = checkUSBConnection(obj)
      logMessage(obj.MessageLogger, sprintf('Connect to RadioID %s\n', obj.RadioID));
      rx = sdrrx('Pluto', 'RadioID', obj.RadioID);
      logMessage(obj.MessageLogger, sprintf('Get info from RadioID %s\n', obj.RadioID));
      radioInfo = info(rx);
      if strcmp(radioInfo.Status, 'No connection with device')
        logMessage(obj.MessageLogger, sprintf('Cannot connect to RadioID %s\n', obj.RadioID));
        success = false;
      else
        logMessage(obj.MessageLogger, ...
          sprintf('Connection successful to RadioID %s with serial number %s\n', ...
          obj.RadioID, radioInfo.SerialNum));
        obj.SerialNum = radioInfo.SerialNum;
        success = true;
      end
    end
    
  end
  
  methods(Hidden)
    function handleSerialError(obj, errorInfo)
      % Ignore connection lost error, if it is as a result of the reset
      % command.
      if obj.AboutToReset == false
        errordlg(errorInfo.Message, 'ADALM-PLUTO Radio Configuration')
        throw(MException(errorInfo.ID, errorInfo.Message))
      end
    end
  end
end
