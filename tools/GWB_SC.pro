PRO GWB_SC
;;==============================================================================
;; GWB APP interface to SpatCon 
;;==============================================================================
;; 
;; Purpose: 
;;==============================================================================
;; IDL cmd-line app to run native SpatCon
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
GWB_mv = 'GWB_SC (version 1.9.5)'
;;
;; Module changelog:
;; 1.9.4: IDL 9.0.0
;; 1.9.2: IDL 8.9.0
;; 1.9.1: SpatCon bugfix, SW tag, rename to GWB_SC
;; 1.9.0: initial release of GWB_SPATCON: extended from GWB_P223 to provide full SpatCon access,
;;        added note to restore files, IDL 8.8.3
;;        fixed SpatCon binary for consistent float output       
;;
;;==============================================================================
;; Input: at least 2 files in the subfolder "input"
;;==============================================================================
;; a) input image(s) (geotiff):
;; at least 1 or more geotiff images in the subfolder "input"
;; the input image must be of data type byte and the appropriate assignment
;; to be evaluated by the selected SpatCon rule 
;;
;; b) sc-parameters.txt: (see header info in input/sc-parameters.txt)
;;  - SpatCon rule
;;  - moving window size [pixels]
;;  - switch for high precision (on/off)
;;
;;==============================================================================
;; Output: in the subfolder "output"
;;==============================================================================
;; native SpatCon output
;; 
;; Processing steps:
;; 1) verify parameter file and compatibility of input image
;; 2) run SpatCon rule
;; 3) post-process: write-out
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
print,'GWB_SC using:'
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
mod_params = dir_input + '/sc-parameters.txt'
IF (file_info(mod_params)).exists EQ 0b THEN BEGIN
  print, "The file: " + mod_params + "  was not found."
  print, "Please copy the respective backup file into your input directory:"
  print, dir_inputdef + "/input/backup/*parameters.txt"
  print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
ENDIF

;;==============================================================================
;; 1a) verify parameter file
;;==============================================================================
;; read SpatCon settings, we need at least 3 valid lines
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
scp = ['r ', 'w ', 'a ', 'b ', 'h ', 'f '] ;; SpatCon parameters to check for

;; 1) R: get the SpatCon mapping rule
;; valid entries: {1,6,7,10,20,21,51,52,53,54,71,72,73,74,75,76,77,78,81,82,83}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
q = where(strlowcase(strmid(finp,0,2)) eq 'r ') & q = q[0]
if q lt 0 then begin
  print, "The file: " + mod_params + " is in a wrong format."
  print, "no line with valid SpatCon parameter 'r <rule number>' found."
  print, "Please copy the respective backup file into your input directory:"
  print, dir_inputdef + "/input/backup/*parameters.txt"
  print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin  
endif

