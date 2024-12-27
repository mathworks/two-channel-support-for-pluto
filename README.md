# Two channel Support for ADALM-PLUTO™
## Description
This repo provides the necessary files to enable dual-channel operation of the ADALM-PLUTO™ radio in MATLAB® and Simulink®. It includes an example demonstrating frequency and phase synchronization between the two channels.

## Requirements
- [MATLAB](https://www.mathworks.com/products/matlab.html)
- [Communications Toolbox™](https://www.mathworks.com/products/communications.html)
- [Communications Toolbox Support Package for ADALM-PLUTO Radio ](https://www.mathworks.com/hardware-support/adalm-pluto-radio.html)
- Rev C or Rev D ADALM-PLUTO
- A 1-2 power splitter
  
## Contents
- RadioConfigurationManager.m
- ReceiveTwoChannelPhaseSynchronizedData.mlx
- configureTwoChannelPlutoRadio.m
- rx.p
- tx.p
- Security.md
- license.txt

## Install Instructions
- Install [Communications Toolbox Support Package for ADALM-PLUTO Radio ](https://www.mathworks.com/hardware-support/adalm-pluto-radio.html)
- Run below command in Matlab command window.
- spkgroot = matlabshared.supportpkg.getSupportPackageRoot();
- Dowload RadioConfigurationManager.m file and place in   spkgroot/toolbox/shared/sdr/sdrplug/plutoradio_hspdef/plutoradio_hspdef/+plutoradio/+internal
- Download configureTwoChannelPlutoRadio.m and ReceiveTwoChannelPhaseSynchronizedData.mlx files and place in spkgroot/toolbox/shared/sdr/sdrplug/plutoradio_hspdef/plutoradio_hspdef
- Download tx.p and rx.p files and place in spkgroot/toolbox/shared/sdr/sdrplug/sdrplugins/plutoradio/+comm/+plutoradio  
  
## Agenda
- Connect the ADALM-PLUTO Radio: Attach the radio to your host computer and run the Hardware Setup App from the Communications Toolbox Support Package for ADALM-PLUTO Radio.
- Configure the Radio: Execute the configureTwoChannelPlutoRadio.m script to enable two-channel functionality on your ADALM-PLUTO.
- SMA Connections: Add SMA connectors to Tx2 and Rx2. Follow [this](https://wiki.analog.com/university/tools/pluto/hacking/hardware#removing_the_case) page for connections 
- Antenna Connection: Use a power splitter to connect the Tx1 antenna port of the radio to both the Rx1 and Rx2 ports.
- Run the Example: Execute the ReceiveTwoChannelPhaseSynchronizedData.mlx example to observe the dual channel operation.

## Results
- Frequency Spectrum: The frequency spectrum of the data received from both channels will overlap, with peaks aligning at the same frequency.
- Phase Synchronization: The phase offset between channels will remain constant until the radio is released.

