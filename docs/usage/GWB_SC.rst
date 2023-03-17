SpatCon (GWB_SC)
================

This module will SpatCon analysis of foreground 
(`Riitters et al. (2000) <https://www.srs.fs.usda.gov/pubs/ja/ja_riitters006.pdf>`_). 
The result are spatially explicit maps and tabular summary statistics. 
The classification ...so forest.

Requirement
-----------

A single band (Geo)TIFF image in data format byte:

-   0 byte: missing (optional)
-   1 byte: background
-   2 byte: foreground (forest)
-   3 byte: specific background (for only)

Processing parameter options are stored in the file :code:`input/sc-parameters.txt`.

.. code-block:: text

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; GTB_SC parameter file:
    ;;
    ;; an example parameter file for FG-Density and using a 27x27 window:
    ;; 1
    ;; 27
    ;; 1
    ****************************************************************************
    1
    27
    1
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
    P2 finished sucessfully

    $ ls -R output/
    output/:
    example_27  X_27.log

    output/example_27:
    example_27.tif  example_27.txt

Example statistics and spatial result of the input image :code:`example.tif` for X, 
showing degree of forest density:

.. code-block:: text

    X summary at Observation Scale: 27
    Total Foreground Area [pixels]: 428490
    Average X: 73.7660

.. figure:: ../_image/example_8_1_1_1.png
    :width: 50%

Remarks
-------

-   Density, Contagion or Adjacency are scale-dependent (specified by the size of 
    the moving window).
-   This moving window approach (originally called Pf/Pff) forms the base for other 
    derived analysis schemes, such as :code:`GWB_LM`/:code:`GWB_FRAG`.

Both, Density and Contagion add a first spatial information content on top of the primary 
information of forest, forest amount. Information on forest Density and Contagion is 
an integral part of many national forest inventories and forest resource assessments. 
However, the derived products Fragmentation and Landscape Mosaic may be easier to 
communicate.
