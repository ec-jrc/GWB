PRO GWB_GSC
;;==============================================================================
;; GWB APP interface to GraySpatCon 
;;==============================================================================
;; 
;; Purpose: 
;;==============================================================================
;; IDL cmd-line app to run native GraySpatCon
;; more info at: https://docs.sepal.io/en/latest/cli/gwb.html
;;
;; Requirements: no external requirements
;;
;; AUTHOR:
;;       Peter Vogt
;;       D.1, T.P. 261
;;       European Commission, JRC
;;       Via E. Fermi, 2749
;;       21027 Ispra, ITALY
;;       E-mail: Peter.Vogt@ec.europa.eu

;;==============================================================================
GWB_mv = 'GWB_GSC (version 1.9.2)'
;;
;; Module changelog:
;; 1.9.2: IDL 8.9.0, added metric 52 Clustering
;; 1.9.1: initial release       
;;
;;==============================================================================
;; Input: at least 2 files in the subfolder "input"
;;==============================================================================
;; a) input image(s) (geotiff):
;; at least 1 or more geotiff images in the subfolder "input"
;; the input image must be of data type byte and the appropriate assignment
;; to be evaluated by the selected GraySpatCon metric 
;;
;; b) gsc-parameters.txt: (see header info in input/gsc-parameters.txt)
;;  - GraySpatCon metric
;;  - moving window size [pixels]
;;  - switch for high precision (on/off)
;;
;;==============================================================================
;; Output: in the subfolder "output"
;;==============================================================================
;; native GraySpatCon output
;; 
;; Processing steps:
;; 1) verify parameter file and compatibility of input image
;; 2) run GraySpatCon metric
;; 3) post-process: write-out map or statistics
;;
;;==============================================================================
;;==============================================================================
device, decomposed = 0
;; initial system checks
cd, current = dir_gwb

;;==============================================================================
;; 0) get path to directories or use default
;;==============================================================================
spawn,'echo $USER',res & res = res[0]
fn_dirs = '/home/' + res + '/.gwb/gwb_dirs.txt'
tt = strarr(2) & close,1 & standalone = 1

;; default directories within application
pushd, '..' & cd, current = dir_inputdef & popd
dir_input = '../input'
dir_output = '../output'

res = file_info(fn_dirs)
IF res.exists EQ 1b THEN BEGIN
  ;; read user-specified directories
  openr, 1, fn_dirs & readf,1,tt & close,1
  dir_input = tt[0] & dir_output = tt[1]
  standalone = 0
ENDIF

;; echo selected directories
print,'GWB_GSC using:'
if standalone eq 1 then dir_input = dir_inputdef + "/input"
if standalone eq 1 then dir_output = dir_inputdef + "/output"
print, 'dir_input= ', dir_input 
print, 'dir_output= ', dir_output

;; verify to have tif image(s) (should be a geotiff)
pushd, dir_input & list = file_search('*.tif', count=ct_tifs) & popd
IF ct_tifs EQ 0 THEN BEGIN
  print, "The input directory does not contain an image with the extension '.tif'"
  print, 'Please copy your geotiff image here.'
  print, "Exiting..."
  goto,fin
ENDIF
mod_params = dir_input + '/gsc-parameters.txt'
IF (file_info(mod_params)).exists EQ 0b THEN BEGIN
  print, "The file: " + mod_params + "  was not found."
  print, "Please copy the respective backup file into your input directory:"
  print, dir_inputdef + "/input/backup/*parameters.txt"
  print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
ENDIF

;;==============================================================================
;;  verify GSC parameter file
;;==============================================================================
;; read GraySpatCon settings, we need at very least 3 valid lines
fl = file_lines(mod_params)
IF fl LT 3 THEN BEGIN
  print, "The file: " + mod_params + " is in a wrong format."
  print, "Please copy the respective backup file into your input directory:"
  print, dir_inputdef + "/input/backup/*parameters.txt"
  print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
ENDIF
;; check for input parameters
finp = strarr(fl) & close,1
openr, 1, mod_params & readf, 1, finp & close, 1
;; filter out lines starting with ; or * or empty lines
q = where(strmid(finp,0,1) eq ';', ct) & IF ct GT 0 THEN finp[q] = ' '
q = where(strmid(finp,0,1) eq '*', ct) & IF ct GT 0 THEN finp[q] = ' '
q = where(strlen(strtrim(finp,2)) GT 0, ct)
IF ct LT 3 THEN BEGIN
  print, "The file: " + mod_params + " is in a wrong format."
  print, "Please copy the respective backup file into your input directory:"
  print, dir_inputdef + "/input/backup/*parameters.txt"
  print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
