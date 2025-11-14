PRO GWB_FRAG
;;==============================================================================
;; GWB script for user-selected scale of FAD/FEC/FAC (fragmentation/connectivity)
;;==============================================================================
;; 
;; Purpose: 
;;==============================================================================
;; IDL cmd-line script to conduct flexible FAD/FED/FAC
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
GWB_mv = 'GWB_FRAG (version 2.0.0)'
;;
;; Module changelog:
;; 1.9.9: IDL 9.2.0, add color histogram
;; 1.9.8: calculate AVCON before potential averaging, fixed csv output
;; 1.9.7: increase computing precision, fixed fadru_av to include special BG, AVCON
;; 1.9.6: add gpref, histogram, ECA, IDL 9.1.0
;; 1.9.5: added FED and grayscale input
;; 1.9.4: IDL 9.0.0
;; 1.9.2: IDL 8.9.0
;; 1.9.1: added image size info, statistic output option, SW tag, fixed multiscale statistic output, 
;;        FRAG now replaces the obsolete multiscale FAD 
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
  print,  dir_inputdef + "/input/backup/*parameters.txt, or"
  print, "restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
ENDIF


;;==============================================================================
;; 1a) verify parameter file 
;;==============================================================================
;; read frag settings, we need at least 6 valid lines
fl = file_lines(mod_params)
IF fl LT 7 THEN BEGIN
  print, "The file: " + mod_params + " is in a wrong format."
  print, "Please copy the respective backup file into your input directory:"
  print,  dir_inputdef + "/input/backup/*parameters.txt, or"
  print, "restore the default files using the command: cp -fr /opt/GWB/*put ~/"
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
IF ct LT 6 THEN BEGIN
  print, "The file: " + mod_params + " is in a wrong format."
  print, "Please copy the respective backup file into your input directory:"
  print,  dir_inputdef + "/input/backup/*parameters.txt, or"
  print, "restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
ENDIF

;; get and check parameters
;; 1) frag type
fragtype = strtrim(finp(q[0]), 2)
fragarray = ['FAD_5','FAD_6','FAD-APP_2','FAD-APP_5','FED_5','FED_6','FED-APP_2','FED-APP_5','FAC_5','FAC_6','FAC-APP_2','FAC-APP_5']
qq = where(fragtype eq fragarray)
IF qq LT 0 THEN  BEGIN
  print, "The file: " + mod_params + " is in a wrong format."
  print, 'The selected option is not correct: ' + fragtype
  print, "Select either of: FAD_5,FAD_6,FAD-APP_2,FAD-APP_5,  FED_5,FED_6,FED-APP_2,FED-APP_5,  FAC_5,FAC_6,FAC-APP_2, FAC-APP_5."
  print, "Please copy the respective backup file into your input directory:"
  print,  dir_inputdef + "/input/backup/*parameters.txt, or"
  print, "restore the default files using the command: cp -fr /opt/GWB/*put ~/"
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
  print, "Select either of: FAD_5,FAD_6,FAD-APP_2,FAD-APP_5,  FED_5,FED_6,FED-APP_2,FED-APP_5,  FAC_5,FAC_6,FAC-APP_2, FAC-APP_5."
  print, "Please copy the respective backup file into your input directory:"
  print,  dir_inputdef + "/input/backup/*parameters.txt, or"
  print, "restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
endelse
tvlct, r, g, b
if strlen(fragtype) eq 5 then fosg = 'FOS' else fosg = 'FOS-APP'
method = strmid(fragtype,0,3)
repstyle = method + ' at pixel level' & repstyle2 = method
IF fosg eq 'FOS-APP' then repstyle = method + ' at patch level (APP: average per patch)'
IF fosg eq 'FOS-APP' then repclass = strmid(fragtype,8,1) ELSE repclass = strmid(fragtype,4,1)
fosclass = fragtype

;; 2) FG-connectivity
c_FGconn = strtrim(finp(q[1]), 2)
if c_FGconn eq '8' then begin
  conn_str = '8-conn FG' & conn8 = 1
endif else if c_FGconn eq '4' then begin
  conn_str = '4-conn FG' & conn8 = 0
endif else begin
  print, "The file: " + mod_params + " is in a wrong format."
  print, "Foreground connectivity is not 8 or 4."
  print, "Please copy the respective backup file into your input directory:"
  print,  dir_inputdef + "/input/backup/*parameters.txt, or"
  print, "restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
endelse

;; 3) Pixel resolution
pixres_str = strtrim(finp(q[2]), 2) & pixres = abs(float(pixres_str))
if pixres le 0.000001 then begin
  print, "The file: " + mod_params + " is in a wrong format."
  print, "Pixel resolution [m] seems wonky: " + pixres_str
  print, "Please copy the respective backup file into your input directory:"
  print,  dir_inputdef + "/input/backup/*parameters.txt, or"
  print, "restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
endif
pixres_str = strtrim(pixres, 2)
;; area conversions
pix2hec = ((pixres)^2) / 10000.0
pix2acr = pix2hec * 2.47105

;; 5) high precision?
hprec = strtrim(finp(q[4]), 2) & condition = hprec EQ '0' or hprec EQ '1'
IF condition NE 1b THEN BEGIN
  print, "The file: " + mod_params + " is in a wrong format."
  print, "High precision switch is not 0 or 1."
  print, "Please copy the respective backup file into your input directory:"
  print,  dir_inputdef + "/input/backup/*parameters.txt, or"
  print, "restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
ENDIF
if hprec eq '1' then prec = method+'_av: ' else prec = '(byte)'+method+'_av: '

