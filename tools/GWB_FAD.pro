PRO GWB_FAD
;;==============================================================================
;; GWB APP for multi-scale (5) Forest area Density (FAD, fragmentation)
;;==============================================================================
;; 
;; Purpose: 
;;==============================================================================
;; IDL cmd-line app to conduct FAD as implemented in GuidosToolbox (GTB)
;; (https://forest.jrc.ec.europa.eu/en/activities/lpa/gtb/)
;; more info in the GTB manual.
;;
;; Requirements: gdal
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
GWB_mv = 'GWB_FAD (version 1.8.8)'
;;
;; Module changelog:
;; 1.8.8: flexible input reading
;; 1.8.7: IDL 8.8.2
;; 1.8.6: added mod_params check
;; 1.6:   nocheck, byte-prec, fad_av, reduced processing time
;; 1.5:   added disk space test, gdal unset LDLIB
;; 1.3:   added option for user-selectable input/output directories
;; 1.2:   initial internal release
;;
;;==============================================================================
;; Input: at least 1 file in the subfolder "input"
;;==============================================================================
;; a) input image(s) (geotiff):
;; at least 1 or more geotiff images in the subfolder "input"
;; the input image must have the assignment:
;; 0 byte: missing or no-data (optional)
;; 1 byte: background pixels (mandatory)
;; 2 byte: foreground pixels (mandatory)
;; 3 byte: fragmenting - specific BG (dark-blue in output; optional)
;; 4 byte: non-fragm. BG (light-blue in output; optional)
;;
;;==============================================================================
;; Output: in the subfolder "output"
;;==============================================================================
;; a) FAD summary statistics (barplot, csv, txt)
;; b) 5 color-coded images with 6 fragmentation classes + 1 multiscale image
;; c) sav-file (containing settings for fragmentation change analysis)
;;
;; Processing steps:
;; 1) verify parameter file and compatibility of input image
;; 2) process for fad-fragmentation
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
print,'GWB_FAD using:'
if standalone eq 1 then dir_input = dir_inputdef + "/input"
if standalone eq 1 then dir_output = dir_inputdef + "/output"
print, 'dir_input= ', dir_input
print, 'dir_output= ', dir_output

;; verify colortables
IF (file_info('idl/fadcolors.sav')).exists EQ 0b THEN BEGIN
  print, "The file 'tools/idl/fadcolors.sav' was not found."
  print, "Exiting..."
  goto,fin
ENDIF
IF (file_info('idl/fe47colors.sav')).exists EQ 0b THEN BEGIN
  print, "The file 'tools/idl/fe47colors.sav' was not found."
  print, "Exiting..."
  goto,fin
ENDIF

;; verify to have tif image(s) (should be a geotiff)
pushd, dir_input & list = file_search('*.tif', count=ct_tifs) & popd
IF ct_tifs EQ 0 THEN BEGIN
  print, "The input directory does not contain an image with the extension '.tif'"
  print, 'Please copy your geotiff image here.'
  print, "Exiting..."
  goto,fin
ENDIF
mod_params = dir_input + '/fad-parameters.txt'
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
;; read fad settings, we need at least 3 valid lines
fl = file_lines(mod_params)
IF fl LT 3 THEN BEGIN
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
IF ct LT 3 THEN BEGIN
  print, "The file: " + mod_params + " is in a wrong format."
  print, "Please copy the respective backup file into your input directory:"
  print, dir_inputdef + "/input/backup/*parameters.txt"
  print, "Exiting..."
  goto,fin
ENDIF
;; get and check parameters
fadtype = strtrim(finp(q[0]), 2)
if fadtype eq 'FAD' or fadtype eq 'FAD-APP5' then begin
  restore, 'idl/fadcolors.sav'
endif else if fadtype eq 'FAD-APP2' then begin
  restore, 'idl/fe47colors.sav'