ENDIF
;; get and check parameters
finp = strtrim(finp[q],2)
;; NOTE: parameter 'r' and 'c' are rows/columns of the image, which we will assign automatically
;; ['m ', 'f ', 'g ', 'p ', 'w ', 'a ', 'b ', 'x ', 'y ', 'k '] ;; GraySpatCon parameters to check for
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 1) M: get the GraySpatCon metric
;; valid entries: [1, 52]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
q = where(strlowcase(strmid(finp,0,2)) eq 'm ') & q = q[0]
if q lt 0 then begin
  print, "The file: " + mod_params + " is in a wrong format."
  print, "no line with valid GraySpatCon parameter 'M <GraySpatCon metric>' found."
  print, "Please copy the respective backup file into your input directory:"
  print, dir_inputdef + "/input/backup/*parameters.txt"
  print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin  
endif
gsc_m = (strsplit(finp(q),' ',/extract))[1]
;; gsc_m_str: header info in log-file
;; px: filename abbreviation string, px2 in log-file
px = 'metric' + gsc_m & px2 = 'GSC-metric ' + gsc_m
case gsc_m of 
  '1': BEGIN
    gsc_m_str = 'GSC-metric 1: Mean'
  END
  '2': BEGIN
    gsc_m_str = 'GSC-metric 2: EvennessOrderedAdj'
  END
  '3': BEGIN
    gsc_m_str = 'GSC-metric 3: EvennessUnorderedAdj'
  END
  '4': BEGIN
    gsc_m_str = 'GSC-metric 4: EntropyOrderedAdj'
  END
  '5': BEGIN
    gsc_m_str = 'GSC-metric 5: EntropyUnorderedAdj'
  END
  '6': BEGIN
    gsc_m_str = 'GSC-metric 6: DiagonalContagion'
  END
  '7': BEGIN
    gsc_m_str = 'GSC-metric 7: ShannonDiversity'
  END
  '8': BEGIN
    gsc_m_str = 'GSC-metric 8: ShannonEvenness'
  END
  '9': BEGIN
    gsc_m_str = 'GSC-metric 9: Median'
  END  
  '10': BEGIN
    gsc_m_str = 'GSC-metric 10: GSDiversity'
  END
  '11': BEGIN
    gsc_m_str = 'GSC-metric 11: GSEvenness'
  END
  '12': BEGIN
    gsc_m_str = 'GSC-metric 12: EquitabilityOrderedAdj'
  END
  '13': BEGIN
    gsc_m_str = 'GSC-metric 13: EquitabilityUnorderedAdj'
  END
  '14': BEGIN
    gsc_m_str = 'GSC-metric 14: DiversityOrderedAdj'
  END
  '15': BEGIN
    gsc_m_str = 'GSC-metric 15: DiversityUnorderedAdj'
  END
  '16': BEGIN
    gsc_m_str = 'GSC-metric 16: Majority'
  END
  '17': BEGIN
    gsc_m_str = 'GSC-metric 17: LandscapeMosaic19'
  END
  '18': BEGIN
    gsc_m_str = 'GSC-metric 18: LandscapeMosaic103'
  END
  '19': BEGIN
    gsc_m_str = 'GSC-metric 19: NumberGrayLevels'
  END
  '20': BEGIN
    gsc_m_str = 'GSC-metric 20: MaxAreaDensity'
  END
  '21': BEGIN
    gsc_m_str = 'GSC-metric 21: FocalAreaDensity'
  END
  '22': BEGIN
    gsc_m_str = 'GSC-metric 22: FocalAdjT1'
  END
  '23': BEGIN
    gsc_m_str = 'GSC-metric 23: FocalAdjT1andT2'
  END
  '24': BEGIN
    gsc_m_str = 'GSC-metric 24: FocalAdjT1givenT2'
  END
  '25': BEGIN
    gsc_m_str = 'GSC-metric 25: StandardDeviation'
  END
  '26': BEGIN
    gsc_m_str = 'GSC-metric 26: CoefficientVariation'
  END
  '27': BEGIN
    gsc_m_str = 'GSC-metric 27: Range'
  END
  '28': BEGIN
    gsc_m_str = 'GSC-metric 28: Dissimilarity'
  END
  '29': BEGIN
    gsc_m_str = 'GSC-metric 29: Contrast'
  END
  '30': BEGIN
    gsc_m_str = 'GSC-metric 30: UniformityOrderedAdj'
  END
  '31': BEGIN
    gsc_m_str = 'GSC-metric 31: UniformityUnorderedAdj'
  END
  '32': BEGIN
    gsc_m_str = 'GSC-metric 32: Homogeneity'
  END
  '33': BEGIN
    gsc_m_str = 'GSC-metric 33: InverseDifference'
  END
  '34': BEGIN
    gsc_m_str = 'GSC-metric 34: SimilarityRMax'
  END
  '35': BEGIN
    gsc_m_str = 'GSC-metric 35: SimilarityRGlobal'
  END
  '36': BEGIN
    gsc_m_str = 'GSC-metric 36: SimilarityRWindow'
  END
  '37': BEGIN
    gsc_m_str = 'GSC-metric 37: DominanceOrderedAdj'
  END
  '38': BEGIN
    gsc_m_str = 'GSC-metric 38: DominanceUnorderedAdj'
  END
  '39': BEGIN
    gsc_m_str = 'GSC-metric 39: DifferenceEntropy'
  END
  '40': BEGIN
    gsc_m_str = 'GSC-metric 40: DifferenceEvenness'
  END
  '41': BEGIN
    gsc_m_str = 'GSC-metric 41: SumEntropy'
  END
  '42': BEGIN
    gsc_m_str = 'GSC-metric 42: SumEvenness'
  END
  '43': BEGIN
    gsc_m_str = 'GSC-metric 43: AutoCorrelation'
  END
  '44': BEGIN
    gsc_m_str = 'GSC-metric 44: Correlation'
  END
  '45': BEGIN
    gsc_m_str = 'GSC-metric 45: ClusterShade'
  END
  '46': BEGIN
    gsc_m_str = 'GSC-metric 46: ClusterProminence'
  END
  '47': BEGIN
    gsc_m_str = 'GSC-metric 47: RootMeanSquare'
  END
  '48': BEGIN
    gsc_m_str = 'GSC-metric 48: AverageAbsDeviation'
  END
  '49': BEGIN
    gsc_m_str = 'GSC-metric 49: kContagion'
  END
  '50': BEGIN
    gsc_m_str = 'GSC-metric 50: Skewness'
  END
  '51': BEGIN
    gsc_m_str = 'GSC-metric 51: Kurtosis'
  END
  '52': BEGIN
    gsc_m_str = 'GSC-metric 52: Clustering'
  END
  ELSE: BEGIN
    print, "The file: " + mod_params + " is in a wrong format."
    print, "M: GraySpatCon metric is not in [1, 52]."
    print, "Please copy the respective backup file into your input directory:"
    print, dir_inputdef + "/input/backup/*parameters.txt"
    print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
    print, "Exiting..."
    goto,fin
  END