sc_r = (strsplit(finp(q),' ',/extract))[1]
;; sc_r_str: header info in log-file
;; px: filename abbreviation string, px2 in log-file
px = 'rule' + sc_r & px2 = 'SC-rule ' + sc_r
case sc_r of 
  '1': BEGIN
    sc_r_str = 'SC-rule 1: Majority pixel value'
  END
  '6': BEGIN
    sc_r_str = 'SC-rule 6: Landscape Mosaic 19-class'
  END
  '7': BEGIN
    sc_r_str = 'SC-rule 7: Landscape Mosaic 103-class'
  END
  '10': BEGIN
    sc_r_str = 'SC-rule 10: Number of unique byte values'
  END
  '20': BEGIN
    sc_r_str = 'SC-rule 20: Median pixel value'
  END
  '21': BEGIN
    sc_r_str = 'SC-rule 21: Mean pixel value'
  END
  '51': BEGIN
    sc_r_str = 'SC-rule 51: Gini-Simpson pixel diversity'
  END
  '52': BEGIN
    sc_r_str = 'SC-rule 52: Gini-Simpson pixel evenness'
  END
  '53': BEGIN
    sc_r_str = 'SC-rule 53: Shannon pixel evenness'
  END
  '54': BEGIN
    sc_r_str = 'SC-rule 54: Pmax'
  END
  '71': BEGIN
    sc_r_str = 'SC-rule 71: Angular second moment'
  END
  '72': BEGIN
    sc_r_str = 'SC-rule 72: Gini-Simpson adjacency evenness'
  END
  '73': BEGIN
    sc_r_str = 'SC-rule 73: Shannon adjacency evenness'
  END
  '74': BEGIN
    sc_r_str = 'SC-rule 74: Sum of diagonals'
  END
  '75': BEGIN
    sc_r_str = 'SC-rule 75: Proportion of total adjacencies involving a specific pixel value'
  END
  '76': BEGIN
    sc_r_str = 'SC-rule 76: Proportion of total adjacencies which are between two specific pixel values'
  END
  '77': BEGIN
    sc_r_str = 'SC-rule 77: Proportion of adjacencies involving a specified pixel value which are adjacencies with that same pixel value'
  END
  '78': BEGIN
    sc_r_str = 'SC-rule 78: Proportion of adjacencies involving a specific pixel value which are adjacencies between that pixel value and another specific pixel value'
  END
  '81': BEGIN
    sc_r_str = 'SC-rule 81: Area density'
  END
  '82': BEGIN
    sc_r_str = 'SC-rule 82: Ratio of the frequencies of two specified pixel values'
  END
  '83': BEGIN
    sc_r_str = 'SC-rule 83: Combined ratio of two specific pixel values'
  END
  ELSE: BEGIN
    print, "The file: " + mod_params + " is in a wrong format."
    print, "R: SpatCon rule is not in {1,6,7,10,20,21,51,52,53,54,71,72,73,74,75,76,77,78,81,82,83}."
    print, "Or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
    print, "Exiting..."
    goto,fin
  END
ENDCASE

;; 2) W: get the window size
;; valid entries: uneven in [3,5,7,...]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
q = where(strlowcase(strmid(finp,0,2)) eq 'w ') & q = q[0]
if q lt 0 then begin
  print, "The file: " + mod_params + " is in a wrong format."
  print, "W: no line with valid SpatCon parameter 'W <window size number>' found."
  print, "Please copy the respective backup file into your input directory:"
  print, dir_inputdef + "/input/backup/*parameters.txt"
  print, "Or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
endif
sc_w = (strsplit(finp(q),' ',/extract))[1]
sc_w_fix = fix(sc_w) & sc_w = strtrim(sc_w_fix,2)
;; make sure window size is appropriate
uneven = sc_w_fix mod 2
IF sc_w_fix LT 3 OR uneven EQ 0 THEN BEGIN ;; invalid user entry
 print, "The file: " + mod_params + " is in a wrong format."
 print, "W: Moving window size is not an uneven number in [3, 5, 7, 9, 11, ... ]."
 print, "Or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
 print, "Exiting..."
 goto,fin
ENDIF

;; 3) A: get first target code
;; valid entries in [0, 255]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
q = where(strlowcase(strmid(finp,0,2)) eq 'a ') & q = q[0]
if q lt 0 then begin ;; if not defined set to default
  sc_a = '0'
endif else begin
  sc_a = (strsplit(finp(q),' ',/extract))[1]  
  sc_a0 = sc_a & sc_a_fix = fix(sc_a) & sc_a = strtrim(sc_a_fix,2)
  condition = (sc_a_fix GE 0) AND (sc_a_fix LE 255) AND (sc_a EQ sc_a0)
  IF condition EQ 0b THEN BEGIN ;; invalid user entry
    print, "The file: " + mod_params + " is in a wrong format."
    print, "A: First target code is not in [0, 255]."
    print, "Or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
    print, "Exiting..."
    goto,fin
  ENDIF
endelse

