Fragmentation (GWB_FRAG)
========================

This module conducts the **fragmentation** analysis at a **user-specified**
single (or multiple) observation scale. The result are spatially explicit maps and 
tabular summary statistics. Details on the methodology and input/output options can be 
found in the 
`Fragmentation <https://ies-ows.jrc.ec.europa.eu/gtb/GTB/psheets/GTB-Fragmentation-FADFOS.pdf>`_ 
product sheet.

Requirements
------------

A single band (Geo)TIFF image in data format byte:

-   0 byte: missing (optional)
-   1 byte: background
-   2 byte: foreground (forest)
-   3 byte: specific background (optional)
-   4 byte: non-fragmenting background (optional)

Processing parameter options are stored in the file :code:`input/frag-parameters.txt`.

.. code-block:: text

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; GTB_FRAG parameter file:
    ;; NOTE: do NOT delete or add any lines in this parameter file!
    ;; Fragmentation analysis at up to 10 user-selected Fixed Observation Scales (FOS):
    ;; FAC (Foreground Area Clustering); FAD (Foreground Area Density)
    ;;
    ;; Options:
    ;; FAC(FAD)5/6: per-pixel clustering (density), color-coded into 5/6 fragmentation classes
    ;; FAC(FAD)-APP2/5: average per-patch clustering (density), color-coded into 2/5 classes
    ;; 
    ;; Input image requirements: 1b-background, 2b-foreground, optional: 
    ;;    0b-missing, 3b-special background, 4b-non-fragmenting background
    ;;
    ;; FRAG will provide one (1) image per observation scale and summary statistics.
    ;; (method: FAC or FAD; reporting at pixel or patch (APP) level; # of reporting classes: 2, 5, 6)
    ;; Please specify entries at lines 32-36 ONLY using the following options:
    ;; line 32: FAC_5 (default)  or  FAC_6, FAC-APP_2, FAC_APP_5, FAD_5, FAD_6, FAD-APP_2  or  FAD-APP_5
    ;; line 33: Foreground connectivity: 8 (default) or 4
    ;; line 34: pixel resolution [meters]
    ;; line 35: up to 10 window sizes (unit: pixels, uneven within [3, 501] ) in increasing order and separated by a single space.
    ;; line 36: high-precision: 1-float precision  (default)  or 0-rounded byte
    ;; line 37: statistics: 0 (default) or 1 (add summary statistics)
    ;;
    ;; an example parameter file using the default settings:
    ;; FAC_5
    ;; 8
    ;; 100
    ;; 27
    ;; 1
    ;; 0
    ****************************************************************************
    FAC_5
    8
    100
    27
    1
    1
    ****************************************************************************

Example
-------

The results are stored in the directory :code:`output`, one directory for each input 
image accompanied by a log-file providing details on computation time and processing 
success of each input image.

:code:`GWB_FRAG` command and listing of results in the directory output:

.. code-block:: console

    $ GWB_FRAG -i=$HOME/input -o=$HOME/output
    IDL 8.8.3 (linux x86_64 m64).
    (c) 2022, Harris Geospatial Solutions, Inc.

    GWB_FRAG using:
    dir_input= $HOME/input
    dir_output= $HOME/output
    % Loaded DLM: TIFF.
    Done with: clc3class.tif
    Done with: example.tif
    Frag finished sucessfully

    $ ls -R output/
    output/:
    clc3class_frag/  example_frag/  frag.log

    output/clc3class_frag:
    clc3class_fos-fac_5class_27.sav  clc3class_fos-fac_5class_27.tif  
    clc3class_fos-fac_5class.csv     clc3class_fos-fac_5class.txt
  

    output/example_frag:
    example_fos-fac_5class_27.sav    example_fos-fac_5class_27.tif  
    example_fos-fac_5class.csv       example_fos-fac_5class.txt

Example statistics and spatial result of custom-scale per patch analysis of the input 
image :code:`example.tif`, here FAC_5 showing fragmentation color-coded into five 
categories.

.. code-block:: text

    Fragmentation analysis using Fixed Observation Scale (FOS)
    Method options: FAC (Foreground Area Clustering); FAD (Foreground Area Density)
    Summary analysis for image: 
    example.tif
    ================================================================================
    FOS parameter settings:
    Foreground connectivity: 8-conn FG
    FOS-type selected: FAC_5
    Method: FAC
    Reporting style: FAC at pixel level
    Number of reporting classes: 5
    Pixel resolution [m]: 100.000
    Window size [pixels]: 27
    Observation scale [(window size * pixel resolution)^2]: 
    Observation scale:   1
    Neighborhood area:   27x27     
         [hectare]:     729.00
           [acres]:    1801.40
    ================================================================================
    Image foreground statistics:
    Foreground area [pixels]: 428490
    ================================================================================
    Proportion [%] of foreground area in foreground cover class:
    FAC at pixel level: 5 classes
                   Rare (FAC-pixel value within: [0 - 9]):      3.0306
               Patchy (FAC-pixel value within: [10 - 39]):     13.7917
         Transitional (FAC-pixel value within: [40 - 59]):     14.4645
             Dominant (FAC-pixel value within: [60 - 89]):     31.2992
            Interior (FAC-pixel value within: [90 - 100]):     37.4139
    ================================================================================
    Precision: floating point
    Average pixel value across all foreground pixels using FAC-method:     70.8060
                       Equivalent to average foreground connectivity:      70.8060
                       Equivalent to average foreground fragmentation:     29.1940


.. figure:: ../_image/example_fos-fac_5class_27.tif
    :width: 100%

Remarks
-------

-   The result provides additional statistics in txt and csv format.
-   The IDL-specific sav-file can be used in GTB to conduct fragmentation 
    change analysis.
-   The result provides one fragmentation image for each custom observation scale. 
    In the example above, the user selected 1 observation scale with a local 
    neighborhood of 27x27 pixels.
-   This module provides options to report at pixel- or patch-level and to select the 
    number of fragmentation classes (6, 5, 2).

Fragmentation has been used to map and summarize the degree of forest fragmentation in the
`FAO SOFO2020 <http://www.fao.org/publications/sofo/en/>`_ report and the Forest Europe 
`State of Europe's Forest 2020 <https://foresteurope.org/wp-content/uploads/2016/08/SoEF_2020.pdf>`_ 
report with additional technical details in the respective JRC Technical Reports for 
`FAO <https://doi.org/10.2760/145325>`_ and `FE <https://doi.org/10.2760/991401>`_.