ENDCASE


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 2) F: get map precision 
;; valid entries: 1 (byte) or 2 (float)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
q = where(strlowcase(strmid(finp,0,2)) eq 'f ') & q = q[0]
if q lt 0 then begin
  print, "The file: " + mod_params + " is in a wrong format."
  print, "no line with valid GraySpatCon parameter 'F <output map precision>' found."
  print, "Please copy the respective backup file into your input directory:"
  print, dir_inputdef + "/input/backup/*parameters.txt"
  print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
endif
gsc_f = (strsplit(finp(q),' ',/extract))[1]
condition = gsc_f EQ '1' or gsc_f EQ '2'
IF condition EQ 0b THEN BEGIN ;; invalid user entry
  print, "The file: " + mod_params + " is in a wrong format."
  print, "F: map precision switch is not 1 or 2."
  print, "Please copy the respective backup file into your input directory:"
  print, dir_inputdef + "/input/backup/*parameters.txt"
  print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
ENDIF
;; enforce float for M 44, 45, 50:
IF gsc_m EQ '44' OR gsc_m EQ '45' OR gsc_m EQ '50' THEN gsc_f = '2'


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  3) G: analysis type
;; valid entries: 0 = moving window analysis; 1 = global (entire map extent) analysis
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
q = where(strlowcase(strmid(finp,0,2)) eq 'g ') & q = q[0]
if q lt 0 then begin
  print, "The file: " + mod_params + " is in a wrong format."
  print, "no line with valid GraySpatCon parameter 'G <analysis type>' found."
  print, "Please copy the respective backup file into your input directory:"
  print, dir_inputdef + "/input/backup/*parameters.txt"
  print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
endif
gsc_g = (strsplit(finp(q),' ',/extract))[1]
condition = (gsc_g EQ '0') OR (gsc_g EQ '1')
IF condition EQ 0b THEN BEGIN ;; invalid user entry
  print, "The file: " + mod_params + " is in a wrong format."
  print, "G: analysis type is not 0 or 1."
  print, "Please copy the respective backup file into your input directory:"
  print, dir_inputdef + "/input/backup/*parameters.txt"
  print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
ENDIF


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  4) P: optional. exclude input pixels with value zero
;; valid entries: 0 = no (include them); 1 = yes
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
q = where(strlowcase(strmid(finp,0,2)) eq 'p ') & q = q[0]
if q lt 0 then begin ;; if not defined set to default of 0 meaning include them
  gsc_p = '0'
