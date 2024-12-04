GraySpatCon (GWB_GSC)
=====================

This module provides full access to the spatial convolution program 
**GraySpatCon**. **GraySpatCon** is an extended version of **SpatCon**, with the 
additional feature of permitting analysing grayscale density maps and conducting a global 
map analysis. **GraySpatCon** offers 52 spatial convolution metrics, which are summarised 
in the 
`GRAYSPATCON_Guide <https://github.com/ec-jrc/GWB/blob/main/tools/external_sources/GRAYSPATCON_Guide.pdf>`_.
**GraySpatCon** conducts a moving window, or focal analysis and results in a spatially 
explicit map for the selected metric. 

Requirement
-----------

A single band (Geo)TIFF image in data format byte. Metric-specific requirements and 
processing options are stored in the file :code:`input/gsc-parameters.txt`.

.. code-block:: text

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; GWB_GSC parameter file:
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; Please amend only the options at the end of this file and between the lines in *****
    ;; GraySpatCon (GSC) metrics:
    ;;  1 = Mean
    ;;  2 = EvennessOrderedAdj
    ;;  3 = EvennessUnorderedAdj
    ;;  4 = EntropyOrderedAdj
    ;;  5 = EntropyUnorderedAdj
    ;;  6 = DiagonalContagion
    ;;  7 = ShannonDiversity
    ;;  8 = ShannonEvenness
    ;;  9 = Median
    ;; 10 = GSDiversity
    ;; 11 = GSEvenness
    ;; 12 = EquitabilityOrderedAdj
    ;; 13 = EquitabilityUnorderedAdj
    ;; 14 = DiversityOrderedAdj
    ;; 15 = DiversityUnorderedAdj
    ;; 16 = Majority
    ;; 17 = LandscapeMosaic19
    ;; 18 = LandscapeMosaic103
    ;; 19 = NumberGrayLevels
    ;; 20 = MaxAreaDensity
    ;; 21 = FocalAreaDensity
    ;; 22 = FocalAdjT1
    ;; 23 = FocalAdjT1andT2
    ;; 24 = FocalAdjT1givenT2
    ;; 25 = StandardDeviation
    ;; 26 = CoefficientVariation
    ;; 27 = Range
    ;; 28 = Dissimilarity
    ;; 29 = Contrast
    ;; 30 = UniformityOrderedAdj
    ;; 31 = UniformityUnorderedAdj
    ;; 32 = Homogeneity
    ;; 33 = InverseDifference
    ;; 34 = SimilarityRMax
    ;; 35 = SimilarityRGlobal
    ;; 36 = SimilarityRWindow
    ;; 37 = DominanceOrderedAdj
    ;; 38 = DominanceUnorderedAdj
    ;; 39 = DifferenceEntropy
    ;; 40 = DifferenceEvenness
    ;; 41 = SumEntropy
    ;; 42 = SumEvenness
    ;; 43 = AutoCorrelation
    ;; 44 = Correlation
    ;; 45 = ClusterShade
    ;; 46 = ClusterProminence
    ;; 47 = RootMeanSquare
    ;; 48 = AverageAbsDeviation
    ;; 49 = kContagion
    ;; 50 = Skewness
    ;; 51 = Kurtosis
    ;; 52 = Clustering
    ;;
    ;; for more details on GraySpatCon, see the Guide and/or the source code at:
    ;; https://github.com/ec-jrc/GWB/tree/main/tools/external_sources/
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; GraySpatCon parameters for all metrics (some metrics use only a subset of all parameters)
    ;; Automatically set by GWB_GSC, do not specify:
    ;;    R x  - number of rows in input map, x is positive integer
    ;;    C x  - number of columns in input map, x is positive integer
    ;; Required:
    ;;    M x  - metric selection: see list above
    ;;    F x  - output map precision: 1 = 8-bit byte, 2 = 32-bit float. F must =2 for metrics 44, 45, 50.
    ;;    G x  - analysis type: 0 = moving window analysis; 1 = global (entire map extent) analysis
    ;; Optional:
    ;;    P x  - exclude input pixels with value zero (0 = no, 1 = yes)
    ;; Required if G = 0:
    ;;    W x  - window size; the number of pixels on the side of a x*x window (eg x=5 for 5x5 window)
    ;;               Must be odd, positive integer > 1 (eg, 3,5,7,9...), maximum < x or y dimension of input map
    ;; Optional if G = 0:
    ;;    A x  - mask missing: 0 - do not mask input missing on output, or
    ;;             1 - set missing input pixels to missing output pixels
    ;; Required if F = 1:
    ;;    B x  - byte stretch if converting to bytes.
    ;;              For metrics bounded in [0.0, 1.0] only: (metrics 2, 3, 6, 8, 10-15, 20-24, 31-38, 40, 42, 49)
    ;;                  1.  From metric value in [0.0, 1.0] to byte in [0, 100]
    ;;                  2.  From metric value in [0.0, 1.0] to byte in [0, 254]
    ;;              For all metrics except 1, 9, 16, 17, 18, 19, 25, 27:
    ;;                  3.  From metric value in [Min, Max] to byte in [0, 254]
    ;;                  4.  From metric value in [0.0, Max] to byte in [0, 254]
    ;;                  5.  From metric value in [0.0, Max] to byte in [0, 100]
    ;;                  Where Min and Max are the observed minimum and observed maximum values
    ;;                  over the entire output image
    ;;              For metrics 1, 9, 16, 17, 18, 19, 25, 27 only:
    ;;                  6.  No stretch allowed; the metric value is converted to byte
    ;; Required for metrics 21, 22, 23, 24:
    ;;    X x  - target code 1 (t1) (x  in [0,100]).
    ;; Required for metrics 23, 24:
    ;;    Y x  - target code 2 (t2) (x  in [0,100]).
    ;; Required for metric 49:
    ;;    K x - target difference level (k*) (x in [0, 100]).
    ;;
    ;; NOTE: parameters can appear in any order. Parameters not used in a given run are ignored.
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; Output file (written in the current directory):
    ;; For G = 0 (image output):
    ;;     Output file name = gscoutput
    ;;     Missing value = -0.01 (32-bit float file) or 255 (8-bit byte file).
    ;;     Exception: for metrics 44, 45, 50 the missing value = -99999999999.0
    ;; For G =1 (text output):
    ;;     Output file name = gscoutput.txt
    ;;     Missing value = -0.01
    ;;     Exception: for metrics 44, 45, 50 the missing value = -99999999999.0
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; Example parameter file for running GraySpatCon metric Majority and using a 27x27 window:
    ;; M 16
    ;; F 1
    ;; G 0
    ;; P 0
    ;; W 27
    ;; A 1
    ;; B 1
    ;; X 88
    ;; Y 87
    ;; K 5
    ****************************************************************************
    M 20
    F 1
    G 0
    P 0
    W 7
    A 1
    B 2
    X 88
    Y 87
    K 5
    ****************************************************************************


