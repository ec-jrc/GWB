Usage
=====

This page provides GWB usage instructions. GWB uses two directories :code:`input` and 
:code:`output`, located in your :code:`$HOME` account (system-mode) or in 
:code:`$HOME/GWB<version>/GWB/` (standalone mode). In system-mode, 
you can reset the original setup using the command:

.. code-block:: console

    $ cp -fr /opt/GWB/*put ~/


Directory setup
---------------
The two directories have the following content and functionality: 

**Directory:** :code:`input`: all your (Geo)TIFF input images will go here

- :code:`backup`: backup copies of all parameter files. This subdirectory may also be 
  used to temporarily store images that should be excluded from processing
- :code:`splitlump`: empty directory where GWB_SPLITLUMP results will be saved 
- GWB module-specific parameter files
- two sample GeoTIFF images: :code:`example.tif` and :code:`clc3class.tif`
- readme.txt: information on file content and usage
    
**Directory:** :code:`output`: empty directory where GWB results will be saved

- resulting images/statistics 
- log.txt: a log-file with information on the batch process

**Input data:** All GWB modules require categorical raster input maps in the (Geo)TIFF 
format and of data type unsigned byte (8bit), with discrete integer values within 
[0, 255] byte. The three sample images in the directory :code:`input` are:

1. :code:`example.tif`: 0 byte - Missing, 1 byte - Background, 2 byte - Foreground
2. :code:`clc3class.tif`: 1 byte - Agriculture, 2 byte - Natural, 3 byte - Developed
3. :code:`gscinput.tif`: [0, 100] byte - grayscale data, 255 byte - Missing

.. note::

   - GWB is designed to apply the module-specific settings of the respective parameter 
     file to **all tif-images** placed in the directory :code:`input`
   - Use the subdirectory :code:`input/backup` to temporarily store images that should 
     be excluded from processing
   - In system-mode only, you can use custom locations and names for the directories 
     :code:`input` and :code:`output` provided the input directory contains the required
     files
   - The module-specific results will be written into the directory :code:`output` 
     or into the directory :code:`input/splitlump` for :code:`GWB_SPLITLUMP` 


Example of the GWB setup in the user account :code:`~`, or :code:`$HOME`.

.. code-block:: console

    $ pwd
    ~

    $ ls output/
    $ ls input/
    backup/              splitlump/           readme.txt
    clc3class.tif        example.tif 
    acc-parameters.txt   dist-parameters.txt  frag-parameters.txt 
    gsc-parameters.txt   lm-parameters.txt    mspa-parameters.txt 
    parc-parameters.txt  rec-parameters.txt   rss-parameters.txt 
    sc-parameters.txt    spa-parameters.txt   splitlump-parameters.txt
    

    $ less input/readme.txt
    Images:
    - GWB will process all images from the folder 'input' having the suffix: .tif

    Parameter files: *-parameter.txt
    - please do not delete these files
    - modify only the settings at the end of the file enclosed by *****

    Directory backup: not needed for processing
    - a set of backup parameter files is included here
    - temporarily store images here that you want to exclude from processing
    
    Directory splitlump: empty, will contain the output of GWB_SPLITLUMP


Usage Instructions Overview
---------------------------

To get an overview of all GWB modules enter the command: :code:`GWB`

.. code-block:: console

    $ GWB
    ===============================================================================
              GWB: GuidosToolbox-Workbench
    ===============================================================================
         Part A: brief module description
    ===============================================================================
    cmd-line image analysis modules from GuidosToolbox
    (https://forest.jrc.ec.europa.eu/en/activities/lpa/gtb/):
    Usage of GWB implies compliance with the conditions in the EULA_GWB.pdf
    (https://ies-ows.jrc.ec.europa.eu/gtb/GWB/EULA_GWB.pdf)

    GWB_check4updates
       Display installed and current program version
       and test for program updates
       (Automatic updater for Debian systems: '/opt/GWB/tools/GWBupdate_deb.sh')     

    GWB_ACC: Accounting of image objects and area classes
       Requirements: 1b-BG, 2b-FG, optional: 0b-missing,
       optional: 3b-special background 1, 4b-special background 2
       Parameter file: input/acc-parameters.txt

    GWB_DIST: Euclidean Distance and Hypsometric Curve
       Requirements: 1b-BG, 2b-FG, optional: 0b-missing
       Parameter file: input/dist-parameters.txt

    GWB_FRAG: user-selected custom scale fragmentation analysis
       Requirements: binary or grayscale map (see frag-parameters.txt), 
       Parameter file: input/frag-parameters.txt
        
    GWB_GSC: GraySpatCon analysis of attribute adjacency table
       Requirements: categorical map within [0b, 255b]
       Parameter file: input/gsc-parameters.txt

    GWB_LM: Landscape Mosaic
       Requirements: 1b-Agriculture, 2b-Natural, 3b-Developed
       optional: 0b-missing
       Parameter file: input/lm-parameters.txt

    GWB_MSPA: Morphological Spatial Pattern Analysis
       Requirements: 1b-BG, 2b-FG, optional: 0b-missing
       Parameter file: input/mspa-parameters.txt

    GWB_PARC: Landscape Parcellation index
       Requirements: [1b, 255b]-land cover classes, optional: 0b-missing
       Parameter file: input/parc-parameters.txt

    GWB_REC: Recode class values
       Requirements: categorical map with up to 256 classes [0b, 255b]
       Parameter file: input/rec-parameters.txt

    GWB_RSS: Restoration Status summary
       Requirements: 1b-BG, 2b-FG, optional: 0b-missing
       Parameter file: input/rss-parameters.txt

    GWB_SC: SpatCon analysis of attribute adjacency table
       Requirements: categorical map within [0b, 255b]
       Parameter file: input/sc-parameters.txt

    GWB_SPA: Spatial Pattern Analysis (2, 3, 5, or 6 classes)
       Requirements: 1b-BG, 2b-FG, optional: 0b-missing
       Parameter file: input/spa-parameters.txt

    GWB_SPLITLUMP: Cut/process/merge buffered stripes of large images
       Requirements: categorical map within [0b, 255b]
       Parameter file: input/splitlump-parameters.txt

    More details in the module-specific parameter files, or run: GWB_XXX --help

    ===============================================================================
         Part B: usage
    ===============================================================================
    a) system mode (GWB installed in /opt/GWB/): 
       To get started in system mode, copy the input/output directories to
       your $HOME folder using the command: cp -fr /opt/GWB/*put ~/
       To process, add the full path to your input and output directory: 
       GWB_ACC -i=$HOME/input -o=$HOME/output
 
    b) standalone mode (within $HOME/GWB<version>/GWB): ./GWB_ACC 
       Note: standalone mode requires using the existing directories:
       $HOME/GWB<version>/GWB/input           as the input directory and
       $HOME/GWB<version>/GWB/output          as the output directory
       To process, ensure you are in $HOME/GWB<version>/GWB, then run:
       ./GWB_ACC

    ===============================================================================
         Part C: processing requirements
    ===============================================================================
    RAM requirements depend on amount/configuration of image objects, the selected  
    module and processing settings, and the image size: imsizeGB = xdim*ydim/1024^3
  
    Note:
    a) On multi-user systems you may not have full access to the available RAM
    b) The peak RAM usage factors below are indicative only. 
    c) The log-file will list: imsizeGB, ~ RAM requirements, peak RAM usage

    Approximate peak RAM usage factors for an image of size imsizeGB:
    GWB_ACC  : 30 * imsizeGB
    GWB_DIST : 18 * imsizeGB
    GWB_FRAG : 20 * imsizeGB
    GWB_GSC  :  5 * imsizeGB
    GWB_LM   :  9 * imsizeGB
    GWB_MSPA : 20 * imsizeGB
    GWB_PARC : 22 * imsizeGB
    GWB_REC  :  2 * imsizeGB
    GWB_RSS  : 20 * imsizeGB
    GWB_SPA  : 20 * imsizeGB
    GWB_SC   :  5 * imsizeGB
    GWB_SPLITLUMP: shell-script, no RAM required
 
    Example: input image 50,000 x 50,000 pixels -> imsizeGB = 2.33 GB.
    Processing this image for GWB_ACC will require 30 * 2.33 ~ 70 GB RAM
    
    Online manual:  https://gwbdoc.readthedocs.io


It is also possible to use the "help" option, for example: :code:`GWB_ACC --help`

.. code-block:: console

    $ GWB_ACC --help    
    ----------------------------------------------------------------------------------
    1) System mode - you MUST specify custom directories:
    ----------------------------------------------------------------------------------
    GWB_ACC -i=<your dir_input> -o=<your dir_output>
    -i=<full path to directory 'input'> 
        (with your input images and parameter files)
    -o=<full path to directory 'output'> 
        (location for results, must exist and must be empty)
    
    ----------------------------------------------------------------------------------
    2) Standalone mode - fixed directory setup:
    ----------------------------------------------------------------------------------
    cd into: $HOME/GWB<version>/GWB
    then run the command: ./GWB_ACC
    Note: standalone mode enforces using the default standalone
    - input directory: $HOME/GWB<version>/GWB/input 
      (with your input images and parameter files);
    - output directory: $HOME/GWB<version>/GWB/output 
      (location for results, must exist and must be empty);
    ----------------------------------------------------------------------------------
     
    other cmd-line options:
    --help: show cmd-line options
    --nox: enforce headless execution via xvfb-run
    --version: show GWB version number

.. tip::

    When used for the first time, please accept the 
    `EULA <https://ies-ows.jrc.ec.europa.eu/gtb/GWB/EULA_GWB.pdf>`_ terms. 
    This step is only needed once.

Additional, general remarks:

-   The directory :code:`output` must be empty before running a new analysis. Please 
    watch out for hidden files/folders in this directory, which may be the result of an 
    interrupted execution. The safest way to empty the directory is to delete it and 
    recreate a new directory :code:`output`.
-   GWB will automatically process all suitable (Geo)TIFF images (single band and of 
    datatype byte) from the directory :code:`input`. Images of different format or that 
    are not compatible with the selected analysis module requirements will be skipped. 
    Details on each image processing result can be found in the log-file in the 
    directory :code:`output`.
-   GWB is written in the 
    `IDL language <https://www.nv5geospatialsoftware.com/Products/IDL>`_. It 
    includes all required IDL libraries and the source code of each module, stored in 
    the folder: :code:`/opt/GWB/tools/source/`.
-   To list your current version of GWB, or to check for a potential new GWB version, 
    please run the command :code:`GWB` or:

    .. code-block:: console

        $ GWB_check4updates

-   Any distance or area measures are calculated in pixels. It is therefore crucial 
    to use maps in equal area projection. Conversion to meters/hectares require 
    knowing the pixel resolution.

Available Commands
------------------

.. danger::

    Please only amend the settings at the end of the module-specific parameter files 
    :code:`input/<module>-parameters.txt` within the section marked with :code:`*******`.
    A wrong setup of this final section will crash the module execution. If in doubt, 
    consult the respective backup file :code:`input/backup/<module>-parameters.txt`.

.. toctree::
    :maxdepth: 1

    GWB_ACC
    GWB_DIST
    GWB_FRAG
    GWB_GSC
    GWB_LM
    GWB_MSPA
    GWB_PARC
    GWB_REC
    GWB_RSS
    GWB_SC
    GWB_SPA
    GWB_SPLITLUMP
    