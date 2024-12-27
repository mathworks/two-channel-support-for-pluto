function status = configureTwoChannelPlutoRadio(varargin)
%configureTwoChannelPlutoRadio Configure ADALM-PLUTO radio to 2r2t Mode
%   configureTwoChannelPlutoRadio configures the ADALM-PLUTO radio with
%   RadioID 'usb:0' to operate in the specified AD9361 CHIPSET nad 2r2t
%   mode. The radio must be connected to computer running this command.

%   Copyright 2024 The MathWorks, Inc.

dev = sdrdev('Pluto');
ip = inputParser;

addOptional(ip,'radioID','usb:0',...
  @(radioID)validateRadioID(radioID));
parse(ip, varargin{:})

config = plutoradio.internal.RadioConfigurationManager(ip.Results.radioID);

status = set2r2tMode(config);

end

function success = validateRadioID(radioID)
  rx = sdrrx('Pluto');
  set(rx,'RadioID',radioID);
  success = true;
end