endif else begin
  gsc_p = (strsplit(finp(q),' ',/extract))[1]
  condition = (gsc_p EQ '0') OR (gsc_p EQ '1')
  IF condition EQ 0b THEN BEGIN ;; invalid user entry
    print, "The file: " + mod_params + " is in a wrong format."
    print, "P: exclude input pixels with value zero is not 0 or 1."
    print, "Please copy the respective backup file into your input directory:"
    print, dir_inputdef + "/input/backup/*parameters.txt"
    print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
    print, "Exiting..."
    goto,fin
  ENDIF
endelse


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 5) W: window size
;; valid entries: uneven in [3,5,7,...]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
gsc_w = 'global' ;; fake value to indicate global analysis when gsc_g eq 1
if gsc_g eq '0' then begin ;; required if moving window analysis is asked for
  q = where(strlowcase(strmid(finp,0,2)) eq 'w ') & q = q[0]
  if q lt 0 then begin
    print, "The file: " + mod_params + " is in a wrong format."
    print, "W: no line with valid GraySpatCon parameter 'W <window size number>' found."
    print, "Please copy the respective backup file into your input directory:"
    print, dir_inputdef + "/input/backup/*parameters.txt"
    print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
    print, "Exiting..."
    goto,fin
  endif
  gsc_w = (strsplit(finp(q),' ',/extract))[1]
  gsc_w_fix = fix(gsc_w) & gsc_w = strtrim(gsc_w_fix,2)
  ;; make sure window size is appropriate
  uneven = gsc_w_fix mod 2
  IF gsc_w_fix LT 3 OR uneven EQ 0 THEN BEGIN ;; invalid user entry
    print, "The file: " + mod_params + " is in a wrong format."
    print, "W: Moving window size is not an uneven number in [3, 5, 7, 9, 11, ... ]."
    print, "Please copy the respective backup file into your input directory:"
    print, dir_inputdef + "/input/backup/*parameters.txt"
    print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
    print, "Exiting..."
    goto,fin
  ENDIF
endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  6) A: optional. mask input missing on output
;; valid entries: 0 = no; 1 = yes
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
gsc_a = '1' ;; fake value
q = where(strlowcase(strmid(finp,0,2)) eq 'a ') & q = q[0]
if q lt 0 then begin ;; if not defined set to default
  gsc_a = '1'
endif else begin
  gsc_a = (strsplit(finp(q),' ',/extract))[1]
  condition = (gsc_a EQ '0') OR (gsc_a EQ '1')
  IF condition EQ 0b THEN BEGIN ;; invalid user entry
    print, "The file: " + mod_params + " is in a wrong format."
    print, "A: mask input missing on output is not 0 or 1."
    print, "Please copy the respective backup file into your input directory:"
    print, dir_inputdef + "/input/backup/*parameters.txt"
    print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
    print, "Exiting..."
    goto,fin
  ENDIF
endelse

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  7) B: required if F=1 - byte output
;; valid entries: [1, 2, 3, 4, 5, 6]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
gsc_b = '0' ;; fake value
IF gsc_f EQ '2' THEN GOTO, skip_b ;; no need to deal with float output

;; we have 3 conditions to deal with
;; 1) bounded metrics in [0, 1]: 2, 3, 6, 8, 10-15, 20-24, 31-38, 40, 42, 49
marr1 = strtrim([2,3,6,8,10,11,12,13,14,15,20,21,22,23,24,31,32,33,34,35,36,37,38,40,42,49,52],2)
;; 3) no-stretch metrics: 1, 9, 16, 17, 18, 19, 25, 27
marr3 = strtrim([1,9,16,17,18,19,25,27],2)
;; 2) unbounded metrics: those not in arr1 or arr3: 4, 5, 7, 26, 28-30, 39, 41, 43-48, 50, 51
marr2 = strtrim([4,5,7,26,28,29,30,39,41,43,44,45,46,47,48,50,51],2)

;; find out which condition we have
q = where(marr1 eq gsc_m, ct1)
q = where(marr2 eq gsc_m, ct2)
q = where(marr3 eq gsc_m, ct3)

if ct1 then begin
  ;; we need to read/check the parameter
  q = where(strlowcase(strmid(finp,0,2)) eq 'b ') & q = q[0]
  if q lt 0 then begin
    print, "The file: " + mod_params + " is in a wrong format."
    print, "B: no line with valid GraySpatCon parameter 'B <byte stretch code>' found."
    print, "Please copy the respective backup file into your input directory:"
    print, dir_inputdef + "/input/backup/*parameters.txt"
    print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
    print, "Exiting..."
    goto,fin
  endif
  gsc_b = (strsplit(finp(q),' ',/extract))[1]
  condition = (gsc_b EQ '1') OR (gsc_b EQ '2')
  IF condition EQ 0b THEN BEGIN ;; invalid user entry
    print, "The file: " + mod_params + " is in a wrong format."
    print, "B: <byte stretch code> is not 1 or 2."
    print, "Please copy the respective backup file into your input directory:"
    print, dir_inputdef + "/input/backup/*parameters.txt"
    print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
    print, "Exiting..."
    goto,fin
  ENDIF
  goto, skip_b