endif else begin
  print, "Select either: FAD or FAD-APP5 or FAD-APP2."
  print, "Exiting..."
  goto,fin
endelse
tvlct, r, g, b
if fadtype eq 'FAD' then fadg = 'FAD' else fadg = 'FAD-APP'

;; FG-connectivity
c_FGconn = strtrim(finp(q[1]), 2)
if c_FGconn eq '8' then begin
  conn_str = '8-conn FG' & conn8 = 1
endif else if c_FGconn eq '4' then begin
  conn_str = '4-conn FG' & conn8 = 0
endif else begin
  print, "Foreground connectivity is not 8 or 4."
  print, "Exiting..."
  goto,fin
endelse

hprec = strtrim(finp(q[2]), 2) & condition = hprec EQ '0' or hprec EQ '1'
IF condition NE 1b THEN BEGIN
  print, "High precision switch is not 0 or 1."
  print, "Exiting..."
  goto,fin
ENDIF
if hprec eq '1' then prec = 'FAD_av: ' else prec = '(byte)FAD_av: '

dir_proc = dir_output + '/.proc'
file_mkdir, dir_proc

;;==============================================================================
;;==============================================================================
;; apply fad settings in a loop over all tif images 
;;==============================================================================
;;==============================================================================
desc = 'GTB_FAD, https://forest.jrc.ec.europa.eu/en/activities/lpa/gtb/'
fn_logfile = dir_output + '/' + strlowcase(fadtype) + '.log'
nr_im_files = ct_tifs & time00 = systime( / sec) & okfile = 0l
nocheck = file_info(dir_input + '/nocheck.txt') & nocheck = nocheck.exists