;; 4) B: get second target code
;; valid entries in [0, 255]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
q = where(strlowcase(strmid(finp,0,2)) eq 'b ') & q = q[0]
if q lt 0 then begin ;; if not defined set to default
  sc_b = '0'
endif else begin
  sc_b = (strsplit(finp(q),' ',/extract))[1] 
  sc_b0 = sc_b & sc_b_fix = fix(sc_b) & sc_b = strtrim(sc_b_fix,2)
  condition = (sc_b_fix GE 0) AND (sc_b_fix LE 255) AND (sc_b EQ sc_b0)
  IF condition EQ 0b THEN BEGIN ;; invalid user entry
    print, "The file: " + mod_params + " is in a wrong format."
    print, "B: Second target code is not in [0, 255]."
    print, "Or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
    print, "Exiting..."
    goto,fin
  ENDIF
endelse

;; 5) H: get handling code
;; valid entries: 1 (ignore) or 2 (include missing pixels or edges)
;; default setting is 1
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
q = where(strlowcase(strmid(finp,0,2)) eq 'h ') & q = q[0]
if q lt 0 then begin ;; if not defined set to default
  sc_h = '1'
endif else begin
  sc_h = (strsplit(finp(q),' ',/extract))[1]
  condition = (sc_h EQ '1') OR (sc_h EQ '2')
  IF condition EQ 0b THEN BEGIN ;; invalid user entry
    print, "The file: " + mod_params + " is in a wrong format."
    print, "H: Handling code is not 1 or 2."
    print, "Or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
    print, "Exiting..."
    goto,fin
  ENDIF
endelse

;; 6) F: get float precision
;; valid entries: 0 (byte) or 1 (float)
;; default setting is 0
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
q = where(strlowcase(strmid(finp,0,2)) eq 'f ') & q = q[0]
if q lt 0 then begin ;; default to byte precision if not specified
  sc_f = '0'
endif else begin
  sc_f = (strsplit(finp(q),' ',/extract))[1]
  condition = sc_f EQ '0' or sc_f EQ '1'
  IF condition EQ 0b THEN BEGIN ;; invalid user entry
    print, "The file: " + mod_params + " is in a wrong format."
    print, "F: Float precision switch is not 0 or 1."
    print, "Or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
    print, "Exiting..."
    goto,fin
  ENDIF
endelse

;; 7) Z: Recode switch
;; valid entries: 0 or 1
;; default setting is 0
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
q = where(strlowcase(strmid(finp,0,2)) eq 'z ') & q = q[0]
if q lt 0 then begin ;; set to default if not specified
  sc_z = '0'
endif else begin
  sc_z = (strsplit(finp(q),' ',/extract))[1]
  condition = sc_z EQ '0' or sc_z EQ '1'
  IF condition EQ 0b THEN BEGIN ;; invalid user entry
    print, "The file: " + mod_params + " is in a wrong format."
    print, "Z: Recode switch is not 0 or 1."
    print, "Or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
    print, "Exiting..."
    goto,fin
  ENDIF
