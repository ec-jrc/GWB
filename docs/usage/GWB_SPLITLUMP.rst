Cut/process/merge (GWB_SPLITLUMP)
=================================

This module will setup two scripts to cut, process, and merge buffered stripes of a single
image, which is too large to be processed directly via a GWB module.


Requirements
------------

Single band geotiff in data format byte:

-   0 byte: missing (optional)
-   1 byte: background
-   2 byte: foreground (forest)

Processing parameter options are stored in the file :code:`input/spa-parameters.txt`.

.. code-block:: text

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; GWB_SPLITLUMP parameter file:
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; Please amend only the options at the end of this file and between the lines in *****
    ;; This module is only needed when trying to process very large maps for either:
    ;; GWB_FRAG/_GSC/_LM/_SPATCON      OR       GWB_ACC/_DIST/_MSPA/_PARC/_RSS/_SPA
    ;; Note: do not calculate statistics when GWB-processing of buffered stripes as this is meaningless
    ;;
    ;;
    ;; Rationale:
    ;; On machines with insufficient amount of available RAM, a map may be too large for GWB processing.
    ;; This issue can be addressed by processing buffered stripes and reassemble them into the final map.
    ;; The buffers must be large enough to maintain the neighborhood information at the intersection
    ;; of neighboring stripes. Buffers are added on both sides of the stripes, except for the top stripe and
    ;; the bottom stripe. The buffer is added to the top stripe at the bottom only, and is added to
    ;; the bottom stripe at the top only.
    ;;
    ;;  There are two categories of GWB modules which analyse the neighborhood:
    ;;  A) Moving window analysis: GWB_FRAG/_GSC/_LM/_SC
    ;;     Analysis of the local neighborhood covered by the size of the moving window:
    ;;     a buffer of 0.5*(window size +1) is sufficient.
    ;;
    ;;  B) Analysis of the spatial extent of map objects: GWB_ACC/_DIST/_MSPA/_PARC/_RSS/_SPA
    ;;     The reliable assessment requires loading the entire map into RAM.
    ;;     For example, a Bridge or a Opening going diagonal through the map can only be
    ;;     found by MSPA if the entire feature extent is 'visible' to MSPA <-> the entire map is in RAM.
    ;;     The exact solution of entire map in RAM can be approximated by setting up as few as possible
    ;;     horizontal buffered stripes with a sufficiently large buffer to capture the spatial extent of large
    ;;     map objects, typically at least 5000 pixels, or more. The result can then be compared to a vertical
    ;;     buffered striping process and if they match, the selected buffer width may be sufficient.
    ;;     *** Note ***:  the 'worst case scenario' of a diagonal feature throughout the map can never be
    ;;     detected via buffered striping but only though loading the entire map into RAM.
    ;; Priority list for  GWB_ACC/_DIST/_MSPA/_PARC/_RSS/_SPA:
    ;;     1) if possible, *** avoid *** buffered striping by using a machine with sufficient RAM
    ;;         (GWB_ACC: 30 * imsizeGB, GWB_(M)SPA: 20 * imsizeGB)
    ;;     2) if you must use striping, use as few stripes as possible with sufficiently large buffers
    ;;     3) compare the result of horizontal and vertical striping and increase buffers if they do not match
    ;;
    ;; We use a new *empty* directory "splitlump" for all intermediate processing steps.
    ;; GWB_SPLITLUMP will setup two bash-scripts in the empty directory  "splitlump":
    ;; - "./splitter.sh" to cut the single large map into buffered stripes for GWB processing,
    ;; - "./lumper.sh" to be used for reassembling the processed buffered stripes.
    ;;
    ;; Steps to be conducted upon completion of GWB_SPLITLUMP:
    ;; 1) open the "splitlump" directory and read through the comments of "./splitter.sh"
    ;;     Note that on a multi-user system you may not have full access to the amount of available RAM.
    ;; 2) if the system setup is appropriate, open a terminal in the  "splitlump" directory and
    ;;     run the bash-script "./splitter.sh" to cut the large input map into buffered stripes
    ;; 3) place the appropriate GWB_XXX parameterfile into the "splitlump" directory
    ;; 4) use   GWB_XXX -i=<splitlump directory> -o =<your output directory>
    ;;     to process all buffered stripes with the GWB module of your choice
    ;; 5) move all resulting tif-maps from step d) into the  "splitlump" directory
    ;; 6) open a terminal in the  "splitlump" directory and run the bash-script "./lumper.sh"
    ;;     to cut and reassemble all processed buffered stripes (tif-maps) into the final large processed map.
    ;;
    ;; Please specify entries at line 72-77 ONLY using the following options:
    ;; line 72: full path to the empty directory "splitlump" (directory must exist and must be empty)
    ;; line 73: full path to the large (GeoTIFF) input map with min. X/Y-dimension of 12,000 pixels
    ;; line 74: number of buffered stripes: select a single number within [2, 3, 4, ..., 100]
    ;; line 75: buffer width in pixels: select a single number within [5, 6, ..., 50000]
    ;; line 76: orientation of buffered stripes: horizontal (default)    or    vertical (MUCH slower)
    ;; line 77: dryrun: 0 (default) or 1 (rename output of splitter.sh to quickly test lumper.sh)
    ;;
    ;; an example parameter file using the default settings:
    ;; ~/input/splitlump
    ;; ~/mylargemap.tif   
    ;; 3   
    ;; 2000
    ;; horizontal
    ;; 0
    ****************************************************************************
    ~/input/splitlump
    ~/input/backup/Mekong_2019.tif
    2
    1200
    horizontal
    1
    ****************************************************************************


