PRO GWB_REC
;;==============================================================================
;;         GWB APP to recode image classes
;;==============================================================================
;; 
;; Purpose: 
;;==============================================================================
;; IDL cmd-line app to recode classes as implemented in GuidosToolbox (GTB)
;; (https://forest.jrc.ec.europa.eu/en/activities/lpa/gtb/)
;; more info in the GTB manual.
;;
;; Requirements: no external requirements
;;
;; AUTHOR:
;;       Peter Vogt
;;       D.1, T.P. 261
;;       European Commission, JRC
;;       Via E. Fermi, 2749
;;       21027 Ispra, ITALY
;;
;;       Phone : +39 0332 78-5002
;;       E-mail: Peter.Vogt@ec.europa.eu

;;==============================================================================
GWB_mv = 'GWB_REC (version 1.8.8)'
;;
;; Module changelog
;; 1.8.8: use gdal only for recoding, added BIGTIFF switch, flexible input reading
;; 1.8.7: IDL 8.8.2
;; 1.8.6: added mod_params check
;; 1.6  : added output directory extension
;; 1.3  : added option for user-selectable input/output directories
;; 1.2  : initial internal release
;;
;;==============================================================================
;; Input: at least 2 files in the subfolder "input"
;;==============================================================================
;; a) input image(s) (geotiff):
;; at least 1 or more geotiff images in the subfolder "input"
;; the input image must have the assignment:
;; any number of classes within [0, 255 byte]
;;
;; b) rec-parameters.txt: (see header info in input/rec-parameters.txt)
;;  - lookup table with new and old class values
;;
;;==============================================================================
;; Output: in the subfolder "output"
;;==============================================================================
;; Recoded geotiff formatted images(byte)
;;
;; Processing steps:
;; 1) verify parameter file and compatibility of input image
;; 2) recode image
;; 3) post-process (write-out)
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
print,'GWB_REC using:'
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
mod_params = dir_input + '/rec-parameters.txt'
IF (file_info(mod_params)).exists EQ 0b THEN BEGIN
  print, "The file: " + mod_params + "  was not found."
  print, "Please copy the respective backup file into your input directory:"
  print, dir_inputdef + "/input/backup/*parameters.txt"
  print, "Exiting..."
  goto,fin
ENDIF

;;==============================================================================
;; 1a) verify parameter file
;;==============================================================================
;; read recode settings: , we need at least 256 valid lines
fl = file_lines(mod_params)
IF fl LT 256 THEN BEGIN
  print, "The file: " + mod_params + " is in a wrong format."
  print, "Please copy the respective backup file into your input directory:"
  print, dir_inputdef + "/input/backup/*parameters.txt"
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
IF ct LT 256 THEN BEGIN
  print, "The file: " + mod_params + " is in a wrong format."
  print, "(Recode table has less than 256 rows)"
  print, "Please copy the respective backup file into your input directory:"
  print, dir_inputdef + "/input/backup/*parameters.txt"
  print, "Exiting..."
  goto,fin
ENDIF
;; get and check parameters
;; cut out the recoding table
tt = strtrim(finp(q[0:255]),2) & psel = uintarr(2,256)
;; rows are pruned now. Check that empty space is present to separate the two entries
xx = strpos(tt, ' ') & q = where(xx eq -1, ct)
if ct gt 0 then begin
  print, "The file: " + mod_params + " has rows without a space separator"
  print, "Please copy the respective backup file into your input directory:"
  print, dir_inputdef + "/input/backup/*parameters.txt"
  print, "Exiting..."
  goto,fin
endif
;; verify that second entry is correct
for i = 0, 255 do begin
  istr = strtrim(i,2) 
  a = (strsplit(tt[i],' ',/extract, count=ct))[0] & b = (strsplit(tt[i],' ',/extract))[1]
  if ct gt 2 then begin
    print, "row with more than 2 entries detected"
    print, "Please copy the respective backup file into your input directory:"
    print, dir_inputdef + "/input/backup/*parameters.txt"
    print, "Exiting..."
    goto,fin
  endif
  if b ne istr then begin
    print, 'Second column (old_original_value) has a wonky value of: ' + b
    print, 'or is not in sequential order or modified incorrectly.'
    print, 'Correct to have new sequential values in [0, 255] only, or'
    print, 'copy the respective backup file into your input directory:'
    print, dir_inputdef + "/input/backup/*parameters.txt"
    print, "Exiting..."
    goto,fin
  endif
  newv = uint(a) & cc = strtrim(newv,2)
  if a ne cc then begin
    print, 'First column (new recode value) has a wonky value of: ' + a
    print, 'Correct to have new recode values in [0, 255] only.'
    print, "Exiting..."
    goto,fin  
  endif  
  if newv gt 255 then begin
    print, 'First column (new recode value) has incorrect value of: ' + strtrim(newv,2)
    print, 'Correct to have new recode values in [0, 255] only.'
    print, "Exiting..."
    goto,fin    
  endif
  psel[0,i] = newv
  psel[1,i] = uint(b)
  
endfor
pseln=rotate(psel,5)

dir_proc = dir_output + '/.proc'
file_mkdir, dir_proc

;;==============================================================================
;; check for python version
syspython = 3 & spawn, 'which python3 2>&1', res & res = res[0]
if strpos(res, "no python3") ge 0 then begin ;; python3 not found
  syspython = 2
  spawn, 'which python2 2>&1', res & res = res[0]
  if strpos(res, "no python2") ge 0 then begin
    print, "python was not found in the system"
    print, "Exiting..."
    goto,fin
  endif