openw, 9, fn_logfile
if nocheck eq 0 then printf,9,GWB_mv else printf,9, GWB_mv + ' - nocheck'
printf, 9, fadg + ' batch processing logfile: ', systime()
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
    GOTO, skip_fad  ;; invalid input
  ENDIF
  
  type = '' & res = query_image(input, type=type)
  IF type NE 'TIFF' THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, ' '
    printf, 9, '==============   ' + counter + '   =============='
    printf, 9, 'Skipping invalid input (not a TIF image): ', input
    close, 9
    GOTO, skip_fad  ;; invalid input
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
    GOTO, skip_fad  ;; invalid input
  ENDIF
  
  ;; get uncompressed image size in MB and check for sufficient disk space for processing
  inpsize = float(inpinfo.dimensions[0]) * inpinfo.dimensions[1]/1024/1024 ;; size in MB
  ;; make sure there is at least 6 times that size left, else exit
  IF hprec EQ '1' THEN reqsize = 8*inpsize ELSE reqsize = 4*inpsize
  spawn, 'df -BM --output=avail ' + dir_output, res
  IF n_elements(res) NE 2 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, ' '
    printf, 9, '==============   ' + counter + '   =============='
    printf, 9, 'Problems determining image size and/or available disk space: ', input
    close, 9
    GOTO, skip_fad  ;; invalid input
  ENDIF
  ;; get free space, strip off the Megabyte sign and convert to float for comparison with reqsize
  res = res [1] & res = strmid(res, 0,strlen(res)-1) & resf=float(res)
  IF resf LT reqsize then BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, ' '
    printf, 9, '==============   ' + counter + '   =============='
    printf, 9, 'Insuffcient free disk space, ' + res + 'MB needed for: ', input
    close, 9
    GOTO, skip_fad  ;; invalid input
  ENDIF


  ;; read it
  geotiff = 0
  im = read_tiff(input, geotiff=geotiff) & is_geotiff = (size(geotiff))[0]
  im = rotate(temporary(im),7) & sz=size(im,/dim) & xdim=sz[0] & ydim=sz[1] & imgminsize=(xdim<ydim)
  IF nocheck EQ 1b THEN goto, good2go

  ;; check for single channel image
  ;;===========================
  IF size(im, / n_dim) NE 2 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, ' '
    printf, 9, '==============   ' + counter + '   =============='
    printf, 9, 'Skipping invalid input (more than 1 band in the TIF image): ', input
    close, 9
    GOTO, skip_fad  ;; invalid input
  ENDIF

  ;; check for byte array
  ;;===========================
  IF size(im, / type) NE 1 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, ' '
    printf, 9, '==============   ' + counter + '   =============='
    printf, 9, 'Skipping invalid input (image is not of type BYTE): ', input
    close, 9
    GOTO, skip_fad  ;; invalid input
  ENDIF
  
  ;; check for correct image dimension
  ;;===================================
  IF imgminsize LT 250 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, ' '
    printf, 9, '==============   ' + counter + '   =============='
    printf, 9, 'Image dimension LT 250 pixels in x or y image dimension.', input
    close, 9
    GOTO, skip_fad  ;; invalid input
  ENDIF

  ;; check min/max value in image
  ;;===========================
  mxx = max(im, min = mii)
  IF mxx GT 4b THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, ' '
    printf, 9, '==============   ' + counter + '   =============='
    printf, 9, 'Skipping invalid input (Image maximum is larger than 4 BYTE): ', input
    close, 9
    GOTO, skip_fad  ;; invalid input
  ENDIF ELSE IF mxx LT 2b THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, ' '
    printf, 9, '==============   ' + counter + '   =============='
    printf, 9, 'Skipping invalid input (Image has no foreground (2 BYTE)): ', input
    close, 9
    GOTO, skip_fad  ;; invalid input
  ENDIF
  IF mii GT 1b THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, ' '
    printf, 9, '==============   ' + counter + '   =============='
    printf, 9, 'Skipping invalid input (Image has no background (1 BYTE)): ', input
    close, 9
    GOTO, skip_fad  ;; invalid input
  ENDIF
  ;; we must have foreground pixels (2) and we must have BG-pixels (1)
  upv = where(histogram(im, /l64) GT 0)
  q=where(upv eq 2, ct)
  IF ct NE 1 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, ' '
    printf, 9, '==============   ' + counter + '   =============='
    printf, 9, 'No pixels with mandatory FG-data value 2 BYTE found: ', input
    close, 9
    GOTO, skip_fad  ;; invalid input    
  ENDIF
  q=where(upv eq 1, ct)
  IF ct NE 1 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, ' '
    printf, 9, '==============   ' + counter + '   =============='
    printf, 9, 'No pixels with mandatory BG-data value 1 BYTE found: ', input
    close, 9
    GOTO, skip_fad  ;; invalid input
  ENDIF

  good2go:
  ;;==============================================================================
  ;; 2) process for FAD
  ;;==============================================================================
  time0 = systime( / sec)
  
  ;; image properties
  image0 = temporary(im)
  qmiss = where(image0 eq 0b,ctmiss, /l64) & q3b = where(image0 eq 3b, ct3b, /l64) & q4b = where(image0 eq 4b, ct4b, /l64)
  BGmask = where(image0 EQ 1b) & FGmask = where(image0 eq 2b, /l64, fgarea)

  ;; get average patch size and # of patches
  ext1 = lonarr(sz[0] + 2, sz[1] + 2)
  ext1[1:sz[0], 1:sz[1]] = long(image0 eq 2b)
  
  ;; label FG only
  ext1 = label_region(ext1, all_neighbors=conn8, / ulong)
  if fadg eq 'FAD-APP' then obj_area = histogram(ext1, reverse_indices = rev, /l64) else obj_area = histogram(ext1, /l64)
  obj_last=max(ext1) & ext1=0
  aps = total(obj_area[1:*]) / obj_last & z81 = strtrim(aps,2) & obj_area = 0 & z80 = strtrim(obj_last,2)
  z20 = '# Patches: ' + z80 & z22 = 'APS: ' + z81
  
  ;; FAD loop over 5 observation scales
  kdim = [7, 13, 27, 81, 243] 
  
  ;; define arrays for cummulative values in summary barplot in popup window
  intact = fltarr(6) & interior = intact & dominant = intact & transitional = intact
  patchy = intact & rare = intact & separated = intact & continuous = intact & fad_av = intact

  ;; calculate FAD for each of the 5 observation scales
  imdisp = image0 * 0 ;;; the average over observation scales image 
  
  ;; define output already here to write out each scale image
  fbn = file_basename(list[fidx], '.tif')
  outdir = dir_output + '/' + fbn + '_' + strlowcase(fadtype) & file_mkdir, outdir
  
  for isc = 0,4 do begin
    if isc eq 0 then begin ;; initialise scinput image
      tmp = temporary(image0)
      IF ct4b GT 0 THEN tmp[q4b] = 0b
    endif
    kdim_str = strtrim(kdim[isc],2)
    
    ;; run spatcon P2 (Spatial Convolution metrics by K.Riitters)
    pushd, dir_proc
    mstr = '81' & resfloat = fix(hprec)
    openw,1, 'scsize.txt'
    printf,1,'nrows '+strtrim(sz[1],2)
    printf,1,'ncols '+strtrim(sz[0],2)
    close,1

    openw,1, 'scpars.txt'
    printf,1,'w ' + kdim_str
    printf,1,'r ' + mstr
    printf,1,'a 2'
    printf,1,'h 1'
    printf,1,'b 0'
    printf,1,'m 0'
    if resfloat eq 1 then printf,1,'f 1' else printf,1,'f 0'
    close,1
    
    if isc eq 0 then begin
      openw, 1, 'scinput' & writeu,1, tmp & close, 1 & tmp = 0
      file_copy, dir_gwb + '/spatcon_lin64', 'spatcon', /overwrite
    endif
    spawn, './spatcon', log

    ;; get result
    im = bytarr(sz(0),sz(1))
    if resfloat eq 1 then im=float(im)
    openr, 1, 'scoutput' & readu,1, im & close,1

    ;; clean up
    file_delete, 'scoutput', 'scpars.txt', 'scsize.txt',/allow_nonexistent,/quiet
    popd

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
    fad_av(isc) = mean(im(FGmask))
    
    ;; do we want APP?
    if fadg eq 'FAD-APP' then begin
      extim = bytarr(sz[0] + 2, sz[1] + 2)
      extim[1:sz[0], 1:sz[1]] = im
      FOR i = 1l, obj_last DO BEGIN
        av = byte(round(mean(extim[rev[rev[i]:rev[i + 1] - 1]])))
        extim[rev[rev[i]:rev[i + 1] - 1]] = av
      ENDFOR
      im = extim[1:sz[0], 1:sz[1]] & extim=0
    endif

    ;; add specialBG (105b), specialBG-Nf (106b), Missing (102b), background (101b)
    if ct3b gt 0 then im[q3b] = 105b
    if ct4b gt 0 then im[q4b] = 106b
    if ctmiss gt 0 then im[qmiss] = 102b
    im[BGmask] = 101b

    ;; the statistics
    if fadg eq 'FAD' then begin
      ;; get the 5 fragmentation proportions (the 6th, rare, is always 100.0%)
      zz = (im EQ 100b) & intact(isc) = total(zz)/fgarea*100.0
      zz = (im GE 90b) AND (im LT 100b) & interior(isc) = total(zz)/fgarea*100.0
      zz = (im GE 60b) AND (im LT 90b) & dominant(isc) = total(zz)/fgarea*100.0
      zz = (im GE 40b) AND (im LT 60b) & transitional(isc) = total(zz)/fgarea*100.0
      zz = (im GE 10b) AND (im LT 40b) & patchy(isc) = total(zz)/fgarea*100.0
      zz = (im LT 10b) & rare(isc) = total(zz)/fgarea*100.0 & zz = 0
    endif else begin ;; output 5-class as well as 2-class
      zz = (im GE 90b) AND (im LE 100b) & interior(isc) = total(zz)/fgarea*100.0
      zz = (im GE 60b) AND (im LT 90b) & dominant(isc) = total(zz)/fgarea*100.0
      zz = (im GE 40b) AND (im LT 60b) & transitional(isc) = total(zz)/fgarea*100.0
      zz = (im GE 10b) AND (im LT 40b) & patchy(isc) = total(zz)/fgarea*100.0
      zz = (im LT 10b) & rare(isc) = total(zz)/fgarea*100.0 
      zz = (im GE 40b) AND (im LE 100b) & continuous(isc) = total(zz)/fgarea*100.0
      zz = (im LT 40b) & separated(isc) = total(zz)/fgarea*100.0 & zz = 0
    endelse
    
    ;; add to summary image
    imdisp = imdisp + im
    
    ;; write out the single scale image
    fn_out = outdir + '/' + fbn + '_' + strlowcase(fadtype) + '_' + kdim_str + '.tif'
    ;; add the geotiff info if available
    IF is_geotiff GT 0 THEN $
      write_tiff, fn_out, rotate(im,7), red = r, green = g, blue = b, geotiff = geotiff, description = desc, compression = 1 ELSE $
      write_tiff, fn_out, rotate(im,7), red = r, green = g, blue = b, description = desc, compression = 1       
  endfor    
  
  file_delete, dir_proc + '/scoutput',/allow_nonexistent,/quiet
  
  ;; average over the 5 classes in byte values
  im = byte(round(temporary(imdisp)/5.0))

  ;; add specialBG (105b), specialBG-Nf (106b), Missing (102b), background (101b) for display image: imdisp = actual summary data
  if ct3b gt 0 then im[q3b] = 105b
  if ct4b gt 0 then im[q4b] = 106b
  if ctmiss gt 0 then im[qmiss] = 102b
  im[BGmask] = 101b & BGmask = 0 & qmiss = 0 & q3b = 0 & q4b = 0
  fad_av(5) = mean(im(FGmask)) & FGmask = 0

  if fadg eq 'FAD' then begin
    ;; stats for sum of classes over observation scale for display image: im
    zz = (im EQ 100b) & intact(5) = total(zz)/fgarea*100.0
    zz = (im GE 90b) AND (im LT 100b) & interior(5) = total(zz)/fgarea*100.0
    zz = (im GE 60b) AND (im LT 90b) & dominant(5) = total(zz)/fgarea*100.0
    zz = (im GE 40b) AND (im LT 60b) & transitional(5) = total(zz)/fgarea*100.0
    zz = (im GE 10b) AND (im LT 40b) & patchy(5) = total(zz)/fgarea*100.0
    zz = (im LT 10b) & rare(5) = total(zz)/fgarea*100.0 & zz = 0
  endif else begin ;; output 5-class as well as 2-class
    zz = (im GE 90b) AND (im LE 100b) & interior(5) = total(zz)/fgarea*100.0
    zz = (im GE 60b) AND (im LT 90b) & dominant(5) = total(zz)/fgarea*100.0
    zz = (im GE 40b) AND (im LT 60b) & transitional(5) = total(zz)/fgarea*100.0
    zz = (im GE 10b) AND (im LT 40b) & patchy(5) = total(zz)/fgarea*100.0
    zz = (im LT 10b) & rare(5) = total(zz)/fgarea*100.0
    zz = (im GE 40b) AND (im LE 100b) & continuous(5) = total(zz)/fgarea*100.0
    zz = (im LT 40b) & separated(5) = total(zz)/fgarea*100.0 & zz = 0
  endelse
  
  fn_out = outdir + '/' + fbn + '_' + strlowcase(fadtype) + '_mscale.tif'
  ;; add the geotiff info if available
  IF is_geotiff GT 0 THEN $
    write_tiff, fn_out, rotate(im,7), red = r, green = g, blue = b, geotiff = geotiff, description = desc, compression = 1 ELSE $
    write_tiff, fn_out, rotate(im,7), red = r, green = g, blue = b, description = desc, compression = 1
  im = 0
  
  ;; the barplot popup window
  ;; here in batch mode add the buffer keyword to not open a graphic window on the screen
  ;; this is important because if the screensave kicks in then the graphic content can no lonnger be saved to a file
  scales = indgen(6)+1
  ;; normal barplot
  ;;==============================================================
  b1 = BARPLOT(scales, intact, Fill_Color=[0,120,0], yrange=[-4,104], xrange=[0.2, 9.5], /buffer, $
    ytitle='Foreground proportion [%]', xtitle='         Observation scale | MultiScale | Legend', $
    xticklen=0.02,yticklen=0.02,xminor=1, xtickv=[1,2,3,4,5]) 
  
  if fadtype eq 'FAD-APP2' then begin
    y2 = continuous & y1 = intact
    b2 = BARPLOT(scales,y2, BOTTOM_values=y1, Fill_Color=[140,200,101],/overplot)
    y1=y2 & y2 = separated+y2
    b3 = BARPLOT(scales,y2, BOTTOM_values=y1, Fill_Color=[0,120,0],/overplot)
  endif else begin
    y2 = interior+intact & y1 = intact
    b2 = BARPLOT(scales,y2, BOTTOM_values=y1, Fill_Color=[0,175,0],/overplot) & y1=y2 & y2 = dominant+y2
    b3 = BARPLOT(scales,y2, BOTTOM_values=y1, Fill_Color=[140,200,100],/overplot) & y1=y2 & y2 = transitional+y2
    b4 = BARPLOT(scales,y2, BOTTOM_values=y1, Fill_Color=[255,200,0],/overplot) & y1=y2 & y2 = patchy+y2
    b5 = BARPLOT(scales,y2, BOTTOM_values=y1, Fill_Color=[250,140,90],/overplot) & y1=y2 & y2 = rare+y2
    b6 = BARPLOT(scales,y2, BOTTOM_values=y1, Fill_Color=[215,50,40],/overplot)
  endelse
      
  ;; separator lines
  a = plot([5.5, 5.5],[-4, 104], /data, color='Black',/overplot, thick=3)
  a = plot([6.5, 6.5],[-4, 104], /data, color='Black',/overplot, thick=3)
  a = text(6.7,95, fadtype, /data,/current)
  a = text(6.7,90,'Fragmentation class: ',/data,/current)
  
  ;; legend
  if fadtype eq 'FAD-APP2' then begin
    c = symbol(6.9,85,'square',/data, /sym_filled, sym_color=[0,120,0],sym_size=2,LABEL_STRING='Separated')
    c = symbol(6.9,78,'square',/data, /sym_filled, sym_color=[140,200,101],sym_size=2,LABEL_STRING='Continuous')
  endif else begin
    c = symbol(6.9,85,'square',/data, /sym_filled, sym_color=[215,50,40],sym_size=2,LABEL_STRING='Rare')
    c = symbol(6.9,78,'square',/data, /sym_filled, sym_color=[250,140,90],sym_size=2,LABEL_STRING='Patchy')
    c = symbol(6.9,71,'square',/data, /sym_filled, sym_color=[255,200,0],sym_size=2,LABEL_STRING='Transitional')
    c = symbol(6.9,64,'square',/data, /sym_filled, sym_color=[140,200,100],sym_size=2,LABEL_STRING='Dominant')
    c = symbol(6.9,57,'square',/data, /sym_filled, sym_color=[0,175,0],sym_size=2,LABEL_STRING='Interior')
    if fadg eq 'FAD' then c = symbol(6.9,50,'square',/data, /sym_filled, sym_color=[0,120,0],sym_size=2,LABEL_STRING='Intact')
  endelse
  
  ;; info on special pixels
  IF (ct4b GT 0) THEN BEGIN
    a = text(6.7,40, 'Non-fragmenting',/data,/current)
    a = text(6.7,35, 'BG pixels present',/data,/current)
  ENDIF
  str = conn_str + ' [pixels]:' 
  a = text(6.7,20,str,/data,/current)
  z = strtrim(fgarea,2) & q = strmid(z,0,1,/reverse)
  ;; remove the dot at the end if it exists
  if q eq '.' then z = strmid(z,0,strlen(z)-1)
  a = text(6.7,15,'Area: '+z,/data,/current)
  a = text(6.7,10,z20,/data,/current)
  a = text(6.7,5,z22,/data,/current)
  fn_out = outdir + '/' + fbn + '_' + strlowcase(fadtype) + '_barplot.png'
  b1.save,fn_out, resolution=300
  b1.close
  
  
  ;; write out the statistics table 
  fn_out = outdir + '/' + fbn + '_' + strlowcase(fadtype) + '_mscale.txt'
  z = strtrim(fgarea,2)
  openw,12,fn_out
  printf, 12, fadg + ': Foreground Area Density summary analysis for image: '
  printf, 12, file_basename(input)
  printf, 12, '================================================================================'
  printf, 12, conn_str + ': area, # patches, aps [pixels]: ', z, ', ', z80,', ', z81
  IF ct4b GT 0 THEN printf, 12, 'Non-fragmenting background pixels [4b] in input image'
  printf, 12, 'Fragmentation class: foreground proportion at observation scale/area: '
  printf, 12, 'Observation scale:    1         2          3          4          5        mscale'
  printf, 12, 'Neighborhood area:   7x7      13x13      27x27      81x81     243x243'
  printf, 12, '================================================================================'
  if fadg eq 'FAD' then begin
    printf, 12, 'FAD 6-class:'
    printf, 12, format='(a14,6(f11.4))', 'Rare: ', rare
    printf, 12, format='(a14,6(f11.4))', 'Patchy: ', patchy
    printf, 12, format='(a14,6(f11.4))', 'Transitional: ', transitional
    printf, 12, format='(a14,6(f11.4))', 'Dominant: ', dominant
    printf, 12, format='(a14,6(f11.4))', 'Interior: ', interior
    printf, 12, format='(a14,6(f11.4))', 'Intact: ', intact
  endif else begin
    printf, 12, 'FAD-APP 5-class:'
    printf, 12, format='(a14,6(f11.4))', 'Rare: ', rare
    printf, 12, format='(a14,6(f11.4))', 'Patchy: ', patchy
    printf, 12, format='(a14,6(f11.4))', 'Transitional: ', transitional
    printf, 12, format='(a14,6(f11.4))', 'Dominant: ', dominant
    printf, 12, format='(a14,6(f11.4))', 'Interior: ', interior
    printf, 12, 'FAD-APP 2-class:'
    printf, 12, format='(a14,6(f11.4))', 'Separated: ', separated
    printf, 12, format='(a14,6(f11.4))', 'Continuous: ', continuous
  endelse 
  printf, 12, '================================================================================'
  printf, 12, format='(a14,6(f11.4))', prec, fad_av
  close, 12
  
  ;; save stats summary in idl sav format for potential change analysis at some later point
  ;; check if we have a geotiff image
  geotiff_log = '' ;; gdal geotiff-information
  IF is_geotiff GT 0 then spawn, 'unset LD_LIBRARY_PATH; gdalinfo -noct "' + input + '" 2>/dev/null', geotiff_log
  fn_out = outdir + '/' + fbn + '_' + strlowcase(fadtype) + '_mscale.sav' 
  save, filename = fn_out, fadtype, xdim, ydim, geotiff_log, $
    rare, patchy, transitional, dominant, interior, intact, separated, continuous, fgarea, kdim_str, fad_av, obj_last

  ;; write csv output
  fn_out = outdir + '/' + fbn + '_' + strlowcase(fadtype) + '_mscale.csv'
  openw,12,fn_out
  printf,12, fadg + ': FragmClass\ObsScale:, 1, 2, 3, 4, 5, Summary' & z = strtrim(rare,2)
  if fadg eq 'FAD' then begin
    printf, 12, 'FAD 6-class:'
    printf, 12, 'Rare:, ',z[0], ', ',z[1], ', ',z[2], ', ',z[3], ', ',z[4], ', ',z[5]  & z = strtrim(patchy,2)
    printf, 12, 'Patchy:, ',z[0], ', ',z[1], ', ',z[2], ', ',z[3], ', ',z[4], ', ',z[5]  & z = strtrim(transitional,2)
    printf, 12, 'Transitional:, ',z[0], ', ',z[1], ', ',z[2], ', ',z[3], ', ',z[4], ', ',z[5]  & z = strtrim(dominant,2)
    printf, 12, 'Dominant:, ',z[0], ', ',z[1], ', ',z[2], ', ',z[3], ', ',z[4], ', ',z[5]  & z = strtrim(interior,2)
    printf, 12, 'Interior:, ',z[0], ', ',z[1], ', ',z[2], ', ',z[3], ', ',z[4], ', ',z[5]  & z = strtrim(intact,2)
    printf, 12, 'Intact:, ',z[0], ', ',z[1], ', ',z[2], ', ',z[3], ', ',z[4], ', ',z[5]
  endif else begin
    printf, 12, 'FAD-APP 5-class:' & z = strtrim(rare,2) 
    printf, 12, 'Rare:, ',z[0], ', ',z[1], ', ',z[2], ', ',z[3], ', ',z[4], ', ',z[5]  & z = strtrim(patchy,2)
    printf, 12, 'Patchy:, ',z[0], ', ',z[1], ', ',z[2], ', ',z[3], ', ',z[4], ', ',z[5]  & z = strtrim(transitional,2)
    printf, 12, 'Transitional:, ',z[0], ', ',z[1], ', ',z[2], ', ',z[3], ', ',z[4], ', ',z[5] & z = strtrim(dominant,2)
    printf, 12, 'Dominant:, ',z[0], ', ',z[1], ', ',z[2], ', ',z[3], ', ',z[4], ', ',z[5] & z = strtrim(interior,2)
    printf, 12, 'Interior:, ',z[0], ', ',z[1], ', ',z[2], ', ',z[3], ', ',z[4], ', ',z[5] 
    printf, 12, 'FAD-APP 2-class:' & z = strtrim(separated,2) 
    printf, 12, 'Separated:, ',z[0], ', ',z[1], ', ',z[2], ', ',z[3], ', ',z[4], ', ',z[5] & z = strtrim(continuous,2)
    printf, 12, 'Continuous:, ',z[0], ', ',z[1], ', ',z[2], ', ',z[3], ', ',z[4], ', ',z[5] 
  endelse 
  z = strtrim(fad_av,2)
  printf, 12, prec + ', ',z[0], ', ',z[1], ', ',z[2], ', ',z[3], ', ',z[4], ', ',z[5]
  close,12

  okfile = okfile + 1

  openw, 9, fn_logfile, /append
  printf, 9, ' '
  printf, 9, '==============   ' + counter + '   =============='
  printf, 9, 'File: ' + input
  printf, 9, 'FAD comp.time [sec]: ', systime( / sec) - time0
  close, 9
  
  skip_fad: 
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
printf, 9, strupcase(fadtype) + ' Batch Processing total comp.time: ', proctstr
printf, 9, 'Successfully processed files: ',strtrim(okfile,2)+'/'+ strtrim(nr_im_files,2)
printf, 9, '==============================================='
close, 9

print, strupcase(fadtype) + ' finished sucessfully'

fin:
END
