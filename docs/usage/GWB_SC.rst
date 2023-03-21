SpatCon (GWB_SC)
================

This module provides full access to the spatial convolution program 
**SpatCon**. Back in 1992, Kurt Riitters started coding a suite of landscape pattern 
metrics from a categorical raster map 
(`Riitters et al. (1995) <https://link.springer.com/content/pdf/10.1007/BF00158551.pdf>`_, 
`Riitters et al. (2000) <https://www.srs.fs.usda.gov/pubs/ja/ja_riitters006.pdf>`_). 
Over time, **SpatCon** grew to now offer 21 spatial convolution metrics, which are 
summarised in a dedicated 
`Technical Note <https://github.com/ec-jrc/GWB/blob/main/tools/external_sources/GWB_SPATCON-TechnicalNote.pdf>`_.
**SpatCon** conducts a moving window, or focal analysis and results in a spatially 
explicit map for the selected metric. 


Requirement
-----------

A single band (Geo)TIFF image in data format byte. Metric-specific requirements and 
processing options are stored in the file :code:`input/sc-parameters.txt`.

.. code-block:: text

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; GTB_SC parameter file:
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; For all output types, missing indicates the input window contained only
    ;; missing pixels or missing pixel adjacencies.
    ;; Missing values are coded as 0 (rounded byte), or -0.01 (float precision).
    ;;
    ;; Rule options at the end of this file and between the lines in *****
    ;; 1 = Majority (most frequent) pixel value
    ;; 6 = Landscape mosaic (19-class version)
    ;; 7 = Landscape mosaic (103-class version)
    ;; 10 = Number of unique pixel values
    ;; 20 = Median pixel value
    ;; 21 = Mean pixel value
    ;; 5x = Pixel diversity:
    ;;    51 = Gini-Simpson pixel diversity
    ;;    52 = Gini-Simpson pixel evenness
    ;;    53 = Shannon pixel evenness
    ;;    54 = Pmax
    ;; 7x = Pixel adjacency (with regard to order of pixels in pairs):
    ;;    71 = Angular second moment
    ;;    72 = Gini-Simpson adjacency evenness
    ;;    73 = Shannon adjacency evenness
    ;;    74 = Sum of diagonals
    ;;    75 = Proportion of total adjacencies involving a specific pixel value
    ;;    76 = Proportion of total adjacencies which are between two specific pixel values
    ;;    77 = Proportion of adjacencies involving a specific pixel value which are adjacencies with that same pixel value
    ;;    78 = Proportion of adjacencies involving a specific pixel value which are adjacencies
    ;;             between that pixel value and another specific pixel value
    ;; 8x = Pixel value density and ratios
    ;;    81 = Area density
    ;;    82 = Ratio of the frequencies of two specified pixel values
    ;;    83 = Combined ratio of two specific pixel values
    ;;
    ;; for more details on SpatCon, see the Technical Note and/or source code at:
    ;; https://github.com/ec-jrc/GWB/tree/main/tools/external_sources/
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; SpatCon parameters for all rules (some rules use only a subset of all parameters)
    ;; R (mapping rule in {1,6,7,10,20,21,51,52,53,54,71,72,73,74,75,76,77,78,81,82,83})
    ;; W (window size - minimum 3, maximum < x or y dimension of input map)
    ;; A (first target code - required for mapping rules 75, 76, 77, 78, 81, 82, 83. Default = 0)
    ;; B (second target code - required for mapping rules 76, 78, 82, 83. Default = 0)
    ;; H (handling of missing values or adjacencies: 1-ignore. 2-include;  -no effect for mapping rules 21, 82, 83. Default = 1)
    ;; F (output precision: 0 = 8-bit byte. 1 = 32-bit float. Float is not available for mapping rules 1, 6, 7, 10. Default = 0)
    ;; Z (Request re-code of input pixels. 0 = No. 1 = Yes. Default = 0)
    ;; M (AFTER optional re-coding (z = 1), the pixel value that is missing. Default = 0)
    ;;
    ;; NOTE: parameters R and W are mandatory. Parameters that are not specified will use their default value.
    ;; Example parameter file for running spatcon rule Majority and using a 27x27 window:
    ;; R 1
    ;; W 27
    ****************************************************************************
    R 81
    W 27
    A 2
    B 3
    H 1
    F 0
    Z 0
    M 0
    ****************************************************************************


Example
-------

The results are stored in the directory :code:`output`, one directory for each input 
image accompanied by a log-file providing details on computation time and processing 
success of each input image.

:code:`GWB_SC` command and listing of results in the directory output:

.. code-block:: console

    $ GWB_SC -i=$HOME/input -o=$HOME/output
    IDL 8.8.3 (linux x86_64 m64).
    (c) 2022, Harris Geospatial Solutions, Inc.

    GWB_SC using:
    dir_input= $HOME/input
    dir_output= $HOME/output
    % Loaded DLM: TIFF.
    Done with: clc3class.tif
    Done with: example.tif
    RULE 81 finished sucessfully

    $ ls -R output/
    output/:
    clc3class_rule81_27/ example_rule81_27/  SpatCon.log

    output/clc3class_rule81_27:
    clc3class_rule81_27.tif

    output/example_rule81_27:
    example_rule81_27.tif

Example spatial result of the input image :code:`example.tif` for Rule 81, showing the 
area density value in a 27x27 moving window:

.. figure:: ../_image/example_rule81_27.tif
    :width: 100%

Remarks
-------

-   All density or adjacency metrics are scale-dependent (specified by the size of the 
    moving window).
-   Some **SpatCon** moving window metrics form the base for other derived analysis 
    schemes, such as :code:`GWB_LM` (Rule 6, 7) and :code:`GWB_FRAG` (Rule 76, 81).


Both, Density and Contagion add a first spatial information content on top of the primary 
information of forest, forest amount. Information on forest Density and Contagion is 
an integral part of many national forest inventories and forest resource assessments. 
However, the derived products Fragmentation and Landscape Mosaic may be easier to 
communicate.
