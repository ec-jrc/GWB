PRO GWB_P223
;;==============================================================================
;;GWB APP for FG-Density (P2), FG-Contagion (P22), FG-Adjacency (P23), or
;;            spatcon mode for P2, P22, P23, Shannon, Sumd
;;==============================================================================
;; 
;; Purpose: 
;;==============================================================================
;; IDL cmd-line app to conduct P2, P22, P23 as implemented in GuidosToolbox (GTB)
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
GWB_mv = 'GWB_P223 (version 1.8.7)'
;;
;; Module changelog:
;; 1.8.7: IDL 8.8.2
;; 1.8.6: added mod_params check
;; 1.8  : added P23, shannon, sumd and spatcon mode
;; 1.6  : nocheck, highres switch
;; 1.3  : added option for user-selectable input/output directories
;; 1.2  : initial internal release
;;
;;==============================================================================
;; Input: at least 2 files in the subfolder "input"
;;==============================================================================
;; a) input image(s) (geotiff):
;; at least 1 or more geotiff images in the subfolder "input"
;; the input image must have the assignment:
;; 0 byte: missing or no-data (optional)
;; 1 byte: background pixels (mandatory for P2 or P22)
;; 2 byte: foreground pixels (mandatory for P2 or P22)
;; 3 byte: specific BG (mandatory for P23)
;;
;; b) p223-parameters.txt: (see header info in input/p223-parameters.txt)
;;  - 1 FG-Density  or  2 FG-Contagion  or  3 FG-Adjacency, or
;;    11, 12, 13, 14, 15 for original spatcon
;;  - moving window size [pixels]
;;
;;==============================================================================
;; Output: in the subfolder "output"
;;==============================================================================
;; P2/P22/P23 geotiff formatted color-coded images(byte), masked by foreground
;;
;; Processing steps:
;; 1) verify parameter file and compatibility of input image
;; 2) process for P223
;; 3) post-process (write-out and dostats)
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
print,'GWB_P223 using:'
if standalone eq 0 then print, 'dir_input= ', dir_input else print, dir_inputdef + "/input"
if standalone eq 0 then print, 'dir_output= ', dir_output else print, dir_inputdef + "/output"

;; restore colortable
IF (file_info('idl/entropycolors.sav')).exists EQ 0b THEN BEGIN
  print, "The file 'tools/idl/entropycolors.sav' was not found."
  print, "Exiting..."
  goto,fin
ENDIF
restore, 'idl/entropycolors.sav' & tvlct, r, g, b


;; verify to have tif image(s) (should be a geotiff)
pushd, dir_input & list = file_search('*.tif', count=ct_tifs) & popd
IF ct_tifs EQ 0 THEN BEGIN
  print, "The input directory does not contain an image with the extension '.tif'"
  print, 'Please copy your geotiff image here.'
  print, "Exiting..."
  goto,fin
ENDIF
mod_params = dir_input + '/p223-parameters.txt'
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
;; read p223 settings: 
tt = strarr(44) & close,1
IF file_lines(mod_params) LT n_elements(tt) THEN BEGIN
  print, "The file: " + mod_params + " is in a wrong format."
  print, "Please copy the respective backup file into your input directory:"
  print, dir_inputdef + "/input/backup/*parameters.txt"
  print, "Exiting..."
  goto,fin
ENDIF
;; check for correct input section lines
openr, 1, mod_params & readf,1,tt & close,1
if strmid(tt[39],0,6) ne '******' OR strmid(tt[43],0,6) ne '******' then begin
  print, "The file: " + mod_params + " is in a wrong format."
  print, "Please copy the respective backup file into your input directory:"
  print, dir_inputdef + "/input/backup/*parameters.txt"
  print, "Exiting..."
  goto,fin
endif

openr, 1, mod_params & readf,1,tt & close,1
ptype = strtrim(tt[40],2)
if ptype eq '1' then begin
  ptype_str = 'FG-Density' 
endif else if ptype eq '2' then begin
  ptype_str = 'FG-Contagion'
endif else if ptype eq '3' then begin
  ptype_str = 'FG-Adjacency'  
endif else if ptype eq '11' then begin
  ptype_str = 'FG-Density_spatcon'
endif else if ptype eq '12' then begin
  ptype_str = 'FG-Contagion_spatcon'
endif else if ptype eq '13' then begin
  ptype_str = 'FG-Adjacency_spatcon'
endif else if ptype eq '14' then begin
  ptype_str = 'FG-Shannon_spatcon'
endif else if ptype eq '15' then begin
  ptype_str = 'FG-SumD_spatcon'
endif else begin
  print, "P223 type is not 1, 2, 3, 11, 12, 13, 14 or 15."
  print, "Exiting..."
  goto,fin
endelse
kdim_str = strtrim(tt[41],2) & kdim = fix(kdim_str)
;; make sure kdim is appropriate
uneven = kdim mod 2
IF kdim LT 3 OR kdim GT 501 OR uneven EQ 0 THEN BEGIN
  print, "Moving window size is not in [3, 5, 7, ..., 501]."
  print, "Exiting..."
  goto,fin