Example
-------

The results are stored in the directory :code:`output`, an image and a txt-file for each 
input image accompanied by a log-file providing details on computation time and 
processing success of each input image.

:code:`GWB_GSC` command and listing of results in the directory output:

.. code-block:: console

    $ GWB_GSC -i=$HOME/input -o=$HOME/output
    IDL 9.1.0 (linux x86_64 m64).
    (c) 2024, NV5 Geospatial Solutions, Inc.

    GWB_GSC using:
    dir_input= $HOME/input
    dir_output= $HOME/output
    % Loaded DLM: TIFF.
    % Loaded DLM: LAPACK.
    % Loaded DLM: PNG.
    Done with: clc3class.tif
    Done with: example.tif
    Done with: gscinput.tif
    GSC finished sucessfully

    $ ls -R output/
    output/:
    clc3class_gsc20.tif  clc3class_gsc20.txt 
    example_gsc20.tif    example_gsc20.txt    GraySpatCon.log 

Example spatial result of a GSC MaxAreaDensity (metric 20) analysis of the input 
image :code:`example.tif`:

.. image:: ../_image/example_gsc20.tif
    :width: 100%


Remarks
-------

-   The metric-dependent settings are echoed 
    in the log-file and automatically verified before execution.
-   Potential erroneous settings are reported in the log-file. 
-   All density or adjacency metrics are scale-dependent (specified by the size of the 
    moving window).
    
    


