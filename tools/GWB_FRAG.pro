PRO GWB_FRAG
;;==============================================================================
;; GWB APP for user-selected scale of FAC or FAD (fragmentation)
;;==============================================================================
;; 
;; Purpose: 
;;==============================================================================
;; IDL cmd-line app to conduct flexible FAC/FAD 
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
;;       E-mail: Peter.Vogt@ec.europa.eu

;;==============================================================================
GWB_mv = 'GWB_FRAG (version 1.9.0)'
;;
;; Module changelog:
;; 1.9.0: added note to restore files, added FAC analysis, fixed loop bug, fixed spatcon binary, IDL 8.8.3
;; 1.8.8: flexible input reading
;; 1.8.7: IDL 8.8.2
;; 1.8.6: added mod_params check
;; 1.8.4: reduced memory footprint, fixed image description, new FOS5
;; 1.6  : initial release: flexible FAD/FOS combination without barplot summary
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
;; a) FOS summary statistics (barplot, csv, txt)
;; b) up to 10 color-coded images with up to 6 fragmentation classes
;; c) sav-file (containing settings for fragmentation change analysis)
;;
;; Processing steps:
;; 1) verify parameter file and compatibility of input image
;; 2) process for fos-fragmentation
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
print,'GWB_FRAG using:'
if standalone eq 1 then dir_input = dir_inputdef + "/input"
if standalone eq 1 then dir_output = dir_inputdef + "/output"
print, 'dir_input= ', dir_input 
print, 'dir_output= ', dir_output

;; verify colortables
IF (file_info('idl/fadcolors.sav')).exists EQ 0b THEN BEGIN
  print, "The file 'tools/idl/fadcolors.sav' was not found."
  print, "Restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
ENDIF
IF (file_info('idl/fadcolors5.sav')).exists EQ 0b THEN BEGIN
  print, "The file 'tools/idl/fadcolors5.sav' was not found."
  print, "Restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
ENDIF
IF (file_info('idl/fe47colors.sav')).exists EQ 0b THEN BEGIN
  print, "The file 'tools/idl/fe47colors.sav' was not found."
  print, "Restore the default files using the command: cp -fr /opt/GWB/*put ~/"
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
mod_params = dir_input + '/frag-parameters.txt'
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
;; read frag settings, we need at least 5 valid lines
fl = file_lines(mod_params)
IF fl LT 5 THEN BEGIN
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
IF ct LT 5 THEN BEGIN
  print, "The file: " + mod_params + " is in a wrong format."
  print, "Please copy the respective backup file into your input directory:"
  print, dir_inputdef + "/input/backup/*parameters.txt"
  print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
ENDIF
;; get and check parameters
fragtype = strtrim(finp(q[0]), 2)
fragarray = ['FAC_5', 'FAC_6', 'FAC-APP_2', 'FAC-APP_5', 'FAD_5', 'FAD_6', 'FAD-APP_2', 'FAD-APP_5']
qq = where(fragtype eq fragarray)
IF qq LT 0 THEN  BEGIN
  print, "The file: " + mod_params + " is in a wrong format."
  print, 'The selected option is not correct: ' + fragtype
  print, "Select either of: FAC_5, FAC_6, FAC-APP_2, FAC-APP_5, FAD_5, FAD_6, FAD-APP_2, FAD-APP_5."
  print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
goto,fin
ENDIF
if strmid(fragtype,4,1) eq '6' or strmid(fragtype,4) eq 'APP_5' then begin
  restore, 'idl/fadcolors.sav'
endif else if strmid(fragtype,4,1) eq '5' then begin
  restore, 'idl/fadcolors5.sav'
endif else if strmid(fragtype,4) eq 'APP_2' then begin
  restore, 'idl/fe47colors.sav'
endif else begin
  print, "The file: " + mod_params + " is in a wrong format."
  print, "Select either of: FAC_5, FAC_6, FAC-APP_2, FAC-APP_5, FAD_5, FAD_6, FAD-APP_2, FAD-APP_5."
  print, "Or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
