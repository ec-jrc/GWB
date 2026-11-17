The source code of the GTB/GWB-amended version of MSPA requires 
miallib: https://github.com/ec-jrc/jeolib-miallib
and fsp.c: https://github.com/ec-jrc/GTB/tree/main/external_sources/fsp

fsp is an amended version of mspa.c designed to work with GTB/GWB.
Modifications include parsing mspa input parameters and the option to write temporary files out to disk.

NOTE: Because compiling the MSPA executable is not straightforward we strongly suggest you have a look at the following repo:
https://github.com/vogtpet/MSPAstandalone

This repo contains a setup of all required libraries to build the standalone version of mspa (v2.4, miallib and fsp snapshot as of 10-20-2026) across the five platforms with either x86_64 or aarch64 CPU (Linux, Linux_ARM, MS-Windows, MS-Windows_ARM, macOS-ARM) using a single script deploy.sh. The standalone version of MSPA, which is used in GTB and GWB, includes all required dependencies so it can run on any respective OS without the need to install anything else, which is important to allow execution in corporate computing environments.
