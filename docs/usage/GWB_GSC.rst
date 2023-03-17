GraySpatCon (GWB_GSC)
=============================

This module will calculates a variety of indicators in a shifting, local neighborhood. 
The result are spatially explicit maps and tabular summary statistics. 
Details on the methodology and input/output options can be found in the 
`Fragmentation <https://ies-ows.jrc.ec.europa.eu/gtb/GTB/psheets/GTB-Fragmentation-FADFOS.pdf>`_ 
product sheet.

Requirement
-----------
WIP!

A single band (Geo)TIFF image in data format byte:

-   0 byte: missing (optional)
-   1 byte: background
-   2 byte: foreground (forest)
-   3 byte: specific background (optional)
-   4 byte: non-fragmenting background (optional)

Processing parameter options are stored in the file :code:`input/gsc-parameters.txt`.

.. code-block:: text

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; GTB_GSC parameter file:
    ;;    ***  do NOT delete header lines starting with ";;" ***
    ;;
    ;; 8
    ;; 1
    ****************************************************************************
    8
    1
    ****************************************************************************

Example
-------

The results are stored in the directory :code:`output`, an image and a txt-file for each 
input image accompanied by a log-file providing details on computation time and 
processing success of each input image.

:code:`GWB_GSC` command and listing of results in the directory output:

.. code-block:: console

    $ GWB_GSC -i=$HOME/input -o=$HOME/output
    IDL 8.8.3 (linux x86_64 m64).
    (c) 2022, Harris Geospatial Solutions, Inc.

    GWB_GSC using:
    dir_input= $HOME/input
    dir_output= $HOME/output
    % Loaded DLM: TIFF.
    % Loaded DLM: LAPACK.
    % Loaded DLM: PNG.
    Done with: clc3class.tif
    Done with: example.tif
    GSC finished sucessfully

    $ ls -R output/
    output/:
    gsc.log example_7.tif   example_mscale.txt

Example statistics and spatial result of aGSC per-pixel analysis of the input 
image :code:`example.tif`:

.. image:: ../_image/example_fad_barplot.png
    :width: 49%

.. image:: ../_image/example_fad_mscale.png
    :width: 49%

Remarks
-------

-   The result provides additional statistics in txt and csv format.
-   In addition to the above multi-scale image, 
-   Options to report at pixel- or patch-level and t

Fragmentation has been used to map and summarize the degree of forest fragmentation by 
Riitters et al. (`2002 <https://doi.org/10.1007/s10021-002-0209-2>`_, 
`2012 <https://doi.org/10.1038/srep00653>`_) as well as the US Forest Inventory and 
Analysis (`FIA <https://www.fia.fs.fed.us/>`_) reports since 2003.
