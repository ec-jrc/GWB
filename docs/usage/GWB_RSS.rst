Restoration Status Summary (GWB_RSS)
====================================

This module will conduct the **Restoration Status Summary** analysis. It will calculate 
key attributes of the current network status, composed of foreground (forest) objects. It  
will also provide the normalized degree of network coherence. The result are tabular 
summary statistics. Details on the methodology and input/output options can be found in the 
`Restoration Planner <https://ies-ows.jrc.ec.europa.eu/gtb/GTB/psheets/GTB-RestorationPlanner.pdf>`_ 
product sheet.

Requirements
------------

A single band (Geo)TIFF image in data format byte.

-   0 byte: missing (optional)
-   1 byte: background
-   2 byte: foreground (forest)

.. warning::

    Any other values are considered as missing data

Processing parameter options are stored in the file :code:`input/rss-parameters.txt`.

.. code-block:: text

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; GTB_RESTORATION-STATUS parameter file:
    ;; NOTE: do NOT delete or add any lines in this parameter file!
    ;;
    ;; RSS: Restoration Status = network coherenceof image objetcs
    ;; Input image requirements: 1b-background, 2b-foreground, optional: 0b-missing
    ;;
    ;; Please specify entry at lines 14 ONLY using the following options:
    ;; line 14: Foreground connectivity: 8 default) or 4
    ;;
    ;; an example parameter file with default output would look like this:
    ;; 8
    ****************************************************************************
    8
    ****************************************************************************

Example
-------

The result is stored in a single csv-file in the directory :code:`output`, listing the 
statistics for each input image in one line, accompanied by a log-file providing details 
on computation time and processing success of each input image.

:code:`GWB_RSS` command and listing of results in the directory output:

.. code-block:: console

    $ GWB_RSS -i=$HOME/input -o=$HOME//output
    IDL 8.8.3 (linux x86_64 m64).
    (c) 2022, Harris Geospatial Solutions, Inc.

    GWB_RSS using:
    dir_input= $HOME//input
    dir_output= $HOME//output
    % Loaded DLM: TIFF.
    Done with: clc3class.tif
    Done with: example.tif
    RSS finished sucessfully

    $ ls -R output/
    output/:
    rss8.csv  rss8.log


Summary statistics for each input image showing the normalized degree of network 
coherence and additional key network parameters:

.. csv-table::
    :header: "FNAME", "AREA", "RAC[%]", "NR_OBJ", "LARG_OBJ", "APS", "CNOA", "ECA", "COH[%]", "REST_POT[%]"

    clc3class.tif,957879.00,23.946975,164,176747,5840.7256,180689,281211.93,29.357771,70.642229
    example.tif,428490.00,42.860572,2850,214811,150.34737,311712,221292.76,51.644789,48.355211

Remarks
-------

-   :code:`GWB_RSS` provides a succinct summary of key network status attributes 
    including area, extent, patch summary statistics, equivalent connected area, degree 
    of network coherence, and the restoration potential.
-   As a normalized index, Coherence or its complement Restoration Potential, can be used 
    to directly compare the integrity of different networks or to quantitatively assess 
    changes in network integrity over time.
-   The provision of key network status attributes is essential and forms the base for 
    any restoration planning.
-   The desktop application 
    `GuidosToolbox <https://forest.jrc.ec.europa.eu/en/activities/lpa/gtb/>`_ provides 
    additional, interactive tools guiding restoration planning.
    

With the provision of a normalized degree of network coherence and restoration potential, :code:`GWB_RSS` provides a powerful tool to measure and rank the integrity of forest networks for different regions of interest. This feature may be useful to set priorities for restoration planning or to measure implementation progress and overall success of policy regulations.