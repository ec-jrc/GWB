# GWB
**GWB**, the GuidosToolbox Workbench is a subset of the desktop software package GTB (https://forest.jrc.ec.europa.eu/en/activities/lpa/gtb/) designed as a cmd-line application for Linux 64bit servers. Full installation packages, including precompiled executables of the application, can be downloaded from the project homepage (https://forest.jrc.ec.europa.eu/en/activities/lpa/gwb/). GWB is written in the IDL language, and you must be the legal owner of an IDL licence to compile the IDL source code. Further information on the IDL software can be found at: https://www.harrisgeospatial.com. Alternative to using IDL, feel free to recode the IDL source code to the programming language of your choice.

**Reference:** Vogt P. et al. (2022). GuidosToolbox Workbench: spatial analysis of raster maps for ecological applications, Ecography, Volume 2022, Issue 3, doi: 10.1111/ecog.05864

This repository provides information on the GWB source code:

a) directory: GWB
-----------
-   GWB*: GWB bash-launcher scripts

b) directory: input
-------
-   *-parameter.txt: GWB module-specific parameter settings
-   *.tif: sample images
-   backup: directory of backup files 

c) directory: output
-------
-   location for intermediate processing and resulting output files

d) directory: tools
-------
-   GWB_*.pro: GWB-module IDL source code

e) directory: tools/external_sources
------
GWB-required C-source code of external programs:
-   mspa: https://github.com/ec-jrc/jeolib-miallib/blob/master/core/c/mspa.c; requiring miallib: https://github.com/ec-jrc/jeolib-miallib
-   recode: recode28Sept2021.c
-   spatcon: spatcon30Sept2021.c
The compiled versions of the three programs should be placed in the directory 'tools'

f) Additional documents of the current GWB-version:
-----
-   current version number and changelog: https://ies-ows.jrc.ec.europa.eu/gtb/GWB/GWB_changelog.txt
