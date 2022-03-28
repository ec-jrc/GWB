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
GWB_mv = 'GWB_REC (version 1.8.6)'
;;
;; Module changelog
;; 1.8.6: added mod_params check
;; 1.6  : nocheck, added output directory extension
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
if standalone eq 0 then print, 'dir_input= ', dir_input else print, dir_inputdef + "/input"
if standalone eq 0 then print, 'dir_output= ', dir_output else print, dir_inputdef + "/output"

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
;; read recode settings: 
tt = strarr(276) & close,1
IF file_lines(mod_params) LT n_elements(tt) THEN BEGIN
  print, "The file: " + mod_params + " is in a wrong format."
  print, 'Do NOT delete or add any lines into the template!'
  print, "Please copy the respective backup file into your input directory:"
  print, dir_inputdef + "/input/backup/*parameters.txt"
  goto,fin
ENDIF
;; check for correct input section lines
openr, 1, mod_params & readf,1,tt & close,1
if strmid(tt[18],0,6) ne '******' OR strmid(tt[275],0,6) ne '******' then begin
  print, 'rec-parameter file modified incorrectly.'
  print, "Please copy the respective backup file into your input directory:"
  print, dir_inputdef + "/input/backup/*parameters.txt"
  print, "Exiting..."
  goto,fin
endif
 
;; cut out the recoding table
tt = strtrim(tt[19:274],2) & psel = uintarr(2,256)
;; verify that second entry is correct
for i = 0, 255 do begin
  istr = strtrim(i,2) 
  a = (strsplit(tt[i],' ',/extract))[0] & b = (strsplit(tt[i],' ',/extract))[1]
  if b ne istr then begin
    print, 'second column (old_original_value) in rec-parameter file '
    print, 'not in sequential order or modified incorrectly.'
    print, "Please copy the respective backup file into your input directory:"
    print, dir_inputdef + "/input/backup/*parameters.txt"
    print, "Exiting..."
    goto,fin
  endif
  psel[0,i] = uint(a) & psel[1,i] = uint(b)
endfor
pseln=rotate(psel,5)

dir_proc = dir_output + '/.proc'
file_mkdir, dir_proc
;;==============================================================================
;;==============================================================================
;; apply recode settings in a loop over all tif images 
;;==============================================================================
;;==============================================================================
fn_logfile = dir_output + '/rec.log' 
nr_im_files = ct_tifs & time00 = systime( / sec) & okfile = 0l
nocheck = file_info(dir_input + '/nocheck.txt') & nocheck = nocheck.exists

openw, 9, fn_logfile
if nocheck eq 0 then printf,9,GWB_mv else printf,9, GWB_mv + ' - nocheck'
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
  
  type = '' & res = query_image(input, type=type)
  IF type NE 'TIFF' THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, ' '
    printf, 9, '==============   ' + counter + '   =============='
    printf, 9, 'Skipping invalid input (not a TIF image): ', input
    close, 9
    GOTO, skip_p  ;; invalid input
  ENDIF

  ;; check if input is an image format
  res = query_image(input, inpinfo)
 
  ;; check for single image in file
  IF inpinfo.num_images GT 1 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, ' '
    printf, 9, '==============   ' + counter + '   =============='
    printf, 9, 'Skipping invalid input (more than 1 image in the TIF image): ', input
    close, 9
    GOTO, skip_p  ;; invalid input
  ENDIF

  ;; read it
  geotiff = 0
  im = read_tiff(input, geotiff=geotiff) & is_geotiff = (size(geotiff))[0]
  im = rotate(temporary(im),7) & sz=size(im,/dim) & xdim=sz[0] & ydim=sz[1] 
  IF nocheck EQ 1b THEN goto, good2go

  ;; check for single channel image
  ;;===========================
  IF size(im, / n_dim) NE 2 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, ' '
    printf, 9, '==============   ' + counter + '   =============='
    printf, 9, 'Skipping invalid input (more than 1 band in the TIF image): ', input
    close, 9
    GOTO, skip_p  ;; invalid input
  ENDIF

  ;; check for byte array
  ;;===========================
  IF size(im, / type) NE 1 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, ' '
    printf, 9, '==============   ' + counter + '   =============='
    printf, 9, 'Skipping invalid input (image is not of type BYTE): ', input
    close, 9
    GOTO, skip_p  ;; invalid input
  ENDIF

  good2go:
  ;;==============================================================================
  ;; 2) run Recode in dir_proc to not interfere with other system-users
  ;;==============================================================================
  time0 = systime( / sec)
  
  pushd, dir_proc

  ;; setup and run recode 
  openw, 1, 'recsize.txt'
  printf,1,'nrows '+strtrim(sz[1],2)
  printf,1,'ncols '+strtrim(sz[0],2)
  close, 1
  openw, 1, 'recode.txt' & printf, 1,pseln & close, 1
  openw, 1, 'recinput' & writeu, 1, im & close, 1
  file_copy, dir_gwb + '/recode_lin64', 'recode', /overwrite
  spawn, './recode', log
  
  ;; get result
  im = temporary(im) * 0b
  openr, 1, 'recoutput' & readu,1, im & close,1
  popd
  
  
  ;;=======================================
  ;; write the final result
  fbn = file_basename(list[fidx], '.tif')
  outdir = dir_output + '/' + fbn + '_rec' & file_mkdir, outdir

  ;; write out the recoded image
  fn_out = outdir + '/' + fbn + '_rec.tif'
  ;; add the geotiff info if available
  IF is_geotiff GT 0 THEN $
    write_tiff, fn_out, rotate(im,7), geotiff = geotiff, compression = 1 ELSE $
    write_tiff, fn_out, rotate(im,7), compression = 1 
  im = 0
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
printf, 9, 'Successfully processed files: ',strtrim(okfile,2)+'/'+ strtrim(nr_im_files,2)
printf, 9, '==============================================='
close, 9
print, 'Recode finished sucessfully'


fin:
END
