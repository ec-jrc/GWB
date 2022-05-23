# GWB
**GWB**, the GuidosToolbox Workbench is a subset of the desktop software package GTB (https://forest.jrc.ec.europa.eu/en/activities/lpa/gtb/) designed as a cmd-line application for Linux 64bit servers. Full installation packages, including precompiled executables of the application, can be downloaded from the project homepage (https://forest.jrc.ec.europa.eu/en/activities/lpa/gwb/). GWB is written in the IDL language, and you must be the legal owner of an IDL licence to compile the IDL source code. Further information on the IDL software can be found at: https://www.harrisgeospatial.com. Alternative to using IDL, feel free to recode the IDL source code to the programming language of your choice.

**Reference:** Vogt P. et al. (2022). GuidosToolbox Workbench: spatial analysis of raster maps for ecological applications, Ecography, Volume 2022, Issue 3, doi: 10.1111/ecog.05864

This repository provides information on the GWB source code:

a) base directory: GWB
-----------
-   GWB*: GWB bash-launcher scripts

b) subdirectory: input
-------
-   *-parameter.txt: GWB module-specific parameter settings
-   *.tif: sample images
-   backup: directory of backup files 

c) subdirectory: output
-------
-   location for intermediate processing and resulting output files

d) subdirectory: tools
-------
-   GWB_*.pro: GWB-module IDL source code

e) subdirectory: tools/external_sources
------
GWB-required C-source and python code of external programs:
-   fsp: directory with source files and instructions needed to compile GTB/GWB-amended version of mspa requiring miallib: https://github.com/ec-jrc/jeolib-miallib
-   recode: recode28Sept2021.c
-   spatcon: spatcon30Sept2021.c
-   gdalcopyproj.py

gdalcopyproj.py and the compiled versions of fsp, recode, and spatcon should be placed in the directory 'tools'

f) additional documents of the current GWB-version:
-----
-   current version number and changelog: https://ies-ows.jrc.ec.europa.eu/gtb/GWB/GWB_changelog.txt