endelse
;; do we want recoding? If so, then prepare the recoding table for SpatCon
if sc_z eq '1' then begin
  rec_file = dir_input + '/rec-parameters.txt'
  IF (file_info(rec_file)).exists EQ 0b THEN BEGIN
    print, "The file: " + rec_file + "  was not found."
    print, "Please copy the respective backup file into your input directory:"
    print, dir_inputdef + "/input/backup/*parameters.txt"
    print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
    print, "Exiting..."
    goto,fin
  ENDIF
  ;; cut out recoding section and save as screcode.txt
  fl = file_lines(rec_file)
  recinp = strarr(fl) & close,1
  openr, 1, rec_file & readf, 1, recinp & close, 1
  ;; filter out lines starting with ; or * or empty lines
  q = where(strmid(recinp,0,1) eq ';', ct) & IF ct GT 0 THEN recinp[q] = ' '
  q = where(strmid(recinp,0,1) eq '*', ct) & IF ct GT 0 THEN recinp[q] = ' '
  q = where(strlen(strtrim(recinp,2)) GT 0, ctrec)
  IF ctrec LT 1 THEN BEGIN
    print, "The file: " + rec_file + " is in a wrong format."
    print, "(Recode table must have at least 1 row and no more than 256 rows)"
    print, "Please copy the respective backup file into your input directory:"
    print, dir_inputdef + "/input/backup/*parameters.txt"
    print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
    print, "Exiting..."
    goto,fin
  ENDIF 
  ;; get and check parameters
  tt = strtrim(recinp[q],2) & psel = uintarr(2,ctrec)
  ;; rows are pruned now. Check that empty space is present to separate the two entries
  xx = strpos(tt, ' ') & q = where(xx eq -1, ct)
  if ct gt 0 then begin
    print, "The file: " + rec_file + " is invalid:"
    print, "Row without 2 entries separated by a space detected"
    print, "Please copy the respective backup file into your input directory:"
    print, dir_inputdef + "/input/backup/*parameters.txt"
    print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
    print, "Exiting..."
    goto,fin
  endif
  ;; verify entries
  for i = 0, ctrec-1 do begin
    a = (strsplit(tt[i],' ',/extract, count=ct))[0] & b = (strsplit(tt[i],' ',/extract))[1]
    if ct gt 2 then begin
      print, "The file: " + rec_file + " is invalid:"
      print, "Row with more than 2 entries detected"
      print, "Please copy the respective backup file into your input directory:"
      print, dir_inputdef + "/input/backup/*parameters.txt"
      print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
      print, "Exiting..."
      goto,fin
    endif
    ;; verify that the first (original) entry is correct
    vx = uint(a) & cc = strtrim(vx,2)
    if a ne cc then begin
      print, "The file: " + rec_file + " is invalid:"
      print, 'First column (original value) has a wonky value of: ' + a
      print, 'Correct to have values in [0, 255] only.'
      print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
      print, "Exiting..."
      goto,fin
    endif
    if vx gt 255 then begin
      print, "The file: " + rec_file + " is invalid"
      print, 'First column (original value) has incorrect value of: ' + cc
      print, 'Correct to have values in [0, 255] only.'
      print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
      print, "Exiting..."
      goto,fin
    endif
    ;; verify that the second (recoded) value is correct
    vx = uint(b) & cc = strtrim(vx,2)
    if b ne cc then begin
      print, "The file: " + rec_file + " is invalid:"
      print, 'Second column (recoded_value) has a wonky value of: ' + b
      print, 'Correct to have new values in [0, 255] only, or'
      print, 'copy the respective backup file into your input directory:'
      print, dir_inputdef + "/input/backup/*parameters.txt"
      print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
      print, "Exiting..."
      goto,fin
    endif
    if vx gt 255 then begin
      print, "The file: " + rec_file + " is invalid"
      print, 'Second column (recoded_value) has incorrect value of: ' + cc
      print, 'Correct to have values in [0, 255] only.'
      print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
      print, "Exiting..."
      goto,fin
    endif
    psel[0,i] = uint(a)
    psel[1,i] = uint(b)
  endfor
  openw, 1, dir_input + '/screcode.txt' & printf, 1, psel & close, 1
endif

;; 8) M: get Missing after recoding
;; valid entries in [0, 255]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
q = where(strlowcase(strmid(finp,0,2)) eq 'm ') & q = q[0]
if q lt 0 then begin ;; if not defined set to default
  sc_m = '0'
endif else begin
  sc_m = (strsplit(finp(q),' ',/extract))[1]
  sc_m0 = sc_m & sc_m_fix = fix(sc_m) & sc_m = strtrim(sc_m_fix,2)
  condition = (sc_m_fix GE 0) AND (sc_m_fix LE 255) AND (sc_m EQ sc_m0)
  IF condition EQ 0b THEN BEGIN ;; invalid user entry
    print, "The file: " + mod_params + " is in a wrong format."
    print, "M: Missing pixel value AFTER recoding is not in [0, 255]."
    print, "Or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
    print, "Exiting..."
    goto,fin
  ENDIF