endif

if ct2 then begin
  ;; we need to read/check the parameter
  q = where(strlowcase(strmid(finp,0,2)) eq 'b ') & q = q[0]
  if q lt 0 then begin
    print, "The file: " + mod_params + " is in a wrong format."
    print, "B: no line with valid GraySpatCon parameter 'B <byte stretch code>' found."
    print, "Please copy the respective backup file into your input directory:"
    print, dir_inputdef + "/input/backup/*parameters.txt"
    print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
    print, "Exiting..."
    goto,fin
  endif
  gsc_b = (strsplit(finp(q),' ',/extract))[1]
  condition = (gsc_b EQ '3') OR (gsc_b EQ '4') OR (gsc_b EQ '5')
  IF condition EQ 0b THEN BEGIN ;; invalid user entry
    print, "The file: " + mod_params + " is in a wrong format."
    print, "B: <byte stretch code> is not 3, 4, or 5."
    print, "Please copy the respective backup file into your input directory:"
    print, dir_inputdef + "/input/backup/*parameters.txt"
    print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
    print, "Exiting..."
    goto,fin
  ENDIF
  goto, skip_b
endif

;; enforce B 6 for no-stretch metrics: 1, 9, 16, 17, 18, 19, 25, 27
if ct3 then begin
  ;; no need to read/check the parameter
  gsc_b = '6'
endif
skip_b:


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 8) X: get target code 1, required for metrics 21, 22, 23, 24
;; valid entries in [0, 100]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
gsc_x = '0' ;; fake value,
q = fix(gsc_m) & condition = q gt 20 and q lt 25
if condition then begin
  q = where(strlowcase(strmid(finp,0,2)) eq 'x ') & q = q[0]
  if q lt 0 then begin
    print, "The file: " + mod_params + " is in a wrong format."
    print, "X: no line with valid GraySpatCon parameter 'X <target code 1>' found."
    print, "Please copy the respective backup file into your input directory:"
    print, dir_inputdef + "/input/backup/*parameters.txt"
    print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
    print, "Exiting..."
    goto,fin
  endif
  gsc_x = (strsplit(finp(q),' ',/extract))[1]
  gsc_x0 = gsc_x & gsc_x_fix = fix(gsc_x) & gsc_x = strtrim(gsc_x_fix,2)
  condition = (gsc_x_fix GE 0) AND (gsc_x_fix LE 100) AND (gsc_x EQ gsc_x0)
  IF condition EQ 0b THEN BEGIN ;; invalid user entry
    print, "The file: " + mod_params + " is in a wrong format."
    print, "X: target code 1 is not in [0, 100]."
    print, "Please copy the respective backup file into your input directory:"
    print, dir_inputdef + "/input/backup/*parameters.txt"
    print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
    print, "Exiting..."
    goto,fin
  ENDIF  
endif


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 9) Y: get target code 2, required for metrics 23, 24
;; valid entries in [0, 100]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
gsc_y = '0' ;; fake value,
q = fix(gsc_m) & condition = q eq 23 or q eq 24
if condition then begin
  q = where(strlowcase(strmid(finp,0,2)) eq 'y ') & q = q[0]
  if q lt 0 then begin
    print, "The file: " + mod_params + " is in a wrong format."
    print, "Y: no line with valid GraySpatCon parameter 'Y <target code 2>' found."
    print, "Please copy the respective backup file into your input directory:"
    print, dir_inputdef + "/input/backup/*parameters.txt"
    print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
    print, "Exiting..."
    goto,fin
  endif
  gsc_y = (strsplit(finp(q),' ',/extract))[1]
  gsc_y0 = gsc_y & gsc_y_fix = fix(gsc_y) & gsc_y = strtrim(gsc_y_fix,2)
  condition = (gsc_y_fix GE 0) AND (gsc_y_fix LE 100) AND (gsc_y EQ gsc_y0)
  IF condition EQ 0b THEN BEGIN ;; invalid user entry
    print, "The file: " + mod_params + " is in a wrong format."
    print, "Y: target code 2 is not in [0, 100]."
    print, "Please copy the respective backup file into your input directory:"
    print, dir_inputdef + "/input/backup/*parameters.txt"
    print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
    print, "Exiting..."
    goto,fin
  ENDIF
endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 10) k: get target difference level, required for metric 49
;; valid entries in [0, 100]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
gsc_k = '0' ;; fake value,
q = fix(gsc_m) & condition = q eq 49
if condition then begin
  q = where(strlowcase(strmid(finp,0,2)) eq 'k ') & q = q[0]
  if q lt 0 then begin
    print, "The file: " + mod_params + " is in a wrong format."
    print, "K: no line with valid GraySpatCon parameter 'K <target difference level>' found."
    print, "Please copy the respective backup file into your input directory:"
    print, dir_inputdef + "/input/backup/*parameters.txt"
    print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
    print, "Exiting..."
    goto,fin
  endif
  gsc_k = (strsplit(finp(q),' ',/extract))[1]
  gsc_k0 = gsc_k & gsc_k_fix = fix(gsc_k) & gsc_k = strtrim(gsc_k_fix,2)
  condition = (gsc_k_fix GE 0) AND (gsc_k_fix LE 100) AND (gsc_k EQ gsc_k0)
  IF condition EQ 0b THEN BEGIN ;; invalid user entry
    print, "The file: " + mod_params + " is in a wrong format."
    print, "K: target difference level is not in [0, 100]."
    print, "Please copy the respective backup file into your input directory:"
    print, dir_inputdef + "/input/backup/*parameters.txt"
    print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
    print, "Exiting..."
    goto,fin
  ENDIF
endif

dir_proc = dir_output + '/.proc'
;; cleanup temporary proc directory
file_delete, dir_proc, /recursive, /quiet, /allow_nonexistent
file_mkdir, dir_proc

;;==============================================================================
;;==============================================================================
;; apply GraySpatCon settings in a loop over all tif images 
;;==============================================================================
;;==============================================================================
desc = 'GTB_GSC, https://forest.jrc.ec.europa.eu/activities/lpa/gtb/'
tagsw = 'TIFFTAG_SOFTWARE='+'"'+"GWB, https://forest.jrc.ec.europa.eu/en/activities/lpa/gwb/" +'" '
gedit = 'unset LD_LIBRARY_PATH; gdal_edit.py -mo ' + tagsw 
gedit = gedit + '-mo TIFFTAG_IMAGEDESCRIPTION="'+desc + '" '
;; add nodata info
gednodata = '-a_nodata 255 ' ;; for byte output
IF gsc_f EQ '2' THEN BEGIN
  gednodata = '-a_nodata -0.01 '
  IF gsc_m eq '44' OR gsc_m eq '45' OR gsc_m eq '50' THEN gednodata = '-a_nodata -9000000 '
ENDIF
gedit = gedit + gednodata

fn_logfile = dir_output + '/GraySpatCon.log' 
nr_im_files = ct_tifs & time00 = systime( / sec) & okfile = 0l
nocheck = file_info(dir_input + '/nocheck.txt') & nocheck = nocheck.exists
;; set precision description in log-file
IF gsc_f EQ '2' THEN prec = ', (float-prec) ' ELSE prec = ', (byte-prec)'

openw, 9, fn_logfile
if nocheck eq 0 then printf,9,GWB_mv else printf,9, GWB_mv + ' - nocheck'
printf, 9, 'logfile: ', systime()
printf, 9, gsc_m_str + ' batch processing'
IF gsc_g EQ '0' THEN printf, 9, 'Window size: ' + gsc_w + 'x' + gsc_w + prec
printf, 9, 'Number of files to be processed: ', nr_im_files
printf, 9, '==============================================='
close, 9
;; write out the path to the logfile to append RAM usage later on
fn_dirs2 = strmid(fn_dirs,0,strlen(fn_dirs)-12) + 'gwb_gsc_log.txt'
close, 1 & openw, 1, fn_dirs2 & printf, 1, fn_logfile & close, 1


