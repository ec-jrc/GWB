Usage
=====

The GuidosToolbox Workbench (**GWB**, `homepage <https://forest.jrc.ec.europa.eu/en/activities/lpa/gwb/>`_) is a subset of the desktop software package GuidosToolbox (`GTB <https://forest.jrc.ec.europa.eu/en/activities/lpa/gtb/>`_) designed as a cmd-line application for Linux 64bit servers. Citation reference: `GuidosToolbox Workbench: Spatial analysis of raster maps for ecological applications <https://doi.org/10.1111/ecog.05864>`_.

This document provides usage instructions for the cmd-line implementation of  **GWB**.

Initial setup
-------------

As regular user, please first copy the **GWB** setup into your :code:`$HOME` account using the command:

.. code-block:: console

    $ cp -fr /opt/GWB/*put ~/

You will now find the new directories :code:`input` and :code:`output` in your :code:`$HOME` account.

-   :code:`input`: This directory contains module-specific parameter files, two sample geotif images and a README file.
-   :code:`output`: This directory is empty.

All GWB modules require categorical raster input maps in data type unsigned byte (8bit), with discrete integer values within [0, 255] byte. The two sample images in the directory :code:`input` are:

-   :code:`example.tif`: 0 byte - Missing, 1 byte - Background, 2 byte - Foreground
-   :code:`clc3class.tif`: 1 byte - Agriculture, 2 byte - Natural, 3 byte - Developed


**GWB** is designed to apply the module-specific settings of the respective parameter file to all tif-images placed in the directory :code:`input`. The module-specific results will be written into the directory :code:`output`.

.. note::

    -   Please also run the above cp-command to update your **GWB**-setup files with potentially modified files provided by a newer version of **GWB**.
    -   The directory :code:`input` has a subdirectory :code:`backup` having backup copies of all parameter files. This subdirectory may also be used to temporarily store images that should be excluded from processing.

Example of the **GWB** setup in the user account :code:`~`.

.. code-block:: console

    $ pwd
    ~

    $ ls output/
    $ ls input/
    acc-parameters.txt   clc3class.tif        example.tif
    frag-parameters.txt  mspa-parameters.txt  parc-parameters.txt
    rec-parameters.txt   spa-parameters.txt   backup
    dist-parameters.txt  fad-parameters.txt   lm-parameters.txt
    p223-parameters.txt  readme.txt           rss-parameters.txt

    $ less input/readme.txt
    Images:
    - GWB will process all images from the folder 'input' having the suffix: .tif

    Parameter files: *-parameter.txt
    - please do not delete these files
    - modify only the settings at the end of the file enclosed by *****

    Directory backup: not needed for processing
    - a set of backup parameter files is included here
    - temporarily store images here that you want to exclude from processing


Usage Instructions Overview
---------------------------

To get an overview of all **GWB** modules enter the command: :code:`GWB`

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

    GWB_ACC: Accounting of image objects and area classes
        Requirements: 1b-BG, 2b-FG, optional: 0b-missing,
        optional: 3b-special background 1, 4b-special background 2
        Parameter file: input/acc-parameters.txt

    GWB_DIST: Euclidean Distance and Hypsometric Curve
        Requirements: 1b-BG, 2b-FG, optional: 0b-missing
        Parameter file: input/dist-parameters.txt

    GWB_FAD: Multiscale fragmentation analysis
        Requirements: 1b-BG, 2b-FG, optional: 0b-missing,
        optional: 3b-special BG, 4b-non-fragmenting BG
        Parameter file: input/fad-parameters.txt

    GWB_FRAG: user-selected custom scale fragmentation analysis
        Requirements: 1b-BG, 2b-FG, optional: 0b-missing,
        optional: 3b-special BG, 4b-non-fragmenting BG
        Parameter file: input/frag-parameters.txt

    GWB_LM: Landscape Mosaic
        Requirements: 1b-Agriculture, 2b-Natural, 3b-Developed
        optional: 0b-missing
        Parameter file: input/lm-parameters.txt

    GWB_MSPA: Morphological Spatial Pattern Analysis (up to 25 classes)
        Requirements: 1b-BG, 2b-FG, optional: 0b-missing
        Parameter file: input/mspa-parameters.txt

    GWB_P223: Foreground Density [%], Contagion [%], or Adjacency [%]
        Spatcon: P2, P22, P23, Shannon, Sumd
        Requirements: 1b-BG, 2b-FG, 3b-specific BG (for Adjacency), optional: 0b-missing
        Parameter file: input/p223-parameters.txt

    GWB_PARC: Landscape Parcellation index
        Requirements: [1b, 255b]-land cover classes, optional: 0b-missing
        Parameter file: input/parc-parameters.txt

    GWB_REC: Recode class values
        Requirements: categorical map with up to 256 classes [0b, 255b]
        Parameter file: input/rec-parameters.txt

    GWB_RSS: Restoration Status summary
        Requirements: 1b-BG, 2b-FG, optional: 0b-missing
        Parameter file: input/rss-parameters.txt

    GWB_SPA: Spatial Pattern Analysis (2, 3, 5, or 6 classes)
        Requirements: 1b-BG, 2b-FG, optional: 0b-missing
        Parameter file: input/spa-parameters.txt

    More details in the module-specific parameter files, or run: GWB_XXX --help

    ===============================================================================
         Part B: usage
    ===============================================================================
    a) standalone mode (within the directory GWB): ./GWB_ACC
       OR add a custom full path to your input and output directory i.e.:
       ./GWB_ACC -i=<your dir_input> -o=<your dir_output>

    b) system mode (GWB installed in /opt/):
       To get started in system mode, copy the input/output directories to
       your home folder using the command: cp -fr /opt/GWB/*put ~/
       To process, add the full path to your input and output directory:
       GWB_ACC -i=$HOME/input -o=$HOME/output

    ===============================================================================
         Part C: processing requirements
    ===============================================================================
    RAM requirements depend on module processing settings and the amount
    and the configuration of objects in the input image.
    You can use: /usr/bin/time -v <full GWB-command> and then look
    at 'Maximum resident set size', which will show the maximum
    RAM usage point (in kb) encountered during execution.
     a) RAMpeakGB = divide 'Maximum resident set size' by 1024^2
     b) imsizeGB = image size in GB = xdim*ydim/1024^3
     c) processing RAM requirement by module: RAMpeak/imsizeGB

    Approximate peak RAM usage factors for an image of size imsizeGB:
    GWB_ACC  : 30 * imsizeGB
    GWB_DIST : 18 * imsizeGB
    GWB_FAD  : 30 * imsizeGB
    GWB_FRAG : 13 * imsizeGB
    GWB_LM   :  9 * imsizeGB
    GWB_MSPA : 20 * imsizeGB
    GWB_P223 : 15 * imsizeGB
    GWB_PARC : 22 * imsizeGB
    GWB_REC  :  2 * imsizeGB
    GWB_RSS  : 20 * imsizeGB
    GWB_SPA  : 20 * imsizeGB
    Example: input image 50,000 x 50,000 pixels -> imsizeGB = 2.33 GB.
    Processing this image for GWB_ACC will require 30 * 2.33 ~ 70 GB RAM

    The RAM usage factors above are indicative only. They depend on module
    settings and the amount/configuration of objects in the input image.
    ===============================================================================
     ***  Please scroll up to read GWB information in Part A, B, C above  ***
    ===============================================================================


It is also possible to use the "help" option: :code:`GWB_ACC --help`

.. code-block:: console

    $ GWB_ACC --help
    ----------------------------------------------------------------------------------
    usage: /usr/bin/GWB_ACC -i=dir_input -o=dir_output
    -i=<full path to directory 'input'>
    (with your input images and parameter files);
    Standalone mode: GWB/input
    -o=<full path to directory 'output'>
    (location for results, must exist and must be empty);
    Standalone mode: GWB/output
    --help: show options

    Standalone mode: ./GWB_ACC
    System mode/use custom directories: GWB_ACC -i=<your dir_input> -o=<your dir_output>
    ----------------------------------------------------------------------------------

.. tip::

    When used for the first time, please accept the `EULA <https://ies-ows.jrc.ec.europa.eu/gtb/GWB/EULA_GWB.pdf>`_ terms. This step is only needed once.

Additional, general remarks:

-   The directory :code:`output` must be empty before running a new analysis. Please watch out for hidden files/folders in this directory, which may be the result of an interrupted execution. The safest way to empty the directory is to delete it and recreate a new directory :code:`output`.
-   **GWB** will automatically process all suitable geotiff images (single band and of datatype byte) from the directory :code:`input`. Images of different format or that are not compatible with the selected analysis module requirements will be skipped. Details on each image processing result can be found in the log-file in the directory :code:`output`.
-   **GWB** is written in the  the `IDL language <https://www.l3harrisgeospatial.com/Software-Technology/IDL>`_. It includes all required IDL libraries and the source code of each module, stored in the folder: :code:`/opt/GWB/tools/source/`.
-   To list your current version of **GWB**, or to check for potential new **GWB** versions, please run the command:

    .. code-block:: console

        $ GWB_check4updates

-   Any distance or area measures are calculated in pixels. It is therefore crucial to use images in equal area projection. Conversion to meters/hectares require to know the pixel resolution.

Available Commands
------------------

.. danger::

    Please enter your own settings by amending the module-specific parameters within the section marked with :code:`*******` in the respective input/<module>-parameters.txt file. Don't change anything else in the parameter file, don't delete or add lines or the module execution will crash. If in doubt, consult the respective input/backup/<module>-parameters.txt file.

.. toctree::
    :maxdepth: 1

    GWB_ACC
    GWB_DIST
    GWB_FAD
    GWB_FRAG
    GWB_LM
    GWB_MSPA
    GWB_P223
    GWB_PARC
    GWB_REC
    GWB_RSS
    GWB_SPA