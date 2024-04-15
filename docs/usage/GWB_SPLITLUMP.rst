Cut/process/merge (GWB_SPLITLUMP)
=================================

This module will setup two scripts, which allow processing a single map that is too large 
to be processed directly via a GWB module.


Rationale
---------

On machines with insufficient amount of available RAM, a map may be too large for GWB 
processing. This issue can be addressed by processing buffered stripes and reassemble 
them into the final map. The buffers must be large enough to maintain the neighborhood 
information at the intersection of neighboring stripes. Buffers are added on both sides 
of the stripes, except for the top stripe and the bottom stripe. The buffer is added to 
the top stripe at the bottom only, and is added to the bottom stripe at the top only.

We use a new **empty** directory :code:`splitlump` for all intermediate processing steps. 
:code:`GWB_SPLITLUMP` will setup two bash-scripts in the empty directory :code:`splitlump`:

* :code:`splitter.sh`: this script cuts the single large map into buffered stripes 
  for GWB processing.
* :code:`lumper.sh`: this script reassembles the GWB-processed buffered stripes into 
  the final map.


Instructions
------------

Steps to be conducted upon completion of :code:`GWB_SPLITLUMP`:

1. Open the :code:`splitlump` directory and read through the comments of :code:`splitter.sh`. 
   Note that on a multi-user system you may not have full access to the amount of available RAM.
   
2. If the splitlump setup is appropriate, open a terminal in the :code:`splitlump` directory 
   and run the bash-script :code:`./splitter.sh` to cut the large input map into buffered stripes
   
3. Place the appropriate GWB_XXX parameter file into the :code:`splitlump` directory

4. Use :code:`GWB_XXX -i=<splitlump directory> -o =<your output directory>` to process all 
   buffered stripes with the GWB module of your choice
   
5. Delete the buffered stripes from step 2 and then move all resulting tif-maps 
   from step 4 into the :code:`splitlump` directory
   
6. Open a terminal in the :code:`splitlump` directory and run the bash-script 
   :code:`./lumper.sh` to cut and reassemble all processed buffered stripes (tif-maps) 
   into the final large processed map.


.. Tip::

    * If possible, **avoid** buffered striping by using a machine with sufficient RAM to 
      allow for direct GWB-processing.
    * If you must use striping, use as few stripes as possible with sufficiently 
      large buffers.
    * Compare the result of horizontal and vertical striping and increase buffers if the
      results from horizontal and vertical striping do not match.
    * Do **not** calculate statistics when GWB-processing of buffered stripes as 
      this is meaningless.
    * Use the option *dryrun* :code:`1` to quickly test the two scripts :code:`splitter.sh` 
      and :code:`lumper.sh` without doing the intermediate, potentially time-consuming
      GWB processing. *dryrun* :code:`1` will rename the output of :code:`splitter.sh` 
      to fake GWB-processed maps, which can then be reassembled via :code:`lumper.sh`. 
      The output of :code:`lumper.sh` should be identical to the original large input map.


Requirements
------------

A single band (Geo)TIFF image in data format byte and at least of size 12,000 x 12,000 
pixels in x and y direction.

Processing parameter options and further detailed instructions are stored in the 
file :code:`input/splitlump-parameters.txt`.

.. code-block:: text

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; GWB_SPLITLUMP parameter file:
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; Please amend only the options at the end of this file and between the lines in *****
    ;; This module is only needed when trying to process very large maps for either:
    ;; GWB_FRAG/_GSC/_LM/_SPATCON      OR      GWB_ACC/_DIST/_MSPA/_PARC/_RSS/_SPA
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
    ;;        (GWB_ACC: 30 * imsizeGB, GWB_(M)SPA: 20 * imsizeGB)
    ;;     2) if you must use striping, use as few stripes as possible with sufficiently large buffers
    ;;     3) compare the result of horizontal and vertical striping and increase buffers if they do not match
    ;;
    ;; We use a new *empty* directory "splitlump" for all intermediate processing steps.
    ;; GWB_SPLITLUMP will setup two bash-scripts in the empty directory  "splitlump":
    ;; - "splitter.sh" to cut the single large map into buffered stripes for GWB processing,
    ;; - "lumper.sh" to be used for reassembling the processed buffered stripes.
    ;;
    ;; Steps to be conducted upon completion of GWB_SPLITLUMP:
    ;; 1) open the "splitlump" directory and read through the comments of "splitter.sh"
    ;;    Note that on a multi-user system you may not have full access to the amount of available RAM.
    ;; 2) if the splitlump setup is appropriate, open a terminal in the  "splitlump" directory and
    ;;    run the bash-script "./splitter.sh" to cut the large input map into buffered stripes
    ;; 3) place the appropriate GWB_XXX parameterfile into the "splitlump" directory
    ;; 4) use GWB_XXX -i=<splitlump directory> -o=<your output directory>
    ;;    to process all buffered stripes with the GWB module of your choice
    ;; 5) move all resulting tif-maps from step 4) into the "splitlump" directory
    ;; 6) open a terminal in the  "splitlump" directory and run the bash-script "./lumper.sh"
    ;;    to cut and reassemble all processed buffered stripes (tif-maps) into the final large processed map.
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
    ~/input/backup/Mekong.tif
    3
    1200
    horizontal
    1
    ****************************************************************************


Example
-------

1. Place a large map (here *Mekong.tif*) into the directory :code:`$HOME/input/backup/`
2. Ensure the directory :code:`$HOME/input/splitlump` is empty
3. Amend the parameter file :code:`$HOME/input/splitlump-parameters.txt` to meet your needs
   (in this example we set to cut 3 horizontal buffered stripes with a buffer of 1200 pixels)
