Accounting (GWB_ACC)
====================

This module conducts the **Accounting** analysis. Accounting will label and calculate 
the area of all foreground objects. The result are spatially explicit maps and tabular 
summary statistics. Details on the methodology and input/output options can be found in the
`Accounting <https://ies-ows.jrc.ec.europa.eu/gtb/GTB/psheets/GTB-Objects-Accounting.pdf>`_ 
product sheet.

Requirements
------------

A single band (Geo)TIFF image in data format byte:

-   0 byte: missing (optional)
-   1 byte: background
-   2 byte: foreground (forest)
-   3 byte: special background 1 (optional)
-   4 byte: special background 2 (optional)

Processing parameter options are stored in the file :code:`input/acc-parameters.txt`.

.. code-block:: text

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; GWB_ACCOUNTING parameter file:
    ;; NOTE: do NOT delete or add any lines in this parameter file!
    ;;
    ;; ACC: Accounting of image objects and patch area size classes
    ;; Input image requirements: 1b-background, 2b-foreground, optional: 0b-missing
    ;; optional: 3b-special background 1, 4b-special background 2
    ;; Please specify entries at lines 25-29 ONLY using the following options:
    ;;
    ;; line 25: Foreground connectivity: 8 (default) or 4
    ;; line 26: spatial pixel resolution in meters:
    ;; line 27: up to 5 area thresholds [unit: pixels] in increasing order
    ;;          and separated by a single space.
    ;; line 28: output option:   default (stats + image of viewport) OR
    ;;   detailed (stats + images of ID, area, viewport; requires much more CPU/RAM!)
    ;; line 29: big3pink: 0 (no - default) or 1 (show 3 largest objects in pink color)
    ;;
    ;; an example parameter file with default output would look like this:
    ;; 8
    ;; 25
    ;; 200 2000 20000 100000 200000
    ;; default
    ;; 0
    ****************************************************************************
    8
    25
    200 2000 20000 100000 200000
    default
    0
    ****************************************************************************


Example
-------

The results are stored in the directory :code:`output`, one directory for each input 
image accompanied by a log-file providing details on computation time and processing 
success of each input image.


:code:`GWB_ACC` Command and listing of results in the directory :code:`output`:

.. code-block:: console

    $ GWB_ACC -i=$HOME/input -o=$HOME/output
    IDL 9.0.0 (linux x86_64 m64).
    (c) 2023, NV5 Geospatial Solutions, Inc.

    GWB_ACC using:
    dir_input= $HOME/input
    dir_output= $HOME/output
    % Loaded DLM: TIFF.
    Done with: clc3class.tif
    Done with: example.tif
    Done with: gscinput.tif
    Accounting finished sucessfully

    $ ls -R output/
    output/:
    acc.log  clc3class_acc/  example_acc/

    output/clc3class_acc:
    clc3class_acc.csv  clc3class_acc.tif  clc3class_acc.txt

    output/example_acc:
    example_acc.csv  example_acc.tif  example_acc.txt

example statistics and graphical result of input image :code:`example.tif`:

.. code-block:: text

    Accounting size classes result using:
    example
    Base settings: 8-connectivity, pixel resolution: 25 [m]
    Conversion factor: pixel_to_hectare: 0.0625000, pixel_to_acres: 0.154441
    ----------------------------------------------------------------------------
    Size class 1: [1, 200] pixels; color: black
            # Objects      Area[pixels]     % of all objects  % of total FGarea
                2789             31190           97.8596         7.2790497
    ----------------------------------------------------------------------------
    Size class 2: [201, 2000] pixels; color: red
            # Objects      Area[pixels]     % of all objects  % of total FGarea
                    44             23643           1.54386         5.5177484
    ----------------------------------------------------------------------------
    Size class 3: [2001, 20000] pixels; color: yellow
            # Objects      Area[pixels]     % of all objects  % of total FGarea
                    14             98972          0.491228         23.097855
    ----------------------------------------------------------------------------
    Size class 4: [20001, 100000] pixels; color: orange
            # Objects      Area[pixels]     % of all objects  % of total FGarea
                    2             59874         0.0701754         13.973255
    ----------------------------------------------------------------------------
    Size class 5: [100001, 200000] pixels; color: brown
            # Objects      Area[pixels]     % of all objects  % of total FGarea
                    0                 0           0.00000         0.0000000
    ----------------------------------------------------------------------------
    Size class 6: [200001 -> ] pixels; color: green
            # Objects      Area[pixels]     % of all objects  % of total FGarea
                    1            214811         0.0350877         50.132092
    ----------------------------------------------------------------------------
    ----------------------------------------------------------------------------
    Sum of all classes:
            # Objects      Area[pixels]     % of all objects  % of total FGarea
                2850            428490           100.000         100.00000

    Median Patch Size:                5
    Average Patch Size:          150.347
    Standard Deviation:          4143.11

    Largest object:     214811
    

.. figure:: ../_image/example_acc.tif
    :width: 100%
    :align: center

Accounting has been used to map and summarize forest patch size classes in the 
`FAO SOFO2020 <http://www.fao.org/publications/sofo/en/>`_ report and the Forest Europe 
`State of Europe's Forest 2020 <https://foresteurope.org/wp-content/uploads/2016/08/SoEF_2020.pdf>`_ 
report with additional technical details in the respective JRC Technical Reports for 
`FAO <https://doi.org/10.2760/145325>`_ and `FE <https://doi.org/10.2760/991401>`_.