ENDIF
hprec = strtrim(tt[42],2) & condition = hprec EQ '0' or hprec EQ '1'
IF condition NE 1b THEN BEGIN
  print, "High precision switch is not 0 or 1."
  print, "Exiting..."
  goto,fin
ENDIF
if hprec eq '1' then prec = ' ' else prec = ', (byte-prec)'


dir_proc = dir_output + '/.proc'
file_mkdir, dir_proc

;;==============================================================================
;;==============================================================================
;; apply p223 settings in a loop over all tif images 
;;==============================================================================
;;==============================================================================
case ptype of 
  '1': px = 'p2' 
  '2': px = 'p22'
  '3': px = 'p23'
  '11': px = 'p2_spatcon'
  '12': px = 'p22_spatcon'
  '13': px = 'p23_spatcon'
  '14': px = 'shannon_spatcon'
  '15': px = 'sumD_spatcon'
endcase
fn_logfile = dir_output + '/' + px + '_' + kdim_str + '.log' 
nr_im_files = ct_tifs & time00 = systime( / sec) & okfile = 0l
nocheck = file_info(dir_input + '/nocheck.txt') & nocheck = nocheck.exists
spatcon = strlen(ptype) eq 2
if spatcon eq 1 then loadct, 0

openw, 9, fn_logfile
if nocheck eq 0 then printf,9,GWB_mv else printf,9, GWB_mv + ' - nocheck'
printf, 9, ptype_str + ' batch processing logfile: ', systime()
printf, 9, 'Window size: ' + kdim_str + 'x' + kdim_str + prec
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
  if spatcon eq 0 then im = rotate(temporary(im),7) ;; rotate if GTB (non-spatcon mode)
  sz=size(im,/dim) & xdim=sz[0] & ydim=sz[1] & imgminsize=(xdim<ydim)
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
    
  IF kdim ge imgminsize THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, ' '
    printf, 9, '==============   ' + counter + '   =============='
    printf, 9, 'Kernel dimension larger than x or y image dimension. ' , input
    close, 9
    GOTO, skip_p  ;; invalid input
  ENDIF

  ;; check min/max value in image
  ;;===========================
  mxx = max(im, min = mii)
  IF (ptype EQ '3' OR ptype EQ '13') THEN BEGIN ;; test for adjacency compliance
    IF mxx GT 3b THEN BEGIN
      openw, 9, fn_logfile, /append
      printf, 9, ' '
      printf, 9, '==============   ' + counter + '   =============='
      printf, 9, 'Skipping invalid input (Image maximum is larger than 3 BYTE): ', input
      close, 9
      GOTO, skip_p
    ENDIF
    IF mxx LT 3b THEN BEGIN
      openw, 9, fn_logfile, /append
      printf, 9, ' '
      printf, 9, '==============   ' + counter + '   =============='
      printf, 9, 'Skipping invalid input (Image maximum is less than 3 BYTE): ', input
      close, 9
      GOTO, skip_p
    ENDIF
  ENDIF
 
  condition = (ptype EQ '1' OR ptype EQ '2' OR ptype EQ '11' OR ptype EQ '12' OR ptype EQ '14' OR ptype EQ '15')
  IF condition AND mxx GT 2b THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, ' '
    printf, 9, '==============   ' + counter + '   =============='
    printf, 9, 'Skipping invalid input (Image maximum is larger than 2 BYTE): ', input
    close, 9
    GOTO, skip_p  ;; invalid input
  ENDIF 
  
  IF mxx LT 2b THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, ' '
    printf, 9, '==============   ' + counter + '   =============='
    printf, 9, 'Skipping invalid input (Image has no foreground (2 BYTE)): ', input
    close, 9
    GOTO, skip_p  ;; invalid input
  ENDIF
  
  IF mii GT 1b THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, ' '
    printf, 9, '==============   ' + counter + '   =============='
    printf, 9, 'Skipping invalid input (Image has no background (1 BYTE)): ', input
    close, 9
    GOTO, skip_p  ;; invalid input
  ENDIF

  good2go:
  ;;==============================================================================
  ;; 2) process for P223
  ;;==============================================================================
  time0 = systime( / sec)
  
  ;; image properties
  if spatcon eq 0 then begin
    qmiss = where(im eq 0b,ctmiss, /l64) & BGmask = where(im EQ 1b, /l64)
  endif
  
  ;; run spatcon P2, P22, or P23 (Spatial Convolution metrics by K.Riitters)
  pushd, dir_proc
  case ptype of
    '1': mstr = '81'
    '2': mstr = '77'
    '3': mstr = '78'
    '11': mstr = '81' ;; spatcon P2
    '12': mstr = '77' ;; spatcon P22
    '13': mstr = '78' ;; spatcon P23
    '14': mstr = '73' ;; spatcon shannon
    '15': mstr = '74' ;; spatcon sumd
  endcase
  resfloat = fix(hprec)
  openw,1, 'scsize.txt'
  printf,1,'nrows '+strtrim(sz[1],2)
  printf,1,'ncols '+strtrim(sz[0],2)
  close,1
  
  openw,1, 'scpars.txt'
  printf,1,'w ' + kdim_str
  printf,1,'r ' + mstr
  printf,1,'a 2'
  printf,1,'h 1'
  if mstr eq '78' then printf,1,'b 3' else printf,1,'b 0'
  printf,1,'m 0'
  if resfloat eq 1 then printf,1,'f 1' else printf,1,'f 0'
  close,1

  openw, 1, 'scinput' & writeu,1, im & close,1
  file_copy, dir_gwb + '/spatcon_lin64', 'spatcon', /overwrite
  spawn, './spatcon', log
  
  ;; get result
  im = bytarr(sz(0),sz(1)) 
  if resfloat eq 1 then im=float(im)
  openr, 1, 'scoutput' & readu,1, im & close,1
  
  ;; clean up
  file_delete, 'scinput', 'scoutput', 'scpars.txt', 'scsize.txt',/allow_nonexistent,/quiet
  popd
  
  ;; write out the original spatcon output, which is non-rotated
  if spatcon eq 1 then begin
    fbn = file_basename(list[fidx], '.tif')
    outdir = dir_output + '/' + fbn + '_' + px + '_' + kdim_str & file_mkdir, outdir
    fn_out = outdir + '/' + fbn + '_' + px + '_' + kdim_str + '.tif'        
    IF is_geotiff GT 0 THEN BEGIN
      write_tiff, fn_out, im, geotiff = geotiff, float = resfloat, compression = 1 
    ENDIF ELSE BEGIN
      write_tiff, fn_out, im, float = resfloat, compression = 1
    ENDELSE
    im = 0  
    goto, skip_gtb
  endif
   
  ;; rescale to normalized byte range
  if resfloat eq 0 then begin
    ;; normally the conversion to byte range would be: im=(im-1b)/254.0 > 0.0
    ;; the potential max value from spatcon is 255b and *only* those pixels can have a remapped value of 100b
    ; we must prevent that the value 254b will get rounded to 100b so mask the 255b pixels
    q = where(im eq 255b, ct, /l64)
    im = (temporary(im) - 1b)/254.0 & im = 0.994999 < temporary(im) > 0.0
    im = byte(round(temporary(im) * 100.0))
    if ct gt 0 then im[q] = 100b
  endif else begin
    im = byte(round(im*100.0))
  endelse

  ;; add Missing (102b), background (101b)
  im[BGmask] = 101b & BGmask = 0
  if ctmiss gt 0 then im[qmiss] = 102b & qmiss = 0
  if ptype ne '3' then begin
    qFG = where(im le 100b, /l64, fgarea) & p_av = mean(im[qFG]) & qFG = 0
  endif
  
  ;;=======================================
  ;; write the final result
  fbn = file_basename(list[fidx], '.tif')
  outdir = dir_output + '/' + fbn + '_' + px + '_' + kdim_str & file_mkdir, outdir

  ;; a) write out the P2, P22 or P23 image
  fn_out = outdir + '/' + fbn + '_' + px + '_' + kdim_str + '.tif'
  desc = 'GTB_' + strupcase(px) +', https://forest.jrc.ec.europa.eu/en/activities/lpa/gtb/'
  ;; add the geotiff info if available
  IF is_geotiff GT 0 THEN $
    write_tiff, fn_out, rotate(im,7), red = r, green = g, blue = b, geotiff = geotiff, description = desc, compression = 1 ELSE $
    write_tiff, fn_out, rotate(im,7), red = r, green = g, blue = b, description = desc, compression = 1 
  im = 0
  
  ;; b) write out statistics
  if ptype ne '3' then begin
    fn_out = outdir + '/' + fbn + '_' + px + '_' + kdim_str + '.txt'
    z1 = strtrim(ulong64(fgarea),2) & z2 = strtrim(p_av,2)
    openw,12,fn_out
    printf, 12, strupcase(px) + '-summary at Observation Scale: ' + kdim_str
    printf, 12, 'Total Foreground Area [pixels]: ' + z1
    printf, 12, 'Average ' + strupcase(px) + ': ' + z2
    close, 12   
  endif
  
  skip_gtb:
  okfile = okfile + 1

  openw, 9, fn_logfile, /append
  printf, 9, ' '
  printf, 9, '==============   ' + counter + '   =============='
  printf, 9, 'File: ' + input
  printf, 9, strupcase(px) + ' comp.time [sec]: ', systime( / sec) - time0
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
printf, 9, strupcase(px) + ' Batch Processing total comp.time: ', proctstr
printf, 9, 'Successfully processed files: ',strtrim(okfile,2)+'/'+ strtrim(nr_im_files,2)
printf, 9, '==============================================='
close, 9

print, strupcase(px) + ' finished sucessfully'

fin:
END