endelse

;; overwrite settings if needed
;; enforce byte output for rule 1,6,7,10
set2b = ['1','6','7','10']
q = (where(set2b eq sc_r,ct))[0] & IF ct GT 0 THEN sc_f = '0'

;; set precision description in log-file
IF sc_f EQ '1' THEN prec = ' ' ELSE prec = ', (byte-prec)'

dir_proc = dir_output + '/.proc'
;; cleanup temporary proc directory
file_delete, dir_proc, /recursive, /quiet, /allow_nonexistent
file_mkdir, dir_proc

;;==============================================================================
;;==============================================================================
;; apply SpatCon settings in a loop over all tif images 
;;==============================================================================
;;==============================================================================
desc = 'GTB_SC, https://forest.jrc.ec.europa.eu/activities/lpa/gtb/'
tagsw = 'TIFFTAG_SOFTWARE='+'"'+"GWB, https://forest.jrc.ec.europa.eu/en/activities/lpa/gwb/" +'" '
gedit = 'unset LD_LIBRARY_PATH; gdal_edit.py -mo ' + tagsw
gedit = gedit + '-mo TIFFTAG_IMAGEDESCRIPTION="'+desc + '" '

fn_logfile = dir_output + '/SpatCon.log' 
nr_im_files = ct_tifs & time00 = systime( / sec) & okfile = 0l
nocheck = file_info(dir_input + '/nocheck.txt') & nocheck = nocheck.exists