;; 6) statistics ?
c_stats = strtrim(finp(q[5]), 2)
if c_stats eq '1' then begin
  tstats = 1b & dostats = 'yes'
endif else if c_stats eq '0' then begin
  tstats = 0b & dostats = 'no'
endif else begin
  print, "The file: " + mod_params + " is in a wrong format."
  print, "Statistics is not 1 or 0."
  print, "Please copy the respective backup file into your input directory:"
  print,  dir_inputdef + "/input/backup/*parameters.txt, or"
  print, "restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
endelse

;; 7) input type?
c_inp = strtrim(finp(q[6]), 2)
IF strlowcase(strmid(c_inp,0,6)) EQ 'binary' THEN BEGIN
  fosinp = 'Binary'
ENDIF ELSE IF strlowcase(strmid(c_inp,0,9)) EQ 'grayscale' THEN BEGIN
  fosinp = 'Grayscale'
ENDIF ELSE BEGIN
  print, "The file: " + mod_params + " is in a wrong format."
  print, "input map type must be either Binary or Grayscale."
  print, "Please copy the respective backup file into your input directory:"
  print,  dir_inputdef + "/input/backup/*parameters.txt, or"
  print, "restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
ENDELSE
grayt_str  = ''
IF fosinp EQ 'Grayscale' THEN BEGIN
  grayt_str  = strtrim(strmid(c_inp,9),2)
  ;; test if in [1,100]
  grayt = fix(abs(grayt_str))
  IF (grayt EQ 0) OR (grayt GT 100) THEN BEGIN
    print, "The file: " + mod_params + " is in a wrong format."
    print, "The Grayscale threshold grayt is not in [1, 100]."
    print, "Please copy the respective backup file into your input directory:"
    print,  dir_inputdef + "/input/backup/*parameters.txt, or"
    print, "restore the default files using the command: cp -fr /opt/GWB/*put ~/"
    print, "Exiting..."
    goto,fin
  ENDIF
  grayt = byte(grayt)
ENDIF


;; 4) observation scales, maximum 10
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
  print, "Please copy the respective backup file into your input directory:"
  print,  dir_inputdef + "/input/backup/*parameters.txt, or"
  print, "restore the default files using the command: cp -fr /opt/GWB/*put ~/"
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
;;==============================================================================
;;==============================================================================
;; apply frag settings in a loop over all tif images 
;;==============================================================================
;;==============================================================================
gpref = 'unset LD_LIBRARY_PATH; '
desc = 'GTB_FOS, https://forest.jrc.ec.europa.eu/en/activities/lpa/gtb/'
tagsw = 'TIFFTAG_SOFTWARE='+'"'+"GWB, https://forest.jrc.ec.europa.eu/en/activities/lpa/gwb/" +'" '
gedit = gpref + 'gdal_edit.py -mo ' + tagsw
gedit = gedit + '-mo TIFFTAG_IMAGEDESCRIPTION="'+desc + '" '

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
printf, 9, 'Statistics: ' + dostats
if fosinp eq 'Grayscale' then printf, 9, 'Input map type: ' + fosinp + ', Grayscale threshold: ' + $
  grayt_str else printf, 9, 'Input map type: ' + fosinp
