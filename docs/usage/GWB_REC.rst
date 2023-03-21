Recoding (GWB_REC)
==================

This module conducts **Recoding** of categorical class values.


Requirements
------------

A single band (Geo)TIFF image in data format byte.

Processing parameter options are stored in the file :code:`input/rec-parameters.txt`.

.. code-block:: text

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; GTB_REC parameter file:
    ;; NOTE: change values only at the end of the file between the lines in *****
    ;;
    ;; REC: Recode image classes
    ;; Input image requirements: classes within the range [0, 255] byte
    ;; Output: the same image coverage but with recoded class values
    ;;
    ;; Please specify recoding values with two entries per line.
    ;; GWB_REC will error/exit if not in correct range.
    ;; Class values not found in the image will be skipped.
    ;; Class values not in the list will not be re-coded.
    ;; If an old value appears on more than one line, the last one listed is used.
    ;;
    ;; Recoding rule:
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; The first value is the original value and the second is the new recoded value:
    ;; original value within [0, 255] byte     new recoded value within [0, 255] byte
    ;; i.e., to recode class 1 to 12 and class 2 to 22 , enter one line each, like:
    ;; 1 12
    ;; 2 22
    ****************************************************************************
    1 120
    2 220
    ****************************************************************************


Example
-------

The results are stored in the directory :code:`output`, one directory for each input 
image accompanied by a log-file providing details on computation time and processing 
success of each input image.

:code:`GWB_REC` command and listing of results in the directory output:

.. code-block:: console

    $ GWB_REC -i=$HOME/input -o=$HOME/output
    IDL 8.8.3 (linux x86_64 m64).
    (c) 2022, Harris Geospatial Solutions, Inc.

    GWB_REC using:
    dir_input= $HOME/input
    dir_output= $HOME/output
    % Loaded DLM: TIFF.
    Done with: clc3class.tif
    Done with: example.tif
    Recode finished sucessfully

    $ ls -R output/
    output/:
    clc3class_rec  example_rec  rec.log

    output/clc3class_rec:
    clc3class_rec.tif

    output/example_rec:
    example_rec.tif

Remarks
-------

-   The recoded images have the suffix _rec.tif to distinguish them from the original images.
-   To verify the recoding run the command:

    .. code-block:: console

        $ gdalinfo -hist <path2image>

Recoding may be useful to quickly setup a forest mask from a land cover map by 
reassigning specific land cover classes to forest. Please note that most GWB
modules require a (pseudo) binary input mask of data type Byte with the assignment:

-   0 byte: missing data (optional)
-   1 byte: Background
-   2 byte: Foreground (i.e., forest)

