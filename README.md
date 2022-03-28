# GWB
**GWB**, the GuidosToolbox Workbench is a subset of the desktop software package GTB (https://forest.jrc.ec.europa.eu/en/activities/lpa/gtb/) designed as a cmd-line application for Linux 64bit servers. Precompiled executables of the application can be downloaded from the project homepage (https://forest.jrc.ec.europa.eu/en/activities/lpa/gwb/).

**Reference:** Vogt P. et al. (2022). GuidosToolbox Workbench: spatial analysis of raster maps for ecological applications, Ecography, Volume 2022, Issue 3, doi: 10.1111/ecog.05864

This repository provides information on the GWB source code:

a) directory: GWB
-----------
-   GWB*: GWB bash-launcher scripts

b) directory: tools
-------
-   GWB_*.pro: GWB-module source code

c) directory: tools/external_sources
------
GWB-required C-source code of external programs:
-   mspa: https://github.com/ec-jrc/jeolib-miallib/blob/master/core/c/mspa.c; requiring miallib: https://github.com/ec-jrc/jeolib-miallib
-   recode: recode28Sept2021.c
-   spatcon: spatcon30Sept2021.c

d) Additional documents of the current GWB-version:
-----
-   changelog: https://ies-ows.jrc.ec.europa.eu/gtb/GWB/GWB_changelog.txt