printf, 9, 'Number of files to be processed: ', nr_im_files
printf, 9, '==============================================='
close, 9
;; write out the path to the logfile to append RAM usage later on
fn_dirs2 = strmid(fn_dirs,0,strlen(fn_dirs)-12) + 'gwb_frag_log.txt'
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
  printf, 9, 'up to 20x RAM needed [GB]: ' + strtrim(imsizeGB*20.0,2)
  close, 9
  
  res = strpos(input,' ') ge 0
  IF res EQ 1 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (empty space in directory path or input filename)'
    close, 9
    GOTO, skip_fos  ;; invalid input
  ENDIF
  
 ;; res = query_tiff(input, inpinfo)
  IF inpinfo.type NE 'TIFF' THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (not a TIF image)'
    close, 9
    GOTO, skip_fos  ;; invalid input
  ENDIF
 
  ;; check for single image in file
  IF inpinfo.num_images GT 1 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (more than 1 image in the TIF image) '
    close, 9
    GOTO, skip_fos  ;; invalid input
  ENDIF
  
  ;; get uncompressed image size in MB and check for sufficient disk space for processing
  ;; make sure there is at least 6 times that size left, else exit
  IF hprec EQ '1' THEN reqsize = 8*inpsize ELSE reqsize = 4*inpsize
  spawn, 'df -BM --output=avail ' + dir_output, res
  IF n_elements(res) NE 2 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Problems determining available disk space '
    close, 9
    GOTO, skip_fos  ;; invalid input
  ENDIF
  ;; get free space, strip off the Megabyte sign and convert to float for comparison with reqsize
  res = res [1] & res = strmid(res, 0,strlen(res)-1) & resf=float(res)
  IF resf LT reqsize then BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Insufficent free disk space, ' + res + 'MB needed.'
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
    printf, 9, 'Skipping invalid input (more than 1 band in the TIF image) '
    close, 9
    GOTO, skip_fos  ;; invalid input
  ENDIF

  ;; check for byte array
  ;;===========================
  IF size(im, / type) NE 1 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (image is not of type BYTE) '
    close, 9
    GOTO, skip_fos  ;; invalid input
  ENDIF 
   
  ;; check for correct image dimension
  ;;===================================
  IF imgminsize LT 250 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Image dimension < 250 pixels in x or y image dimension'
    close, 9
    GOTO, skip_fos  ;; invalid input; PV: comment out to test small images
  ENDIF


  IF fosinp EQ 'Binary' THEN BEGIN
    ;; check min/max value in image
    ;;===========================
    mxx = max(im, min = mii)
    IF mxx GT 4b THEN BEGIN
      openw, 9, fn_logfile, /append
      printf, 9, 'Skipping invalid input (Image maximum is larger than 4 BYTE)'
      close, 9
      GOTO, skip_fos  ;; invalid input
    ENDIF ELSE IF mxx LT 2b THEN BEGIN
      openw, 9, fn_logfile, /append
      printf, 9, 'Skipping invalid input (Image has no foreground (2 BYTE))'
      close, 9
      GOTO, skip_fos  ;; invalid input
    ENDIF
    IF mii GT 1b THEN BEGIN
      openw, 9, fn_logfile, /append
      printf, 9, 'Skipping invalid input (Image has no background (1 BYTE)) '
      close, 9
      GOTO, skip_fos  ;; invalid input
    ENDIF
    ;; we must have foreground pixels (2) and we must have BG-pixels (1)
    upv = where(histogram(im, /l64) GT 0)
    q=where(upv eq 2, ct)
    IF ct NE 1 THEN BEGIN
      openw, 9, fn_logfile, /append
      printf, 9, 'No pixels with mandatory FG-data value 2 BYTE found'
      close, 9
      GOTO, skip_fos  ;; invalid input
    ENDIF
    q=where(upv eq 1, ct)
    IF ct NE 1 THEN BEGIN
      openw, 9, fn_logfile, /append
      printf, 9, 'No pixels with mandatory BG-data value 1 BYTE found'
      close, 9
      GOTO, skip_fos  ;; invalid input
    ENDIF    
  ENDIF ELSE BEGIN ;; grayscale
    ;; clustering is not allowed for grayscale
    IF strmid(fosclass,0,3) EQ 'FAC' THEN BEGIN
      openw, 9, fn_logfile, /append
      printf, 9, 'Clustering (FAC) is not applicale to grayscale input maps'
      close, 9
      GOTO, skip_fos  ;; invalid input
    ENDIF
    
  ENDELSE

  good2go:
  ;;==============================================================================
  ;; 2) process for fragtype
  ;;==============================================================================
  ;; cleanup temporary proc directory
  file_delete, dir_proc, /recursive, /quiet, /allow_nonexistent
  file_mkdir, dir_proc
  time0 = systime( / sec)
  
  image0 = temporary(im) & obj_last = -1
  ;; image properties
  IF fosinp EQ 'Binary' THEN BEGIN
    qmiss = where(image0 eq 0b, ctmiss, /l64, complement=ruarea)
    n_ruarea = n_elements(ruarea)
    q3b = where(image0 eq 3b, ct3b, /l64)
    q4b = where(image0 eq 4b, ct4b, /l64)
    BGmask = where(image0 EQ 1b, /l64)
    qFG = where(image0 eq 2b, /l64, fgarea)
    fareaperc=100.0/n_ruarea*fgarea
  ENDIF ELSE BEGIN ;; grayscale
    ;; we must have foreground pixels and we must have BG-pixels
    BGmask = where(image0 LT grayt, ctbg, /l64)
    IF ctbg LT 1 THEN BEGIN
      openw, 9, fn_logfile, /append
      printf, 9, 'No BG pixels found when using grayscale threshold: ' + grayt_str
      close, 9
      GOTO, skip_fos  ;; invalid input
    ENDIF
    tt = image0 GE grayt AND image0 LT 101b & qFG = where(tt eq 1b, /l64, fgarea)
    IF fgarea LT 1 THEN BEGIN
      openw, 9, fn_logfile, /append
      printf, 9, 'No FG pixels found when using grayscale threshold: ' + grayt_str
      close, 9
      GOTO, skip_fos  ;; invalid input
    ENDIF
    qmiss = where(image0 eq 255b,ctmiss, /l64, complement=ruarea) 
    n_ruarea = n_elements(ruarea)
    fareaperc=100.0/n_ruarea*fgarea
    q3b = where(image0 eq 103b, ct3b, /l64) 
    q4b = where(image0 eq 104b, ct4b, /l64)
    IF ct3b GT 0 THEN image0[q3b] = 0b ;; set special BG to zero
    IF ct4b GT 0 THEN image0[q4b] = 255b ;; non-fragmenting specialBG - assign to missing
  ENDELSE
    
  ;; FOS loop over observation scales
  kdim_cat = cat & fad_av_cat = fltarr(nr_cat) & fadru_av_cat = fltarr(nr_cat)
  
  IF (fosg eq 'FOS-APP') OR (tstats eq 1) THEN BEGIN
    ext1 = bytarr(sz[0] + 2, sz[1] + 2)
    IF fosinp EQ 'Binary' THEN BEGIN
      ext1[1:sz[0], 1:sz[1]] = image0 eq 2b
    ENDIF ELSE BEGIN
      ext1[1:sz[0], 1:sz[1]] = long(temporary(tt))
    ENDELSE
    ;; label FG only
    ext1 = ulong(temporary(ext1)) & obj_area = histogram(ext1, /l64)
    ext1 = label_region(temporary(ext1), all_neighbors=conn8, / ulong)
    obj_last = max(ext1) & z80 = strtrim(obj_last,2)
    aps = total(obj_area[1:*],/double) / obj_last & z81 = strtrim(aps,2)
    ;; get pixel indices by patch
    ext1 = histogram(temporary(ext1), reverse_indices = rev, /l64)
    ;; PCnum:= overall connectivity. Sum of [ (areas per component)^2 ]
    pcnum = total(ext1(1: * )^2, / double) & ECA = sqrt(pcnum)
    ECA_max = total(ext1(1: * ), / double) & COH = ECA/ECA_max*100.0
    COH_ru = ECA/n_ruarea*100.0 & ext1=0 
    
    ;; define arrays for cummulative values
    intact_cat = fltarr(nr_cat) & interior_cat = intact_cat & dominant_cat = intact_cat & transitional_cat = intact_cat
    patchy_cat = intact_cat & rare_cat = intact_cat & separated_cat = intact_cat & continuous_cat = intact_cat
    hist2_cat = fltarr(nr_cat,101)
  ENDIF
  
  ;; define output already here to write out each scale image
  fbn = file_basename(list[fidx], '.tif')
  outdir = dir_output + '/' + fbn + '_frag' & file_mkdir, outdir
  proc_spatcon = strmid(fosclass,0,3) EQ 'FAC' OR (strmid(fosclass,0,3) EQ 'FAD' AND fosinp EQ 'Binary')
  
  ;; loop over specified scales
  ;;=========================================================================
  
  for isc = 0, nr_cat-1 do begin
    if isc eq 0 then begin ;; initialise scinput image
      tmp = temporary(image0)
      IF fosinp EQ 'Binary' THEN BEGIN
        IF ct4b GT 0 THEN tmp[q4b] = 0b
      ENDIF ELSE BEGIN
        IF ct4b GT 0 THEN tmp[q4b] = 255b
      ENDELSE      
    endif
    kdim_str = strtrim(kdim_cat[isc],2)
    kdim = kdim_cat[isc]
    
    ;; run spatcon Density (PF) or Clustering (Spatial Convolution metrics by K. Riitters)
    
    IF proc_spatcon EQ 1 THEN BEGIN
      ;; ***************  run spatcon PF (a) or FAC (e)  ***********************
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
        file_copy, dir_gwb + '/spatcon_lin64','spatcon', /overwrite
      endif
      spawn, './spatcon', log

      ;; get result
      im = bytarr(sz(0),sz(1))
      if resfloat eq 1 then im=float(temporary(im))
      openr, 1, 'scoutput' & readu,1, im & close,1

      ;; clean up
      file_delete, 'scoutput','scpars.txt','scsize.txt',/allow_nonexistent,/quiet
      popd

      ;; rescale to normalized byte range
      if resfloat eq 0 then begin
        ;; normally the conversion to byte range would be: im=(im-1b)/254.0 > 0.0
        ;; the potential max value from spatcon is 255b and *only* those pixels can have a remapped value of 100b
        ; we must prevent that the value 254b will get rounded to 100b so mask the 255b pixels
        q = where(im eq 255b, ct, /l64)
        im = (temporary(im) - 1b)*(1.0/254.0) & im = 0.994999 < temporary(im) > 0.0
        im = byte(round(temporary(im) * 100.0))
        if ct gt 0 then im[q] = 100b
      endif else begin
        im = byte(round(temporary(im) * 100.0))
      endelse
    
    ENDIF ELSE BEGIN
      GSC1 = (strmid(fosclass,0,3) EQ 'FAD' AND fosinp EQ 'Grayscale')
      pushd, dir_proc
      ;; ***************  run GSC for (b), (c), or (d) ***********************
      IF GSC1 EQ 1 THEN BEGIN ;; run GSC 1 for case (b)
        close, 1 & openw,1, 'gscpars.txt'
        printf,1,'R ' + strtrim(sz[1],2)
        printf,1,'C ' + strtrim(sz[0],2)
        printf,1,'M 1'
        printf,1,'P 0'
        printf,1,'G 0'
        printf,1,'W ' + kdim_str
        printf,1,'F 1'
        printf,1,'B 6'
        printf,1,'A 1'
        printf,1,'X 5'
        printf,1,'Y 10'
        printf,1,'K 5'
        close,1
      ENDIF ELSE BEGIN ;; run GSC 52 for (c) and (d)
        close, 1 & openw,1, 'gscpars.txt'
        printf,1,'R ' + strtrim(sz[1],2)
        printf,1,'C ' + strtrim(sz[0],2)
        printf,1,'M 52'
        printf,1,'P 0'
        printf,1,'G 0'
        printf,1,'W ' + kdim_str
        printf,1,'F 1'
        printf,1,'B 1'
        printf,1,'A 1'
        printf,1,'X 5'
        printf,1,'Y 10'
        printf,1,'K 5'
        close,1
        ;; amend image setup for GSC processing
        ;; 1) set all BG to zero
        tmp[BGmask] = 0b
        IF fosinp EQ 'Binary' THEN BEGIN ;; case (c)
          tmp[qFG] = 100b
          tmp[qmiss] = 255b
          IF ct3b GT 0 THEN tmp[q3b] = 0b ;; set special BG to zero
          IF ct4b GT 0 THEN tmp[q4b] = 255b ;; non-fragmenting specialBG - assign to missing
        ENDIF
      ENDELSE
      
      if isc eq 0 then begin
        openw, 1, 'gscinput' & writeu,1, tmp & close, 1 & tmp = 0
        file_copy, dir_gwb + '/grayspatcon_lin64','grayspatcon', /overwrite
      endif
      spawn, './grayspatcon', log

      ;; get result
      ;; if we get a GraySpatCon error then the last entry will not be "Normal Finish"
      res = log[n_elements(log)-1] & res = strpos(strlowcase(res), 'normal finish') gt 0
      if res eq 0 then begin
        file_delete, 'gscinput','gscoutput','gscoutput.txt','gscpars.txt', /allow_nonexistent,/quiet
        openw, 9, fn_logfile, /append
        printf, 9, 'GSC error'
        for idd = 1, n_elements(log)-1 do printf, 9, log[idd]     
        close, 9
        popd
        GOTO, skip_fos  ;; invalid input
      endif
      ;; read the image output
      im = bytarr(sz(0),sz(1))
      openr, 1, 'gscoutput' & readu,1, im & close,1
      file_delete, 'gscoutput','gscpars.txt', /allow_nonexistent,/quiet      
      popd
    ENDELSE 
    
    ;; build the statistics BEFORE doing APP so they are consistent with non-APP
    fad_av = mean(im[qFG]) & fad_av_cat[isc] = fad_av
    fadru_av = fad_av*fgarea/n_ruarea & fadru_av_cat[isc] = fadru_av

    
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
    
    ;; write out the single scale image
    fn_out = outdir + '/' + fbn + '_fos-' + strlowcase(fragtype) + 'class_' + kdim_str + '.tif'
    ;; add the geotiff info if available
    IF is_geotiff GT 0 THEN $
      write_tiff, fn_out, rotate(im,7), red = r, green = g, blue = b, geotiff = geotiff, compression = 1 ELSE $
      write_tiff, fn_out, rotate(im,7), red = r, green = g, blue = b, compression = 1
    spawn, gedit + fn_out + ' > /dev/null 2>&1'


    if tstats eq 0 then goto, nostats        
    ;; a) build histogram
    hist = histogram(im[qFG],/l64) & hist = hist[0:100]
    if strlen(fosclass) eq 5 then begin
      method = strmid(fosclass,0,3) & rep = strmid(fosclass,4,1)
    endif else begin
      method = strmid(fosclass,0,7) & rep = strmid(fosclass,8,1)
    endelse
    bins = findgen(101)-0.5 & xtit = method & tit = 'Foreground pixel histogram (WS: ' + kdim_str + ')'    
    ;; plot as percentage by FG-area
    hist2 = float(hist)/n_elements(qfg)*100.0 & bmax = max(hist2) * 1.05 & hist2_cat[isc,*] = hist2
    
    IF rep EQ '5' THEN BEGIN
      bp = barplot(bins[0:9], hist2[0:9], fill_color=[215,50,40], xtitle=xtit, /buffer, thick=0, $
        ytitle = 'Frequency [%]', title = tit, xrange = [0,105], yrange = [0, bmax],histogram=1, font_size=12) ;; very low
      bp = barplot(bins[10:39], hist2[10:39], fill_color = [250,140,90],thick=0,histogram=1, /overplot) ;; low
      bp = barplot(bins[40:59], hist2[40:59], fill_color = [255,200,0],thick=0,histogram=1, /overplot) ;; intermediate
      bp = barplot(bins[60:89], hist2[60:89], fill_color = [140,200,100],thick=0,histogram=1, /overplot) ;; high
      bp = barplot(bins[90:100], hist2[90:100], fill_color = [0,175,0],thick=0,histogram=1, /overplot) ;; very high
    ENDIF ELSE IF rep EQ '6' THEN BEGIN
      bp = barplot(bins[0:9], hist2[0:9], fill_color=[215,50,40], xtitle=xtit, /buffer, thick=0, $
        ytitle = 'Frequency [%]', title = tit, xrange = [0,105], yrange = [0,bmax],histogram=1, font_size=12)
      bp = barplot(bins[10:39], hist2[10:39], fill_color = [250,140,90],thick=0,histogram=1, /overplot) ;; low
      bp = barplot(bins[40:59], hist2[40:59], fill_color = [255,200,0],thick=0,histogram=1, /overplot) ;; intermediate
      bp = barplot(bins[60:89], hist2[60:89], fill_color = [140,200,100],thick=0,histogram=1, /overplot) ;; high
      bp = barplot(bins[90:99], hist2[90:99], fill_color = [0,175,0],thick=0,histogram=1, /overplot) ;; very high
      bp = barplot(bins[100:100], hist2[100:100], fill_color = [0,120,0],thick=0,histogram=1, /overplot) ;; intact
    ENDIF ELSE IF rep EQ '2' THEN BEGIN
      bp = barplot(bins[0:39], hist2[0:39], fill_color=[0,120,0], xtitle=xtit, /buffer, thick=0, $
        ytitle = 'Frequency [%]', title = tit, xrange = [0,105], yrange = [0,bmax],histogram=1, font_size=12)
      bp = barplot(bins[40:100], hist2[40:100], fill_color = [140,200, 101],thick=0,histogram=1, /overplot) ;; low
    ENDIF

    fn_out = outdir + '/' + fbn + '_fos-' + strlowcase(fragtype) + 'class_' + kdim_str + '.png'
    bp.save, fn_out, resolution=300
    bp.close
    
    ;; b) do the grouping
    intact = -1.0 & interior = intact & dominant = intact & transitional = intact  & patchy = intact
    rare = intact & continuous = intact & separated = intact
    if fosg eq 'FOS' then begin
      ;; get the 5 fragmentation proportions (the 6th, rare, is always 100.0%)
      if strmid(fragtype,4,1) eq '6' then begin
        zz = (im EQ 100b) & intact = total(zz,/double)/fgarea*100.0 & intact_cat[isc] = intact
        zz = (im GE 90b) AND (im LT 100b) & interior = total(zz,/double)/fgarea*100.0 & interior_cat[isc] = interior
      endif else begin
        zz = (im GE 90b) AND (im LE 100b) & interior = total(zz,/double)/fgarea*100.0 & interior_cat[isc] = interior
      endelse
      zz = (im GE 60b) AND (im LT 90b) & dominant = total(zz,/double)/fgarea*100.0 & dominant_cat[isc] = dominant
      zz = (im GE 40b) AND (im LT 60b) & transitional = total(zz,/double)/fgarea*100.0 & transitional_cat[isc] = transitional
      zz = (im GE 10b) AND (im LT 40b) & patchy = total(zz,/double)/fgarea*100.0 & patchy_cat[isc] = patchy
      zz = (im LT 10b) & rare = total(zz,/double)/fgarea*100.0 & zz = 0 & rare_cat[isc] = rare
    endif else begin ;; output 5-class as well as 2-class
      zz = (im GE 90b) AND (im LE 100b) & interior = total(zz,/double)/fgarea*100.0 & interior_cat[isc] = interior
      zz = (im GE 60b) AND (im LT 90b) & dominant = total(zz,/double)/fgarea*100.0 & dominant_cat[isc] = dominant
      zz = (im GE 40b) AND (im LT 60b) & transitional = total(zz,/double)/fgarea*100.0 & transitional_cat[isc] = transitional
      zz = (im GE 10b) AND (im LT 40b) & patchy = total(zz,/double)/fgarea*100.0 & patchy_cat[isc] = patchy
      zz = (im LT 10b) & rare = total(zz,/double)/fgarea*100.0 & rare_cat[isc] = rare
      zz = (im GE 40b) AND (im LE 100b) & continuous = total(zz,/double)/fgarea*100.0 & continuous_cat[isc] = continuous
      zz = (im LT 40b) & separated = total(zz,/double)/fgarea*100.0 & zz = 0 & separated_cat[isc] = separated
    endelse
    ;; c) save stats summary in idl sav format for potential change analysis at some later point
    hec = ((pixres * kdim)^2) / 10000.0 & acr = hec * 2.47105 & geotiff_log = ''
    IF is_geotiff GT 0 then spawn, 'unset LD_LIBRARY_PATH; gdalinfo -noct "' + input + '" 2>/dev/null', geotiff_log
    fn_out = outdir + '/' + fbn + '_fos-' + strlowcase(fragtype) + 'class_' + kdim_str + '.sav'
    save, filename = fn_out, grayt_str, fragtype, xdim, ydim, geotiff_log, rare, patchy, transitional, dominant, interior, intact, $
      separated, continuous, fad_av, fadru_av, fgarea, kdim_str, obj_last, conn_str, pixres_str, kdim, hec, acr
    nostats: 
  endfor    ;; end of isc scale loop  
  
  ;; cleanup temporary proc directory and the masks for the current image
  file_delete, dir_proc, /recursive, /quiet, /allow_nonexistent
  qmiss = 0 & q3b = 0 & q4b = 0 & BGmask = 0 & qFG = 0
  if tstats eq 0 then begin
     ruarea = 0 & goto, skipstats 
  endif
  
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; d) write out the statistics table as plain text file
  ;;=======================================
  fn_out = outdir + '/' + fbn + '_fos-' + strlowcase(fragtype) + 'class.txt'
  openw,12,fn_out
  printf, 12, 'Fragmentation analysis using Fixed Observation Scale (FOS)'
  printf, 12, '(Fragmentation is complementary to Connectivity: Fragmentation = 100% - Connectivity)
  printf, 12, 'Method options: FAD - FG Area Density; FED - FG Edge Density; FAC - FG Area Clustering;'
  printf, 12, 'Summary analysis for image: '
  printf, 12, file_basename(input)
  printf, 12, '================================================================================'
  IF hprec EQ '1' THEN printf, 12, 'Precision: floating point' else printf, 12, 'Precision: rounded byte'
  IF fosinp EQ 'Binary' THEN tt = '[4b]' ELSE tt = '[104b]'
  IF ct4b GT 0 THEN printf, 12, 'Non-fragmenting background pixels ' + tt + ' in input image'
  printf, 12, 'FOS parameter settings:'
  IF fosinp EQ 'Grayscale' THEN tt = 'Input type: Grayscale (FG threshold: ' + grayt_str + ')' ELSE tt = 'Input type: ' + fosinp
  printf, 12, tt  
  printf, 12, 'Foreground connectivity: ' + conn_str
  printf, 12, 'FOS-type selected: ' + fosclass
  printf, 12, 'Method: ' + method
  printf, 12, 'Reporting style: ' + repstyle
  printf, 12, 'Number of reporting classes: ' + repclass
  printf, 12, 'Pixel resolution [m]: ' + pixres_str
  ws_cat = strarr(nr_cat)
  for id = 0, nr_cat -1 do ws_cat[id] = '   ' + strtrim(cat[id],2)
  cc = '' & for i = 0, nr_cat-1 do cc = cc + ws_cat[i]
  ccws = cc
  printf, 12, 'Window size [pixels]: ' + ccws
  printf, 12, 'Observation scale [(window size * pixel resolution)^2]: '
  ;; Observation scales
  w = indgen(nr_cat)+1 & if nr_cat gt 1 then w = w[1:*]
  if nr_cat eq 1 then printf, 12, format='(a24)','Observation scale:   1' else $
    printf, 12, format='(a23,9(i11))','Observation scale:    1', w

  ;; observation area
  cat2 = strarr(nr_cat)
  for id = 0, nr_cat -1 do cat2[id] = '   ' + strtrim(cat[id],2) + 'x' + strtrim(cat[id],2) + '   '
  cat2[0] = cat2[0] + '  '
  printf, 12, format = '(a18, 10(A))','Neighborhood area:',cat2

  ;; area conversions
  hec = ((pixres * kdim_cat)^2) / 10000.0 & acr = hec * 2.47105
  printf, 12, format = '(a15, 10(f11.2))','[hectare]:', hec
  printf, 12, format = '(a15, 10(f11.2))','[acres]:', acr
  printf, 12, '================================================================================'
  printf, 12, 'Proportion [%] of foreground area in foreground cover class:'
  fmt = '(a55,'+strtrim(nr_cat,2)+'(f11.4))'
  if fosg eq 'FOS' then begin    
    ;if fragtype eq 'FOS6' then printf, 12, 'FOS 6-class:' else printf, 12, 'FOS 5-class:'    
    printf, 12, format=fmt, 'Rare (' + method + '-pixel value within: [0 - 9]): ', rare_cat
    printf, 12, format=fmt, 'Patchy (' + method + '-pixel value within: [10 - 39]): ', patchy_cat
    printf, 12, format=fmt, 'Transitional (' + method + '-pixel value within: [40 - 59]): ', transitional_cat
    printf, 12, format=fmt, 'Dominant (' + method + '-pixel value within: [60 - 89]): ', dominant_cat 
    if repclass eq '5' then begin
      printf, 12, format=fmt, 'Interior (' + method + '-pixel value within: [90 - 100]): ', interior_cat
    endif else begin
      printf, 12, format=fmt, 'Interior (' + method + '-pixel value within: [90 - 99]): ', interior_cat
      printf, 12, format=fmt, 'Intact (' + method + '-pixel value: 100): ', intact_cat
    endelse
  endif else begin
    printf, 12, format=fmt, 'Rare (' + method + '-pixel value within: [0 - 9]): ', rare_cat
    printf, 12, format=fmt, 'Patchy (' + method + '-pixel value within: [10 - 39]): ', patchy_cat
    printf, 12, format=fmt, 'Transitional (' + method + '-pixel value within: [40 - 59]): ', transitional_cat
    printf, 12, format=fmt, 'Dominant (' + method + '-pixel value within: [60 - 89]): ', dominant_cat
    printf, 12, format=fmt, 'Interior (' + method + '-pixel value within: [90 - 100]): ', interior_cat
    printf, 12, 'FOS-' + strmid(fragtype,0,7)  + ': 2 classes:'
    printf, 12, format=fmt, 'Separated  (' + method + '-pixel value within: [0 - 39]): ', separated_cat
    printf, 12, format=fmt, 'Continuous (' + method + '-pixel value within: [40 - 100]): ', continuous_cat
  endelse
  printf, 12, '================================================================================'
  printf, 12, '================================================================================'
  printf, 12, 'A) Image summary:'
  printf, 12, '================================================================================'
  printf, 12, 'Reporting unit area [pixels]: ', strtrim(n_ruarea,2)
  printf, 12, 'Foreground area [pixels]: ', strtrim(fgarea,2)
  printf, 12, 'Foreground area [%]: ', strtrim(fareaperc,2)
  printf, 12, 'Number of foreground patches: ',  z80
  printf, 12, 'Average foreground patch size [pixels]: ', z81
  printf, 12, '================================================================================'
  printf, 12, 'B) Reporting levels'
  printf, 12, '================================================================================'
  printf, 12, 'Foreground (FG) connectivity is available at 4 reporting levels, B1 - B4:'
  printf, 12, 'B1) Pixel-level: method FAD/FED/FAC: check the FG pixel value on the map, or aggregated at'
  printf, 12, 'B2) Patch-level: method _APP (Average-Per-Patch): check the FG pixel value on the map'
  printf, 12, 'B3) Foreground-level: reference area = all foreground pixels'
  printf, 12, format='(a24,'+strtrim(nr_cat,2)+'(f11.4))','- Average ' + method + ' at WS [%]: ', strtrim(fad_av_cat,2)
  printf, 12, '- ECA (Equivalent Connected Area) [pixels]: ', strtrim(ECA,2)  
  printf, 12, '- COH (Coherence = ECA/ECA_max*100) [%]: ', strtrim(COH,2)
  printf, 12, 'B4) Reporting unit-level: reference area = entire reporting unit'
  printf, 12, format='(a42,'+strtrim(nr_cat,2)+'(f11.4))','- AVCON (average connectivity) at WS [%]: ', strtrim(fadru_av_cat,2)
  printf, 12, '- COH_ru (ECA/Reporting unit area*100) [%]: ', strtrim(COH_ru,2)
  printf, 12, '================================================================================'
  printf, 12, '================================================================================'
  printf, 12, 'Histogram of FG-pixel values rounded to the nearest integer, FGcover[%] at window size:'
  fmt3 = '(a6,' + strtrim(nr_cat,2)+'(f11.4))'
  cc = '' & for i = 0, nr_cat-1 do cc = cc + '   WS' + strtrim(ws_cat[i],2) + '    '
  printf, 12, 'Value ' + cc
  For id = 0, 100 do printf, 12, format=fmt3, strtrim(id,2), hist2_cat[*,id]
  close, 12

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; e) write out the statistics table as csv 
  ;;=======================================
  fn_out = outdir + '/' + fbn + '_fos-' + strlowcase(fragtype) + 'class.csv'
  openw,12,fn_out
  w = indgen(nr_cat+1, /string) +',' & w = w[1:*] & cc = '' & for i = 0, nr_cat-1 do cc = cc + w[i]
  IF fosinp EQ 'Grayscale' THEN tt = 'Grayscale_' + grayt_str ELSE tt = fosinp
  printf,12, tt + ' ' + fragtype + ': FragmClass\ObsScale:, ' + cc
  cat2 = strtrim(cat2, 2) + ',' & cc = '' & for i = 0, nr_cat-1 do cc = cc + cat2[i]
  printf,12, 'Neighborhood area [pixels]:,', cc
  hec = strtrim(hec, 2) + ',' & cc = '' & for i = 0, nr_cat-1 do cc = cc + hec[i]
  printf,12, 'Neighborhood area [hectares]:,', cc
  acr = strtrim(acr, 2) + ',' & cc = '' & for i = 0, nr_cat-1 do cc = cc + acr[i]
  printf,12, 'Neighborhood area [acres]:,', cc

  z = strtrim(rare_cat,2) + ',' & cc = '' & for i = 0, nr_cat-1 do cc = cc + z[i]
  if fosg eq 'FOS' then begin
    printf, 12, repstyle  + ': ' + repclass + ' classes'
    printf, 12, 'Rare:, ' + cc & z = strtrim(patchy_cat,2) + ',' & cc = '' & for i = 0, nr_cat-1 do cc = cc + z[i]
    printf, 12, 'Patchy:, ' + cc & z = strtrim(transitional_cat,2) + ',' & cc = '' & for i = 0, nr_cat-1 do cc = cc + z[i]
    printf, 12, 'Transitional:, ' + cc & z = strtrim(dominant_cat,2) + ',' & cc = '' & for i = 0, nr_cat-1 do cc = cc + z[i]
    printf, 12, 'Dominant:, ' + cc & z = strtrim(interior_cat,2) + ',' & cc = '' & for i = 0, nr_cat-1 do cc = cc + z[i]
    printf, 12, 'Interior:, ' + cc & z = strtrim(intact_cat,2) + ',' & cc = '' & for i = 0, nr_cat-1 do cc = cc + z[i]
    if repclass eq '6' then printf, 12, 'Intact:, ' + cc
  endif else begin
    printf, 12, strmid(fragtype,0,7)  + ': 5 classes:'
    printf, 12, 'Rare:, ' + cc & z = strtrim(patchy_cat,2) + ',' & cc = '' & for i = 0, nr_cat-1 do cc = cc + z[i]
    printf, 12, 'Patchy:, ' + cc & z = strtrim(transitional_cat,2) + ',' & cc = '' & for i = 0, nr_cat-1 do cc = cc + z[i]
    printf, 12, 'Transitional:, ' + cc & z = strtrim(dominant_cat,2) + ',' & cc = '' & for i = 0, nr_cat-1 do cc = cc + z[i]
    printf, 12, 'Dominant:, ' + cc & z = strtrim(interior_cat,2) + ',' & cc = '' & for i = 0, nr_cat-1 do cc = cc + z[i]
    printf, 12, 'Interior:, ' + cc
    printf, 12, strmid(fragtype,0,7)  + ': 2 classes:' & z = strtrim(separated_cat,2) + ',' & cc = '' & for i = 0, nr_cat-1 do cc = cc + z[i]
    printf, 12, 'Separated:, ' + cc & z = strtrim(continuous_cat,2) + ',' & cc = '' & for i = 0, nr_cat-1 do cc = cc + z[i]
    printf, 12, 'Continuous:, ' + cc 
  endelse
  printf, 12, ' ' 
  printf, 12, 'A) Image summary:'
  printf, 12, 'Reporting unit area [pixels]:, ' + strtrim(n_ruarea,2)
  printf, 12, 'Foreground area [pixels]:, ' + strtrim(fgarea,2)
  printf, 12, 'Foreground area [%]:, ' + strtrim(fareaperc,2)
  printf, 12, 'Number of foreground patches:, ' +  z80
  printf, 12, 'Average foreground patch size [pixels]:, ' + z81
  z = strtrim(fad_av_cat,2) + ',' & cc = '' & for i = 0, nr_cat-1 do cc = cc + z[i]
  printf, 12, ' '
  printf, 12, 'B) Reporting levels'
  printf, 12, 'B3) Foreground-level:'
  sss = strmid(method,0,3)
  IF strlen(method) EQ 3 THEN sstr = '- Average ' + sss + ' at window size [%]:,' ELSE sstr = '- Average ' + sss + ' (before APP) at window size [%]:,'   
  printf, 12, sstr + cc
  printf, 12, '- ECA [pixels]:, ' + strtrim(ECA,2)
  printf, 12, '- COH [%]:, ' + strtrim(COH,2)
  printf, 12, 'B4) Reporting unit-level:'
  z = strtrim(fadru_av_cat,2) + ',' & cc = '' & for i = 0, nr_cat-1 do cc = cc + z[i]
  printf, 12, '- AVCON (average connectivity) at window size [%]:,' + cc
  printf, 12, '- COH_ru [%]:, ' + strtrim(COH_ru,2)
  printf, 12, ' '
  cc = '' & for i = 0, nr_cat-1 do cc = cc + 'WS' + strtrim(ws_cat[i],2) + ','
  printf, 12, 'FGcover histogram [%] at window size,' + cc
  cc = '' & for i = 0, nr_cat-1 do cc = cc + strtrim(hist2_cat[i,0],2)+ ',' 
  printf, 12, 'Pixel Value   0',', ',cc
  For id = 1, 100 do begin
    cc = '' & for i = 0, nr_cat-1 do cc = cc + strtrim(hist2_cat[i,id],2)+ ','
    printf, 12, strtrim(id,2), ',',cc 
  endfor
  close,12
  
  skipstats:
  okfile = okfile + 1

  openw, 9, fn_logfile, /append
  printf, 9, strupcase(fragtype) + ' comp.time [sec]: ', systime( / sec) - time0
  close, 9
  
  skip_fos: 
  print, 'Done with: ' + file_basename(input)
  
ENDFOR

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
printf, 9, 'FRAG Batch Processing total comp.time: ', proctstr
printf, 9, 'Successfully processed files: ',strtrim(okfile,2)+'/'+ strtrim(nr_im_files,2)
printf, 9, '==============================================='
close, 9

print, 'Frag finished sucessfully'

fin:
END