endelse
tvlct, r, g, b
if strlen(fragtype) eq 5 then fosg = 'FOS' else fosg = 'FOS-APP'
method = strmid(fragtype,0,3)
repstyle = method + ' at pixel level'
IF fosg eq 'FOS-APP' then repstyle = method + ' at patch level (APP: average per patch)'
IF fosg eq 'FOS-APP' then repclass = strmid(fragtype,8,1) ELSE repclass = strmid(fragtype,4,1)

;; FG-connectivity
c_FGconn = strtrim(finp(q[1]), 2)
if c_FGconn eq '8' then begin
  conn_str = '8-conn FG' & conn8 = 1
endif else if c_FGconn eq '4' then begin
  conn_str = '4-conn FG' & conn8 = 0
endif else begin
  print, "The file: " + mod_params + " is in a wrong format."
  print, "Foreground connectivity is not 8 or 4."
  print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
endelse

;; Pixel resolution
pixres_str = strtrim(finp(q[2]), 2) & pixres = abs(float(pixres_str))
if pixres le 0.000001 then begin
  print, "The file: " + mod_params + " is in a wrong format."
  print, "Pixel resolution [m] seems wonky: " + pixres_str
  print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
endif
pixres_str = strtrim(pixres, 2)
;; area conversions
pix2hec = ((pixres)^2) / 10000.0
pix2acr = pix2hec * 2.47105

;; high precision?
hprec = strtrim(finp(q[4]), 2) & condition = hprec EQ '0' or hprec EQ '1'
IF condition NE 1b THEN BEGIN
  print, "The file: " + mod_params + " is in a wrong format."
  print, "High precision switch is not 0 or 1."
  print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
ENDIF
if hprec eq '1' then prec = method+'_av: ' else prec = '(byte)'+method+'_av: '

;; observation scales, maximum 10
ath = strtrim(finp(q[3]), 2)
res = strsplit(ath,' ',/extract) & nr_res = n_elements(res)
cl1 = 0 & cl2 = 0 & cl3 = 0 & cl4 = 0 & cl5 = 0
cl6 = 0 & cl7 = 0 & cl8 = 0 & cl9 = 0 & cl10 = 0
cl1_str = res[0] & cl1 = ulong(abs(cl1_str))
IF nr_res GE 2 THEN BEGIN
  cl2_str = res[1] & cl2 = ulong(abs(cl2_str))
ENDIF
IF nr_res GE 3 THEN BEGIN
  cl3_str = res[2] & cl3 = ulong(abs(cl3_str))
ENDIF
IF nr_res GE 4 THEN BEGIN
  cl4_str = res[3] & cl4 = ulong(abs(cl4_str))
ENDIF
IF nr_res GE 5 THEN BEGIN 
  cl5_str = res[4] & cl5 = ulong(abs(cl5_str))
ENDIF
IF nr_res GE 6 THEN BEGIN 
  cl6_str = res[5] & cl6 = ulong(abs(cl6_str))
ENDIF
IF nr_res GE 7 THEN BEGIN
  cl7_str = res[6] & cl7 = ulong(abs(cl7_str))
ENDIF
IF nr_res GE 8 THEN BEGIN
  cl8_str = res[7] & cl8 = ulong(abs(cl8_str))
ENDIF
IF nr_res GE 9 THEN BEGIN
  cl9_str = res[8] & cl9 = ulong(abs(cl9_str))
ENDIF
IF nr_res GE 10 THEN BEGIN ;; more than 10 will be neglected
  cl10_str = res[9] & cl10 = ulong(abs(cl10_str))
ENDIF
cat = [cl1, cl2, cl3, cl4, cl5, cl6, cl7, cl8, cl9, cl10] ;; the defined kernel sizes
;; filter out invalid settings
q = where(cat ge 3,ct)
if ct eq 0 then begin
  print, "The file: " + mod_params + " is in a wrong format."
  print, "Invalid kernel window size settings."
  print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