Example
-------

The results are stored in the directory :code:`output`, one directory for each input image accompanied by a log-file providing details on computation time and processing success of each input image.

:code:`GWB_SPA` command and listing of results in the directory output:

.. code-block:: console

    $ GWB_SPA -i=~/input -o=~/output
    IDL 8.8.0 (linux x86_64 m64).
    (c) 2020, Harris Geospatial Solutions, Inc.

    GWB_SPA using:
    dir_input= ~/input
    dir_output= ~/output
    % Loaded DLM: TIFF.
    Done with: clc3class.tif
    Done with: example.tif
    SPA2 finished sucessfully

    $ ls -R output/
    output/:
    example_spa2  spa2.log

    output/example_spa2:
    example_spa2.tif  example_spa2.txt

Statistics and spatial result of the input image :code:`example.tif` showing a 2-class segmentation (SPA2): Contiguous and Small & Linear Features (SLF):

.. code-block:: text

    SPA2: 8-connected Foreground, summary analysis for image:
    ~/input/example.tif

    Image Dimension X/Y: 1000/1000
    Image Area =               Data Area                    + No Data (Missing) Area
            = [ Foreground (FG) +   Background (BG)  ]     +          Missing
            = [        FG       + {Core-Opening + other BG} ] +       Missing

    ================================================================================
            Category              Area [pixels]:
    ================================================================================
            Contiguous:                 388899
    +              SLF:                  39591
    --------------------------------------------------------------------------------
    = Foreground Total:                 428490
    + Background Total:                 571240
    --------------------------------------------------------------------------------
    =  Data Area Total:                 999730

             Data Area:                 999730
    +          Missing:                    270
    --------------------------------------------------------------------------------
    = Image Area Total:                1000000


    ================================================================================
            Category    Proportion [%]:
    ================================================================================
       Contiguous/Data:     38.9004
    +         SLF/Data:      3.9602
    --------------------------------------------------------------------------------
               FG/Data:     42.8606
    --------------------------------------------------------------------------------
         Contiguous/FG:     90.7603
    +           SLF/FG:      9.2397
    ================================================================================


    ================================================================================
            Category          Count [#]:
    ================================================================================
            Contiguous:             847
            FG Objects:            2850
                   SLF:            6792
    ================================================================================

.. figure:: ../_image/example_spa2.png
    :width: 50%

Remarks
-------

-   The full version, GWB_MSPA provides many more features and classes.
-   Please use :code:`GWB_MSPA` if you need an edge width > 1 pixel and/or to detect connecting pathways.

:code:`GWB_SPA` is a purely geometric analysis scheme, which can be applied to any type of raster image. It is ideal to describe the morphology of foreground (forest) patches for basic mapping and statistics, which may be sufficient in many application fields. Advanced analysis, including the detection of connecting pathways require using the full version :code:`GWB_MSPA`.