4. To setup the two scripts :code:`splitter.sh` and :code:`lumper.sh`, open a terminal 
   and run:
  
   .. code-block:: console
  
     $ GWB_SPLITLUMP -i=$HOME/input/splitlump-parameters.txt
    
     IDL 9.0.0 (linux x86_64 m64).
     (c) 2023, NV5 Geospatial Solutions, Inc.
    
     parameter file: $HOME/input/splitlump-parameters.txt
     % Loaded DLM: TIFF.
    
     Next, please follow the instructions at the end of: ~/input/splitlump/splitter.sh
    
     $ ls $HOME/input/splitlump/
     lumper.sh*   splitter.sh*

  
5. **Cut:** to cut the large input map into buffered stripes, open a terminal, cd into the 
   :code:`splitlump` directory and run:
  
   .. code-block:: console
  
     $ cd $HOME/input/splitlump
     $ ./splitter.sh
    
     Input file size is 19907, 24966
     0...10...20...30...40...50...60...70...80...90...100 - done.
     Input file size is 19907, 24966
     0...10...20...30...40...50...60...70...80...90...100 - done.
     Input file size is 19907, 24966
     0...10...20...30...40...50...60...70...80...90...100 - done.
     The script './splitter.sh' has finished.
    
     $ ls
     hstripe1.tif  hstripe2.tif  hstripe3.tif  lumper.sh*  splitter.sh*
     
   The bash-script :code:`splitter.sh` has now cut the large input map *Mekong.tif* into 3
   horizontal buffered stripes with an overlapping buffer of 1200 pixels at the 
   intersection of neighbouring stripes, more details in :code:`splitter.sh`.
   

  
6. Prepare for GWB-processing: for example for fragmentation, amend the fragmentation parameter file
   as needed and then copy it into the directory :code:`$HOME/input/splitlump`:

   .. code-block:: console
  
     $ cp $HOME/input/frag-parameters.txt $HOME/input/splitlump/
     $ ls
     frag-parameters.txt hstripe1.tif  hstripe2.tif  hstripe3.tif  lumper.sh*  splitter.sh*
    
    
7. **GWB-processing:** ensure :code:`$HOME/output` is empty, then run the GWB analysis for all buffered stripes: 

   .. code-block:: console
  
     $ GWB_FRAG -i=$HOME/input/splitlump -o=$HOME/output
    
     IDL 8.8.3 (linux x86_64 m64).
     (c) 2022, L3Harris Geospatial Solutions, Inc.
    
     GWB_FRAG using:
     dir_input= $HOME/input/splitlump
     dir_output= $HOME/output
     % Loaded DLM: TIFF.
     Done with: hstripe1.tif
     Done with: hstripe2.tif
     Done with: hstripe3.tif
     Frag finished sucessfully
    
     $ ls $HOME/output
     ls -R $HOME/output
     $HOME/output:
     frag.log  hstripe1_frag/  hstripe2_frag/  hstripe3_frag/
    
     $HOME/output/hstripe1_frag:
     hstripe1_fos-fac_5class_27.tif
    
     $HOME/output/hstripe2_frag:
     hstripe2_fos-fac_5class_27.tif
    
     $HOME/output/hstripe3_frag:
     hstripe3_fos-fac_5class_27.tif
          
    
8. Prepare for merging: **delete the no longer needed initial buffered stripes,** which 
   is necessary to make step 9 work. After this, move all GWB-processed maps into the 
   directory :code:`$HOME/input/splitlump`:
  
   .. code-block:: console
    
     $ cd $HOME/input/splitlump
     $ rm -f *stripe*.tif
     $ cp $HOME/output/*stripe*/*.tif $HOME/input/splitlump/
     $ ls
     frag-parameters.txt             hstripe2_fos-fac_5class_27.tif  lumper.sh*
     hstripe1_fos-fac_5class_27.tif  hstripe3_fos-fac_5class_27.tif  splitter.sh*

       
9. **Merge:** reassemble the GWB-processed striped maps in the directory :code:`splitlump`:
  
   .. code-block:: console
    
     $ cd $HOME/input/splitlump
     $ ./lumper.sh
     Input file size is 19907, 9522
     0...10...20...30...40...50...60...70...80...90...100 - done.
     Input file size is 19907, 10722
     0...10...20...30...40...50...60...70...80...90...100 - done.
     Input file size is 19907, 9522
     0...10...20...30...40...50...60...70...80...90...100 - done.
     0...10...20...30...40...50...60...70...80...90...100 - done.
     Input file size is 19907, 24966
     0...10...20...30...40...50...60...70...80...90...100 - done.
     The script lumper.sh has finished, please verify your output file:
     Mekong_fos-fac_5class_27.tif
     
     $ ls
     frag-parameters.txt  hstripe3_fos-fac_5class_27.tif  lumper3.tif  splitter.sh*
     hstripe1_fos-fac_5class_27.tif   lumper1.tif   lumper.sh*   tmp.vrt
     hstripe2_fos-fac_5class_27.tif   lumper2.tif   Mekong_fos-fac_5class_27.tif


   The bash-script :code:`lumper.sh` has now cut the common buffers of the 3 buffered 
   stripes and then merged the 3 unbuffered stripes into the final map, applied 
   LZW-compression and renamed the final processed large map 
   (here, *Mekong_fos-fac_5class_27.tif*) using the basename of the 
   original input name (here *Mekong.tif*) and the GWB module specific extension 
   (here, *_fos-fac_5class_27*), more details in :code:`lumper.sh`.  
     
     
10. Move the result to a final location and empty the directory :code:`$HOME/input/splitlump`.
    Verify the result via the command :code:`gdalinfo -noct Mekong_fos-fac_5class_27.tif` 
    or load it into your favoured GIS application.
    