endif else begin
  cat=cat[q]
endelse
;; make sure numbers are uneven
cat2 = cat mod 2 & q = where(cat2 eq 0, ct)
if ct gt 0 then cat[q] = cat[q] + 1
;; make sure min is at least 3 and max is not larger than 501
cat = 3 > cat < 501
;; sort it, remove double entries, increasing order
cat = cat(sort(cat)) & cat = cat(uniq(cat))
nr_cat = n_elements(cat)


dir_proc = dir_output + '/.proc'
;; cleanup temporary proc directory
file_delete, dir_proc, /recursive, /quiet, /allow_nonexistent
file_mkdir, dir_proc

;;==============================================================================
;;==============================================================================
;; apply frag settings in a loop over all tif images 
;;==============================================================================
;;==============================================================================
desc = 'GTB_FOS, https://forest.jrc.ec.europa.eu/en/activities/lpa/gtb/'
fn_logfile = dir_output + '/' + 'frag.log'
nr_im_files = ct_tifs & time00 = systime( / sec) & okfile = 0l
nocheck = file_info(dir_input + '/nocheck.txt') & nocheck = nocheck.exists

openw, 9, fn_logfile
if nocheck eq 0 then printf,9,GWB_mv else printf,9, GWB_mv + ' - nocheck'
printf, 9, fragtype + ' batch processing logfile: ', systime()
cat3 = strtrim(cat, 2) + ',' & cc = '' & for i = 0, nr_cat-1 do cc = cc + cat3[i]
printf, 9, conn_str + ', Pixel resolution: ' + pixres_str + '[m]'
printf, 9, 'Window size: ' + cc
cat3 = strtrim(round(float(cat)^2 * pix2hec),2)+',' & cc = '' & for i = 0, nr_cat-1 do cc = cc + cat3[i]
printf, 9, 'Observation scale [ha]: ' + cc
cat3 = strtrim(round(float(cat)^2 * pix2acr),2)+',' & cc = '' & for i = 0, nr_cat-1 do cc = cc + cat3[i]
printf, 9, 'Observation scale [ac]: ' + cc
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
    GOTO, skip_fos  ;; invalid input
  ENDIF
  
  res = query_tiff(input, inpinfo)
  IF inpinfo.type NE 'TIFF' THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, ' '
    printf, 9, '==============   ' + counter + '   =============='
    printf, 9, 'Skipping invalid input (not a TIF image): ', input
    close, 9
    GOTO, skip_fos  ;; invalid input
  ENDIF
 
  ;; check for single image in file
  IF inpinfo.num_images GT 1 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, ' '
    printf, 9, '==============   ' + counter + '   =============='
    printf, 9, 'Skipping invalid input (more than 1 image in the TIF image): ', input
    close, 9
    GOTO, skip_fos  ;; invalid input
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
    GOTO, skip_fos  ;; invalid input
  ENDIF
  ;; get free space, strip off the Megabyte sign and convert to float for comparison with reqsize
  res = res [1] & res = strmid(res, 0,strlen(res)-1) & resf=float(res)
  IF resf LT reqsize then BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, ' '
    printf, 9, '==============   ' + counter + '   =============='
    printf, 9, 'Insufficent free disk space, ' + res + 'MB needed for: ', input
    close, 9
    GOTO, skip_fos  ;; invalid input
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
    GOTO, skip_fos  ;; invalid input
  ENDIF

  ;; check for byte array
  ;;===========================
  IF size(im, / type) NE 1 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, ' '
    printf, 9, '==============   ' + counter + '   =============='
    printf, 9, 'Skipping invalid input (image is not of type BYTE): ', input
    close, 9
    GOTO, skip_fos  ;; invalid input
  ENDIF
  
  ;; check for correct image dimension
  ;;===================================
  IF imgminsize LT 250 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, ' '
    printf, 9, '==============   ' + counter + '   =============='
    printf, 9, 'Image dimension LT 250 pixels in x or y image dimension.', input
    close, 9
    GOTO, skip_fos  ;; invalid input
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
    GOTO, skip_fos  ;; invalid input
  ENDIF ELSE IF mxx LT 2b THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, ' '
    printf, 9, '==============   ' + counter + '   =============='
    printf, 9, 'Skipping invalid input (Image has no foreground (2 BYTE)): ', input
    close, 9
    GOTO, skip_fos  ;; invalid input
  ENDIF
  IF mii GT 1b THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, ' '
    printf, 9, '==============   ' + counter + '   =============='
    printf, 9, 'Skipping invalid input (Image has no background (1 BYTE)): ', input
    close, 9
    GOTO, skip_fos  ;; invalid input
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
    GOTO, skip_fos  ;; invalid input    
  ENDIF
  q=where(upv eq 1, ct)
  IF ct NE 1 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, ' '
    printf, 9, '==============   ' + counter + '   =============='
    printf, 9, 'No pixels with mandatory BG-data value 1 BYTE found: ', input
    close, 9
    GOTO, skip_fos  ;; invalid input
  ENDIF

  good2go:
  ;;==============================================================================
  ;; 2) process for fragtype
  ;;==============================================================================
  time0 = systime( / sec)
  
  ;; image properties
  image0 = temporary(im)
  qmiss = where(image0 eq 0b, ctmiss, /l64) & q3b = where(image0 eq 3b, ct3b, /l64) & q4b = where(image0 eq 4b, ct4b, /l64)
  BGmask = where(image0 EQ 1b, /l64) & qFG = where(image0 eq 2b, /l64, fgarea) & obj_last = -1

  if fosg eq 'FOS-APP' then begin
    ;; for FOS_APP we need the patch sizes
    ext1 = bytarr(sz[0] + 2, sz[1] + 2)
    ext1[1:sz[0], 1:sz[1]] = image0 eq 2b
    ;; label FG only
    ext1 = ulong(temporary(ext1)) & obj_area = histogram(ext1, /l64) 
    ext1 = label_region(temporary(ext1), all_neighbors=conn8, / ulong)
    obj_last = max(ext1) & z80 = strtrim(obj_last,2)
    aps = total(obj_area[1:*]) / obj_last & z81 = strtrim(aps,2) 
    ;; get pixel indices by patch
    ext1 = histogram(temporary(ext1), reverse_indices = rev, /l64) & ext1=0
  endif
  
  ;; FOS loop over observation scales
  kdim = cat 
  
  ;; define arrays for cummulative values in summary barplot in popup window
  intact = fltarr(nr_cat) & interior = intact & dominant = intact & transitional = intact
  patchy = intact & rare = intact & separated = intact & continuous = intact & fad_av = intact
  
  ;; define output already here to write out each scale image
  fbn = file_basename(list[fidx], '.tif')
  outdir = dir_output + '/' + fbn + '_frag' & file_mkdir, outdir
  
  for isc = 0, nr_cat-1 do begin
    if isc eq 0 then begin ;; initialise scinput image
      tmp = temporary(image0)
      IF ct4b GT 0 THEN tmp[q4b] = 0b
    endif
    kdim_str = strtrim(kdim[isc],2)
    
    ;; run spatcon Density (PF) or Clustering (Spatial Convolution metrics by K. Riitters)
    pushd, dir_proc
    IF strmid(fragtype,0,3) eq 'FAC' then begin
      mstr = '76' 
      bstr = 'b 2'
    ENDIF ELSE BEGIN
      mstr = '81' 
      bstr = 'b 0'
    ENDELSE
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
    printf,1, bstr
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
    if resfloat eq 1 then im=float(temporary(im))
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
      im = byte(round(temporary(im) * 100.0))
    endelse
    fad_av(isc) = mean(im(qFG))
    
    ;; do we want APP?
    if fosg eq 'FOS-APP' then begin
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
    if fosg eq 'FOS' then begin
      ;; get the 5 fragmentation proportions (the 6th, rare, is always 100.0%)
      if strmid(fragtype,4,1) eq '6' then begin
        zz = (im EQ 100b) & intact(isc) = total(zz)/fgarea*100.0
        zz = (im GE 90b) AND (im LT 100b) & interior(isc) = total(zz)/fgarea*100.0
      endif else begin
        zz = (im GE 90b) AND (im LE 100b) & interior(isc) = total(zz)/fgarea*100.0
      endelse                  
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
       
    ;; write out the single scale image
    fn_out = outdir + '/' + fbn + '_fos-' + strlowcase(fragtype) + 'class_' + kdim_str + '.tif'
    ;; add the geotiff info if available
    IF is_geotiff GT 0 THEN $
      write_tiff, fn_out, rotate(im,7), red = r, green = g, blue = b, geotiff = geotiff, description = desc, compression = 1 ELSE $
      write_tiff, fn_out, rotate(im,7), red = r, green = g, blue = b, description = desc, compression = 1    
        
  endfor    
  file_delete, dir_proc + '/scoutput',/allow_nonexistent,/quiet
  
  ;; write out the statistics table
  fn_out = outdir + '/' + fbn + '_fos-' + strlowcase(fragtype) + 'class_' + kdim_str + '.txt'

  openw,12,fn_out
  printf, 12, 'Fragmentation analysis using Fixed Observation Scale (FOS)'
  printf, 12, 'Method options: FAC (Foreground Area Clustering); FAD (Foreground Area Density)'
  printf, 12, 'Summary analysis for image: '
  printf, 12, file_basename(input)
  printf, 12, '================================================================================'
  printf, 12, 'FOS parameter settings:'
  printf, 12, 'Foreground connectivity: ' + conn_str
  printf, 12, 'FOS-type selected: ' + fragtype
  printf, 12, 'Method: ' + method
  printf, 12, 'Reporting style: ' + repstyle
  printf, 12, 'Number of reporting classes: ' + repclass
  printf, 12, 'Pixel resolution [m]: ' + pixres_str
  printf, 12, 'Window size [pixels]: ' + kdim_str
  printf, 12, 'Observation scale [(window size * pixel resolution)^2]: '
  ;; Observation scales
  w = indgen(nr_cat)+1 & if nr_cat gt 1 then w = w[1:*]
  if nr_cat eq 1 then printf, 12, format='(a24)', 'Observation scale:   1' else $
    printf, 12, format='(a23,9(i11))', 'Observation scale:    1', w

  ;; observation area
  cat2 = strarr(nr_cat)
  for id = 0, nr_cat -1 do cat2[id] = '   ' + strtrim(cat[id],2) + 'x' + strtrim(cat[id],2) + '   '
  cat2[0] = cat2[0] + '  '
  ;  printf, 12, format = '(%"Neighborhood area:", 10(A))', cat2
  printf, 12, format = '(a18, 10(A))', 'Neighborhood area:',cat2

  ;; area conversions
  hec = ((pixres * kdim)^2) / 10000.0
  acr = hec * 2.47105
  printf, 12, format = '(a15, 10(f11.2))', '[hectare]:', hec
  printf, 12, format = '(a15, 10(f11.2))', '[acres]:', acr
  printf, 12, '================================================================================'
  printf, 12, 'Image foreground statistics:'
  printf, 12, 'Foreground area [pixels]: ', strtrim(fgarea,2)
  if fosg eq 'FOS-APP' then printf, 12, 'Number of foreground patches: ',  z80
  if fosg eq 'FOS-APP' then printf, 12, 'Average foreground patch size: ', z81
  IF ct4b GT 0 THEN printf, 12, 'Non-fragmenting background pixels [4b] in input image'
  printf, 12, '================================================================================'
  printf, 12, 'Proportion [%] of foreground area in foreground cover class:'
  fmt = '(a55,'+strtrim(nr_cat,2)+'(f11.4))'
  fmt2 = '(a67,'+strtrim(nr_cat,2)+'(f11.4))'
  
  if fosg eq 'FOS' then begin    
    ;if fragtype eq 'FOS6' then printf, 12, 'FOS 6-class:' else printf, 12, 'FOS 5-class:'    
    printf, 12, repstyle  + ': ' + repclass + ' classes'
    printf, 12, format=fmt, 'Rare (' + method + '-pixel value within: [0 - 9]): ', rare
    printf, 12, format=fmt, 'Patchy (' + method + '-pixel value within: [10 - 39]): ', patchy
    printf, 12, format=fmt, 'Transitional (' + method + '-pixel value within: [40 - 59]): ', transitional
    printf, 12, format=fmt, 'Dominant (' + method + '-pixel value within: [60 - 89]): ', dominant    
    if repclass eq '5' then begin
      printf, 12, format=fmt, 'Interior (' + method + '-pixel value within: [90 - 100]): ', interior
    endif else begin
      printf, 12, format=fmt, 'Interior (' + method + '-pixel value within: [90 - 99]): ', interior
      printf, 12, format=fmt, 'Intact (' + method + '-pixel value: 100): ', intact
    endelse
  endif else begin
    printf, 12, 'FOS-' + strmid(fragtype,0,7)  + ': 5 classes:'
    printf, 12, format=fmt, 'Rare (' + method + '-pixel value within: [0 - 9]): ', rare
    printf, 12, format=fmt, 'Patchy (' + method + '-pixel value within: [10 - 39]): ', patchy
    printf, 12, format=fmt, 'Transitional (' + method + '-pixel value within: [40 - 59]): ', transitional
    printf, 12, format=fmt, 'Dominant (' + method + '-pixel value within: [60 - 89]): ', dominant
    printf, 12, format=fmt, 'Interior (' + method + '-pixel value within: [90 - 100]): ', interior
    printf, 12, 'FOS-' + strmid(fragtype,0,7)  + ': 2 classes:'
    printf, 12, format=fmt, 'Separated  (' + method + '-pixel value within: [0 - 39]): ', separated
    printf, 12, format=fmt, 'Continuous (' + method + '-pixel value within: [40 - 100]): ', continuous
  endelse
  printf, 12, '================================================================================'
  if hprec eq '1' then printf, 12, 'Precision: floating point' else printf, 12, 'Precision: rounded byte'
  printf, 12, format=fmt2, 'Average pixel value across all foreground pixels using ' + method + '-method: ', strtrim(fad_av,2)
  printf, 12, format=fmt2, 'Equivalent to average foreground connectivity: ', strtrim(fad_av,2)
  printf, 12, format=fmt2, 'Equivalent to average foreground fragmentation: ', strtrim(100.0-fad_av,2)
  close, 12

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; save stats summary in idl sav format for potential change analysis at some later point
  ;; check if we have a geotiff image
  geotiff_log = '' ;; gdal geotiff-information
  IF is_geotiff GT 0 then spawn, 'unset LD_LIBRARY_PATH; gdalinfo -noct "' + input + '" 2>/dev/null', geotiff_log
  fn_out = outdir + '/' + fbn + '_fos-' + strlowcase(fragtype) + 'class_' + kdim_str + '.sav'
  save, filename = fn_out, fragtype, xdim, ydim, geotiff_log, rare, patchy, transitional, dominant, interior, intact, $
    separated, continuous, fad_av, fgarea, kdim_str, obj_last, conn_str, pixres_str, kdim_str, hec, acr
  

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; write csv output
  fn_out = outdir + '/' + fbn + '_fos-' + strlowcase(fragtype) + 'class_' + kdim_str + '.csv'
  openw,12,fn_out
  w = indgen(nr_cat+1, /string) +',' & w = w[1:*] & cc = '' & for i = 0, nr_cat-1 do cc = cc + w[i]
  printf,12, fragtype + ': FragmClass\ObsScale:, ' + cc
  cat2 = strtrim(cat2, 2) + ',' & cc = '' & for i = 0, nr_cat-1 do cc = cc + cat2[i]
  printf,12, 'Neighborhood area:,', cc

  z = strtrim(rare,2) + ',' & cc = '' & for i = 0, nr_cat-1 do cc = cc + z[i]
  if fosg eq 'FOS' then begin
    printf, 12, repstyle  + ': ' + repclass + ' classes'
    printf, 12, 'Rare:, ' + cc & z = strtrim(patchy,2) + ',' & cc = '' & for i = 0, nr_cat-1 do cc = cc + z[i]
    printf, 12, 'Patchy:, ' + cc & z = strtrim(transitional,2) + ',' & cc = '' & for i = 0, nr_cat-1 do cc = cc + z[i]
    printf, 12, 'Transitional:, ' + cc & z = strtrim(dominant,2) + ',' & cc = '' & for i = 0, nr_cat-1 do cc = cc + z[i]
    printf, 12, 'Dominant:, ' + cc & z = strtrim(interior,2) + ',' & cc = '' & for i = 0, nr_cat-1 do cc = cc + z[i]
    printf, 12, 'Interior:, ' + cc & z = strtrim(intact,2) + ',' & cc = '' & for i = 0, nr_cat-1 do cc = cc + z[i]
    if repclass eq '6' then printf, 12, 'Intact:, ' + cc
  endif else begin
    printf, 12, strmid(fragtype,0,7)  + ': 5 classes:'
    printf, 12, 'Rare:, ' + cc & z = strtrim(patchy,2) + ',' & cc = '' & for i = 0, nr_cat-1 do cc = cc + z[i]
    printf, 12, 'Patchy:, ' + cc & z = strtrim(transitional,2) + ',' & cc = '' & for i = 0, nr_cat-1 do cc = cc + z[i]
    printf, 12, 'Transitional:, ' + cc & z = strtrim(dominant,2) + ',' & cc = '' & for i = 0, nr_cat-1 do cc = cc + z[i]
    printf, 12, 'Dominant:, ' + cc & z = strtrim(interior,2) + ',' & cc = '' & for i = 0, nr_cat-1 do cc = cc + z[i]
    printf, 12, 'Interior:, ' + cc
    printf, 12, strmid(fragtype,0,7)  + ': 2 classes:' & z = strtrim(separated,2) + ',' & cc = '' & for i = 0, nr_cat-1 do cc = cc + z[i]
    printf, 12, 'Separated:, ' + cc & z = strtrim(continuous,2) + ',' & cc = '' & for i = 0, nr_cat-1 do cc = cc + z[i]
    printf, 12, 'Continuous:, ' + cc 
  endelse
  z = strtrim(fad_av,2) + ',' & cc = '' & for i = 0, nr_cat-1 do cc = cc + z[i]
  printf, 12, prec + ', ' + cc
  close,12
  okfile = okfile + 1

  openw, 9, fn_logfile, /append
  printf, 9, ' '
  printf, 9, '==============   ' + counter + '   =============='
  printf, 9, 'File: ' + input
  printf, 9, strupcase(fragtype) + ' comp.time [sec]: ', systime( / sec) - time0
  close, 9
  
  skip_fos: 
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
printf, 9, strupcase(fragtype) + ' Batch Processing total comp.time: ', proctstr
printf, 9, 'Successfully processed files: ',strtrim(okfile,2)+'/'+ strtrim(nr_im_files,2)
printf, 9, '==============================================='
close, 9

print, 'Frag finished sucessfully'

fin:
END