openw, 9, fn_logfile
if nocheck eq 0 then printf,9,GWB_mv else printf,9, GWB_mv + ' - nocheck'
printf, 9, 'logfile: ', systime()
printf, 9, sc_r_str + ' batch processing'
printf, 9, 'Window size: ' + sc_w + 'x' + sc_w + prec
printf, 9, 'Number of files to be processed: ', nr_im_files
printf, 9, '==============================================='
close, 9
;; write out the path to the logfile to append RAM usage later on
fn_dirs2 = strmid(fn_dirs,0,strlen(fn_dirs)-12) + 'gwb_sc_log.txt'
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
  printf, 9, 'Rule dependent RAM requirements'
  close, 9
  
  res = strpos(input,' ') ge 0
  IF res EQ 1 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (empty space in directory path or input filename): '
    close, 9
    GOTO, skip_sc  ;; invalid input
  ENDIF
  
  res = query_tiff(input, inpinfo)
  IF inpinfo.type NE 'TIFF' THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (not a TIF image): '
    close, 9
    GOTO, skip_sc  ;; invalid input
  ENDIF
 
  ;; check for single image in file
  IF inpinfo.num_images GT 1 THEN BEGIN
    openw, 9, fn_logfile, /append
     printf, 9, 'Skipping invalid input (more than 1 image in the TIF image): '
     close, 9
    GOTO, skip_sc  ;; invalid input
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
    GOTO, skip_sc  ;; invalid input
  ENDIF

  ;; check for byte array
  ;;===========================
  IF size(im, / type) NE 1 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (image is not of type BYTE): '
    close, 9
    GOTO, skip_sc  ;; invalid input
  ENDIF
    
  IF sc_w_fix ge mindim THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Window dimension larger than x or y image dimension. ' 
    close, 9
    GOTO, skip_sc  ;; invalid input
  ENDIF

  good2go:
  ;;==============================================================================
  ;; 2) process for SpatCon
  ;;==============================================================================
  time0 = systime( / sec)
    
  ;; run SpatCon (Spatial Convolution metrics by K.Riitters)
  pushd, dir_proc
  resfloat = fix(sc_f)
  openw,1, 'scsize.txt'
  printf,1,'nrows '+strtrim(sz[1],2)
  printf,1,'ncols '+strtrim(sz[0],2)
  close,1
  
  ;; 'r ', 'w ', 'a ', 'b ', 'h ', 'f ', 'z ', 'm '
  openw,1, 'scpars.txt'
  printf,1,'r ' + sc_r
  printf,1,'w ' + sc_w
  printf,1,'a ' + sc_a
  printf,1,'b ' + sc_b
  printf,1,'h ' + sc_h
  if resfloat eq 1 then printf,1,'f 1' else printf,1,'f 0'
  printf,1,'z ' + sc_z
  printf,1,'m ' + sc_m
  close,1

  ;; echo the assigned settings to the log-file
  openw, 9, fn_logfile, /append
  printf, 9, 'Spatcon parameters assigned: '
  tt = strarr(file_lines('scpars.txt'))
  close, 10 & openr, 10, 'scpars.txt' & readf, 10, tt & close, 10
  for ii = 0,n_elements(tt)-1 do printf, 9, tt(ii)
  close, 9
  
  openw, 1, 'scinput' & writeu,1, im & close,1
  file_copy, dir_gwb + '/spatcon_lin64', 'spatcon', /overwrite
  
  ;; do we want recoding? If so, then prepare the recoding table for SpatCon 
  if sc_z eq '1' then begin
    file_copy, dir_input + '/screcode.txt', 'screcode.txt'
  endif
  
  ;; run SpatCon
  spawn, './spatcon', log
  
  ;; get result
  im = bytarr(sz(0),sz(1)) 
  if resfloat eq 1 then im=float(im)
  ;; if we get a SpatCon error then the last entry will not be "Normal Finish" 
  res = log[n_elements(log)-1] & res = strpos(strlowcase(res), 'normal finish') gt 0
  if res eq 0 then begin
    file_delete, 'scinput', 'scoutput', 'scpars.txt', 'scsize.txt', 'screcode.txt', /allow_nonexistent,/quiet
    popd
    openw, 9, fn_logfile, /append
    printf, 9, px2 + ' comp.time [sec]: ', systime( / sec) - time0
    printf, 9, '+++++++++++++++++++++++++++++++++'
    printf, 9, '                SpatCon error output:'
    for idd = 0, n_elements(log)-1 do printf, 9, log[idd]
    printf, 9, '+++++++++++++++++++++++++++++++++'
    printf, 9, '  '
    close, 9
    goto, skip_sc
  endif
  openr, 1, 'scoutput' & readu,1, im & close,1  
  ;; clean up
  file_delete, 'scinput', 'scoutput', 'scpars.txt', 'scsize.txt', 'screcode.txt', /allow_nonexistent,/quiet
  popd
  
  ;; when we arrive here then SpatCon worked ok.
  okfile = okfile + 1
  ;; write out the original SpatCon output
  fbn = file_basename(list[fidx], '.tif')
  outdir = dir_output + '/' + fbn + '_' + px + '_' + sc_w & file_mkdir, outdir
  fn_out = outdir + '/' + fbn + '_' + px + '_' + sc_w + '.tif'
  IF is_geotiff GT 0 THEN BEGIN
    write_tiff, fn_out, im, geotiff = geotiff, float = resfloat, compression = 1
  ENDIF ELSE BEGIN
    write_tiff, fn_out, im, float = resfloat, compression = 1
  ENDELSE
  spawn, gedit + fn_out + ' > /dev/null 2>&1'
  im = 0

  openw, 9, fn_logfile, /append
  printf, 9, px2 + ' comp.time [sec]: ', systime( / sec) - time0
  printf, 9, '                SpatCon log:'
  for idd = 0, n_elements(log)-1 do printf, 9, log[idd]
  close, 9
  
  skip_sc: 
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
file_delete, dir_input + '/screcode.txt', /allow_nonexistent,/quiet

END
