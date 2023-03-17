Parcellation (GWB_PARC)
=======================

This module will conduct the **Parcellation** analysis. It provides a statistical summary 
file (txt/csv- format) with details for each unique class found in the image as well as 
the full image content: class value, total number of objects, total area, degree of 
parcellation. Details on the methodology and input/output options can be found in the 
`Parcellation <https://ies-ows.jrc.ec.europa.eu/gtb/GTB/psheets/GTB-Objects-Parcellation.pdf>`_ 
product sheet.

Requirements
------------

A single band (Geo)TIFF image in data format byte:

-   0 byte: missing (optional)
-   at least two different landcover classes

Processing parameter options are stored in the file :code:`input/parc-parameters.txt`.

.. code-block:: text

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; GTB_PARC parameter file:
    ;; NOTE: do NOT delete or add any lines in this parameter file!
    ;;
    ;; PARC: Landscape Parcellation index
    ;; Input image requirements: [1b, 255b]-land cover classes,
    ;;    optional: 0b-missing
    ;;
    ;; PARC will provide summary statistics only.
    ;;
    ;; Please specify entries at lines 17 ONLY using the following options:
    ;; line 17: Foreground connectivity: 8 (default) or 4
    ;;
    ;; an example parameter file using 8-connected foreground:
    ;; 8
    ****************************************************************************
    8
    ****************************************************************************

Example
-------

The results are stored in the directory :code:`output`, one directory for each input 
image accompanied by a log-file providing details on computation time and processing 
success of each input image.

:code:`GWB_PARC` command and listing of results in the directory output:

.. code-block:: console

    $ GWB_PARC -i=$HOME/input -o=$HOME/output
    IDL 8.8.3 (linux x86_64 m64).
    (c) 2022, Harris Geospatial Solutions, Inc.

    GWB_PARC using:
    dir_input= $HOME/input
    dir_output= $HOME/output
    % Loaded DLM: TIFF.
    Done with: clc3class.tif
    Done with: example.tif
    PARC finished sucessfully

    $ ls -R output/
    output/:
    clc3class_parc  example_parc  parc.log

    output/clc3class_parc:
    clc3class_parc.csv  clc3class_parc.txt

    output/example_parc:
    example_parc.csv  example_parc.txt


Example statistics of the input image :code:`clc3class.tif` showing statistics and degree 
of parcellation for each land cover class as well as for the entire image area:

.. code-block:: text

    Class   Value      Count     Area[pixels]     APS          AWAPS       AWAPS/data       DIVISION      PARC[%]
        1       1          45       2448931    54420.7000  2076600.0000  1271360.0000        0.1520        1.1937
        2       2         164        957879     5840.7300    82557.6000    19770.0000        0.9138       17.7426
        3       3         212        593190     2798.0700   128177.0000    19008.4000        0.7839       11.0897
    ================================================================================================================
    8-conn. Parcels:      421       4000000     9501.1875                1310139.4429        0.6725        8.0790

Remarks
-------

-   Parcellation is a normalized summary index in [0, 100]%.
-   :code:`GWB_PARC` provides a tabular summary only.

Parcellation, or the degree of dissection, may be useful to provide a quick tabular 
summary for each land cover class as well as for the entire image. Together with the 
degree of division, it may be used to make a statement on the dissection of a particular 
land cover class. Because Parcellation is a normalized index, measuring Parcellation can 
be used to quantify temporal changes over a given site as well as directly compare the 
degree of parcellation of different sites. Being able to quantify changes in percent 
may also be useful to investigate if a given landscape planning measure had in fact 
a tangible influence on a specific land cover type or not.