FOR fidx = 0, nr_im_files - 1 DO BEGIN
  counter = strtrim(fidx + 1, 2) + '/' + strtrim(nr_im_files, 2)  
  input = dir_input + '/' + list[fidx] 
  res = query_tiff(input, inpinfo)
  inpsize = float(inpinfo.dimensions[0]) * inpinfo.dimensions[1]/1024/1024 ;; size in MB
  imsizeGB = inpsize/1024.0
  ;; current free RAM exclusive swap space
  spawn,"free|awk 'FNR == 2 {print $7}'", mbavail & mbavail = float(mbavail[0])/1024.0 ;; available
  GBavail = mbavail/1024.0
  
  openw, 9, fn_logfile, /append
  printf, 9, ' '
  printf, 9, '==============   ' + counter + '   =============='
  printf, 9, 'File: ' + input
  printf, 9, 'uncompressed image size [GB]: ' + strtrim(imsizeGB,2)
  printf, 9, 'available free RAM [GB]: ' + strtrim(GBavail,2)
  printf, 9, 'metric dependent RAM requirements'
  close, 9
  
  res = strpos(input,' ') ge 0
  IF res EQ 1 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (empty space in directory path or input filename) '
    close, 9
    GOTO, skip_gsc  ;; invalid input
  ENDIF
  
  res = query_tiff(input, inpinfo)
  IF inpinfo.type NE 'TIFF' THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (not a TIF image): '
    close, 9
    GOTO, skip_gsc  ;; invalid input
  ENDIF
 
  ;; check for single image in file
  IF inpinfo.num_images GT 1 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (more than 1 image in the TIF image): '
    close, 9
    GOTO, skip_gsc  ;; invalid input
  ENDIF

  ;; read it
  geotiff = 0
  im = read_tiff(input, geotiff=geotiff) & is_geotiff = (size(geotiff))[0]
  sz=size(im,/dim) & xdim=sz[0] & ydim=sz[1] & mindim=(xdim<ydim)
  IF nocheck EQ 1b THEN goto, good2go

  ;; check for single channel image
  ;;===========================
  IF size(im, / n_dim) NE 2 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (more than 1 band in the TIF image): '
    close, 9
    GOTO, skip_gsc  ;; invalid input
  ENDIF

  ;; check for byte array
  ;;===========================
  IF size(im, / type) NE 1 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (image is not of type BYTE): '
    close, 9
    GOTO, skip_gsc  ;; invalid input
  ENDIF
  
  IF gsc_w NE 'global' THEN BEGIN
    IF gsc_w_fix ge mindim THEN BEGIN
      openw, 9, fn_logfile, /append
      printf, 9, 'Window dimension larger than x or y image dimension. '
      close, 9
      GOTO, skip_gsc  ;; invalid input
    ENDIF
  ENDIF  

  good2go:
  ;;==============================================================================
  ;; 2) process for GraySpatCon
  ;;==============================================================================
  time0 = systime( / sec)
    
  ;; run GraySpatCon (Spatial Convolution metrics by K.Riitters)
  pushd, dir_proc
  resfloat = gsc_f EQ '2'
  ;; 'R ', 'C ',  'M ', 'F ','G ', 'P ', 'W ', 'A ', 'B ', 'X ', 'Y ', 'K '
  openw,1, 'gscpars.txt'
  printf,1,'R ' + strtrim(sz[1],2)
  printf,1,'C ' + strtrim(sz[0],2)
  printf,1,'M ' + gsc_m
  printf,1,'F ' + gsc_f
  printf,1,'G ' + gsc_g
  printf,1,'P ' + gsc_p
  IF gsc_w NE 'global' THEN printf,1,'W ' + gsc_w ELSE printf,1,'W 0' 
  printf,1,'A ' + gsc_a
  printf,1,'B ' + gsc_b
  printf,1,'X ' + gsc_x
  printf,1,'Y ' + gsc_y
  printf,1,'K ' + gsc_k
  close,1

  ;; echo the assigned settings to the log-file
  openw, 9, fn_logfile, /append
  printf, 9, 'GraySpatCon parameters assigned: '
  tt = strarr(file_lines('gscpars.txt'))
  close, 10 & openr, 10, 'gscpars.txt' & readf, 10, tt & close, 10
  for ii = 0,n_elements(tt)-1 do printf, 9, tt(ii)
  close, 9
  
  openw, 1, 'gscinput' & writeu,1, im & close,1
  file_copy, dir_gwb + '/grayspatcon_lin64', 'grayspatcon', /overwrite  
  ;; run GraySpatCon
  spawn, './grayspatcon', log
  
  ;; get result
  ;; if we get a GraySpatCon error then the last entry will not be "Normal Finish" 
  res = log[n_elements(log)-1] & res = strpos(strlowcase(res), 'normal finish') gt 0
  if res eq 0 then begin
    file_delete, 'gscinput', 'gscoutput', 'gscoutput.txt', 'gscpars.txt', /allow_nonexistent,/quiet
    popd
    openw, 9, fn_logfile, /append
    printf, 9,  px2 + ' comp.time [sec]: ', systime( / sec) - time0
    printf, 9, '+++++++++++++++++++++++++++++++++'
    printf, 9, '        GraySpatCon error output:'
    for idd = 0, n_elements(log)-1 do printf, 9, log[idd]
    printf, 9, '+++++++++++++++++++++++++++++++++'
    printf, 9, '  '
    close, 9
    goto, skip_gsc
  endif
  IF gsc_g EQ '0' THEN BEGIN ;; we have an image output    
    im = bytarr(sz(0),sz(1))
    if resfloat eq 1 then im=float(im)
    openr, 1, 'gscoutput' & readu,1, im & close,1  
  ENDIF ELSE BEGIN ;; we have the text output: gscoutput.txt
    res = file_info('gscoutput.txt')
    IF res.exists EQ 0b THEN goto, skip_gsc   
    fl = file_lines('gscoutput.txt') & gsctxt = strarr(fl)
    close, 10 & openr, 10, 'gscoutput.txt' & readf, 10, gsctxt & close, 10
  ENDELSE 
  ;; clean up  
  file_delete, 'gscinput', 'gscoutput', 'gscoutput.txt', 'gscpars.txt', /allow_nonexistent,/quiet
  popd

  ;; when we arrive here then GraySpatCon worked ok.
  okfile = okfile + 1
  ;; write out the original GraySpatCon output
  fbn = file_basename(list[fidx], '.tif')
  fn_outbase = dir_output + '/' + fbn + '_gsc' + gsc_m 
  IF gsc_g EQ '0' THEN BEGIN ;; we have an image output
    fn_out = fn_outbase + '.tif'
    IF is_geotiff GT 0 THEN BEGIN
      write_tiff, fn_out, im, geotiff = geotiff, float = resfloat, compression = 1
    ENDIF ELSE BEGIN
      write_tiff, fn_out, im, float = resfloat, compression = 1
    ENDELSE
    spawn, gedit + fn_out + ' > /dev/null 2>&1'
    im = 0
    
    ;; write the same 'gscoutput.txt' info style as for a global analysis
    log2 = strmid(log,1,3)
    fn_out = fn_outbase + '.txt' & openw, 10, fn_out
    printf, 10, 'Image output for metric ' +  gsc_m
    printf, 10, 'For the parameter set:'
    q = where(log2 EQ 'R =', ct) & IF ct gt 0 THEN printf, 10, log[q[0]]
    q = where(log2 EQ 'C =', ct) & IF ct gt 0 THEN printf, 10, log[q[0]]
    q = where(log2 EQ 'M =', ct) & IF ct gt 0 THEN printf, 10, log[q[0]]
    q = where(log2 EQ 'F =', ct) & IF ct gt 0 THEN printf, 10, log[q[0]]
    q = where(log2 EQ 'G =', ct) & IF ct gt 0 THEN printf, 10, log[q[0]]
    q = where(log2 EQ 'P =', ct) & IF ct gt 0 THEN printf, 10, log[q[0]]
    q = where(log2 EQ 'W =', ct) & IF ct gt 0 THEN printf, 10, log[q[0]]
    q = where(log2 EQ 'A =', ct) & IF ct gt 0 THEN printf, 10, log[q[0]]
    q = where(log2 EQ 'B =', ct) & IF ct gt 0 THEN printf, 10, log[q[0]]
    q = where(log2 EQ 'X =', ct) & IF ct gt 0 THEN printf, 10, log[q[0]]
    q = where(log2 EQ 'Y =', ct) & IF ct gt 0 THEN printf, 10, log[q[0]]
    q = where(log2 EQ 'K =', ct) & IF ct gt 0 THEN printf, 10, log[q[0]]
    close, 10  
    
  ENDIF ELSE BEGIN ;; we have text output only
    fn_out = fn_outbase + '.txt'
    openw, 10, fn_out & for idx = 0, fl-1 do printf, 10, gsctxt[idx] & close,10
  ENDELSE


  openw, 9, fn_logfile, /append
  printf, 9,  px2 + ' comp.time [sec]: ', systime( / sec) - time0
  printf, 9, '         GraySpatCon log:'
  for idd = 0, n_elements(log)-1 do printf, 9, log[idd]
  close, 9
  
  skip_gsc: 
  print, 'Done with: ' + file_basename(input)
ENDFOR
;; cleanup temporary proc directory
file_delete, dir_proc, /recursive, /quiet, /allow_nonexistent

;; inform that batch is done
proct = systime( / sec) - time00
IF proct GT 3600.0 THEN BEGIN
  proct2 = proct - ulong(proct/3600)*3600
  proctstr = strtrim(ulong(proct/3600.),2) + ' hrs, ' + strtrim(ulong(proct2/60.),2) + $
    ' mins, ' + strtrim(ulong(proct mod 60),2) + ' secs'
ENDIF ELSE BEGIN
  proctstr = strtrim(ulong(proct/60.),2) + $
    ' mins, ' + strtrim(ulong(proct mod 60),2) + ' secs'
ENDELSE
IF proct LT 60.0 THEN proctstr = strtrim(round(proct),2) + ' secs'
openw, 9, fn_logfile, /append
printf, 9, ''
printf, 9, '==============================================='
printf, 9,  px2 + ' Batch Processing total comp.time: ', proctstr
printf, 9, 'Successfully processed files: ',strtrim(okfile,2)+'/'+ strtrim(nr_im_files,2)
printf, 9, '==============================================='
close, 9

print, px2 + ' finished sucessfully'

fin:

END