endif 
;;==============================================================================
;;==============================================================================
;; apply recode settings in a loop over all tif images 
;;==============================================================================
;;==============================================================================
;; check gdal version, NUM_THREADS is supported only in 2.1 and later
spawn, 'gdalinfo --version', res & res = res[0]
res = strmid(res, 5, strpos(res,',')-5) & res = strmid(res, 0, strpos(res,'.',/reverse_search))
res = float(res)
IF res GE 2.1 THEN CCPU = ' -co "NUM_THREADS=ALL_CPUS" ' ELSE CCPU = ''

fn_logfile = dir_output + '/rec.log' 
nr_im_files = ct_tifs & time00 = systime( / sec) & okfile = 0l

openw, 9, fn_logfile
printf,9, GWB_mv 
printf, 9, 'Recode batch processing logfile: ', systime()
printf, 9, 'Number of files to be processed: ', nr_im_files
printf, 9, '==============================================='
close, 9


FOR fidx = 0, nr_im_files - 1 DO BEGIN
  counter = strtrim(fidx + 1, 2) + '/' + strtrim(nr_im_files, 2)
  
  input = dir_input + '/' + list[fidx] & res = strpos(input,' ') ge 0
  IF res EQ 1 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, ' '
    printf, 9, '==============   ' + counter + '   =============='
    printf, 9, 'Skipping invalid input (empty space in directory path or input filename): ', input
    close, 9
    GOTO, skip_p  ;; invalid input
  ENDIF
  
  type = '' & res = query_image(input, inpinfo, type=type)
  IF type NE 'TIFF' THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, ' '
    printf, 9, '==============   ' + counter + '   =============='
    printf, 9, 'Skipping invalid input (not a TIF image): ', input
    close, 9
    GOTO, skip_p  ;; invalid input
  ENDIF
 
  ;; check for single image in file
  IF inpinfo.num_images GT 1 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, ' '
    printf, 9, '==============   ' + counter + '   =============='
    printf, 9, 'Skipping invalid input (more than 1 image in the TIF image): ', input
    close, 9
    GOTO, skip_p  ;; invalid input
  ENDIF
  
  ;; check for single channel image
  ;;===========================
  IF inpinfo.channels GT 1 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, ' '
    printf, 9, '==============   ' + counter + '   =============='
    printf, 9, 'Skipping invalid input (more than 1 band in the TIF image): ', input
    close, 9
    GOTO, skip_p  ;; invalid input
  ENDIF

  ;; check for byte array
  ;;===========================
  IF inpinfo.pixel_type NE 1 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, ' '
    printf, 9, '==============   ' + counter + '   =============='
    printf, 9, 'Skipping invalid input (image is not of type BYTE): ', input
    close, 9
    GOTO, skip_p  ;; invalid input
  ENDIF
  
  ;; image size
  xdim = inpinfo.dimensions[0]
  ydim = inpinfo.dimensions[1]
  
  ;; anticipate bigtiff, if (compressed) file size of input is > 3.7 GB then enforce BIGTIFF=YES
  res = file_info(input) & fsize = res.size/(1024.0^3)
  IF fsize GT 3.7 THEN BTIFF = ' -co "BIGTIFF=YES" ' ELSE BTIFF = ''

  
  ;;==============================================================================
  ;; 2) run Recode in dir_proc to not interfere with other system-users
  ;;==============================================================================
  time0 = systime( / sec)
  
  fbn = file_basename(list[fidx], '.tif')
  outdir = dir_output + '/' + fbn + '_rec' & file_mkdir, outdir
  
  pushd, dir_proc
  ;; setup and run recode 
  openw, 1, 'recsize.txt'
  printf,1,'nrows '+strtrim(ydim,2)
  printf,1,'ncols '+strtrim(xdim,2)
  close, 1
  openw, 1, 'recode.txt' & printf, 1,pseln & close, 1
  ;; use gdal to write the raw data in bsq and without the geoheader
  spawn, 'gdal_translate -of ENVI ' + input + ' recinput > /dev/null 2>&1'  
  file_copy, dir_gwb + '/recode_lin64', 'recode', /overwrite
  file_copy, dir_gwb + '/gdalcopyproj.py', 'gdalcopyproj.py', /overwrite
  ;; as user, set correct python path for gdalcopyproj.py and ensure it is executable
  if syspython eq 3 then begin
    spawn, 'sed -i "1s|.*|\#\!/usr/bin/env python3|" gdalcopyproj.py'
  endif else begin
    spawn, 'sed -i "1s|.*|\#\!/usr/bin/env python|" gdalcopyproj.py'
  endelse
  file_chmod, 'gdalcopyproj.py', /A_EXECUTE 
  
  ;; do the recoding
  spawn, './recode', log
  ;;=======================================
  ;; write out the recoded image
  fn_out = outdir + '/' + fbn + '_rec.tif' 
  file_move, 'recinput.hdr','recoutput.hdr', /overwrite
  file_move, 'recinput.aux.xml','recoutput.aux.xml', /overwrite
  spawn, 'gdal_translate -of GTiff -co "COMPRESS=LZW"' + CCPU + BTIFF + ' recoutput ' + fn_out + ' > /dev/null 2>&1'
  spawn, './gdalcopyproj.py ' + input + ' ' + fn_out 
  popd
  okfile = okfile + 1

  openw, 9, fn_logfile, /append
  printf, 9, ' '
  printf, 9, '==============   ' + counter + '   =============='
  printf, 9, 'File: ' + input
  printf, 9, 'Recode comp.time [sec]: ', systime( / sec) - time0
  close, 9
  
  skip_p: 
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
printf, 9, 'Recode Batch Processing total comp.time: ', proctstr
printf, 9, 'Successfully processed files: ', strtrim(okfile,2)+'/'+ strtrim(nr_im_files,2)
printf, 9, '==============================================='
close, 9
print, 'Recode finished sucessfully'


fin:
END
