PRO GWB_LM
;;==============================================================================
;;         GWB APP for Landscape Mosaic (LM)
;;==============================================================================
;; 
;; Purpose: 
;;==============================================================================
;; IDL cmd-line app to conduct LM as implemented in GuidosToolbox (GTB)
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
;;       E-mail: Peter.Vogt@ec.europa.eu

;;==============================================================================
GWB_mv = 'GWB_LM (version 1.9.5)'
;;
;; Module changelog:
;; 1.9.4: IDL 9.0.0
;; 1.9.3: added loop with up to 10 window sizes
;; 1.9.2: IDL 8.9.0
;; 1.9.1: added image size info, SW tag
;; 1.9.0: added note to restore files, IDL 8.8.3
;; 1.8.8: flexible input reading
;; 1.8.7: IDL 8.8.2 & fixed standalone execution
;; 1.8.6: added mod_params check
;; 1.8.4: rearranged processing sequence
;; 1.8.1: fixed csv output
;; 1.8  : added 103class legend
;; 1.6  : nocheck
;; 1.5  : added 103class output image
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
;; 1 byte: Agricultural pixels
;; 2 byte: Natural pixels
;; 3 byte: Developed pixels
;;
;; b) lm-parameters.txt: (see header info in input/lm-parameters.txt)
;;  - moving window size [pixels]
;;
;;==============================================================================
;; Output: in the subfolder "output"
;;==============================================================================
;; a) LM summary statistics, heatmap, triangle chart and csv-statistics
;; b) geotiff formatted color-coded image with up to 19 LM classes and 103 subclasses grey-scale
;;
;; Processing steps:
;; 1) verify parameter file and compatibility of input image
;; 2) process for LM
;; 3) post-process (write-out and dostats)
;;
;;==============================================================================
;;==============================================================================
device, decomposed = 0

;; initial system checks
;;
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
print,'GWB_LM using:'
if standalone eq 1 then dir_input = dir_inputdef + "/input"
if standalone eq 1 then dir_output = dir_inputdef + "/output"
print, 'dir_input= ', dir_input 
print, 'dir_output= ', dir_output

;; restore colortable
IF (file_info('idl/lmcolors.sav')).exists EQ 0b THEN BEGIN
  print, "The file 'tools/idl/lmcolors.sav' was not found."
  print, "Restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
ENDIF
restore, 'idl/lmcolors.sav' & tvlct, r, g, b

;; verify to have tif image(s) (should be a geotiff)
pushd, dir_input & list = file_search('*.tif', count=ct_tifs) & popd
IF ct_tifs EQ 0 THEN BEGIN
  print, "The input directory does not contain an image with the extension '.tif'"
  print, 'Please copy your geotiff image here.'
  print, "Exiting..."
  goto,fin
ENDIF
mod_params = dir_input + '/lm-parameters.txt'
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
;; read LM settings: moving window size, we need at least 1 valid line
fl = file_lines(mod_params)
IF fl LT 1 THEN BEGIN
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
IF ct LT 1 THEN BEGIN
  print, "The file: " + mod_params + " is in a wrong format."
  print, "Please copy the respective backup file into your input directory:"
  print,  dir_inputdef + "/input/backup/*parameters.txt, or"
  print, "restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
ENDIF
;; get and check observation scales, maximum 10
ptype_str = 'LM'
ath = strtrim(finp(q[0]), 2)
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
  print, "Moving window size is not in [3, 5, 7, ..., 501]."
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
;; cleanup temporary proc directory
file_delete, dir_proc, /recursive, /quiet, /allow_nonexistent
file_mkdir, dir_proc

;;==============================================================================
;;==============================================================================
;; apply lm settings in a loop over all tif images 
;;==============================================================================
;;==============================================================================
desc = 'GTB_LM, https://forest.jrc.ec.europa.eu/en/activities/lpa/gtb/'
tagsw = 'TIFFTAG_SOFTWARE='+'"'+"GWB, https://forest.jrc.ec.europa.eu/en/activities/lpa/gwb/" +'" '
gedit = 'unset LD_LIBRARY_PATH; gdal_edit.py -mo ' + tagsw
gedit = gedit + '-mo TIFFTAG_IMAGEDESCRIPTION="'+desc + '" '

fn_logfile = dir_output + '/lm.log'
nr_im_files = ct_tifs & time00 = systime( / sec) & okfile = 0l
nocheck = file_info(dir_input + '/nocheck.txt') & nocheck = nocheck.exists

openw, 9, fn_logfile
if nocheck eq 0 then printf,9,GWB_mv else printf,9, GWB_mv + ' - nocheck'
printf, 9, ptype_str + ' batch processing logfile: ', systime()
cat3 = strtrim(cat, 2) + ',' & cc = '' & for i = 0, nr_cat-1 do cc = cc + cat3[i]
printf, 9, 'Window size: ' + cc
printf, 9, 'Number of files to be processed: ', nr_im_files
printf, 9, '==============================================='
close, 9
;; write out the path to the logfile to append RAM usage later on
fn_dirs2 = strmid(fn_dirs,0,strlen(fn_dirs)-12) + 'gwb_lm_log.txt'
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
  printf, 9, 'up to 9x RAM needed [GB]: ' + strtrim(imsizeGB*9.0,2)
  close, 9
  
  res = strpos(input,' ') ge 0
  IF res EQ 1 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (empty space in directory path or input filename)'
    close, 9
    GOTO, skip_lm  ;; invalid input
  ENDIF
  
  res = query_tiff(input, inpinfo)
  IF inpinfo.type NE 'TIFF' THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (not a TIF image)'
    close, 9
    GOTO, skip_lm  ;; invalid input
  ENDIF
 
  ;; check for single image in file
  IF inpinfo.num_images GT 1 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (more than 1 image in the TIF image)'
    close, 9
    GOTO, skip_lm  ;; invalid input
  ENDIF

  ;; read it
  geotiff = 0
  im0 = read_tiff(input, geotiff=geotiff) & is_geotiff = (size(geotiff))[0]
  sz=size(im0,/dim) & xdim=sz[0] & ydim=sz[1] & imgminsize=(xdim<ydim)
  IF nocheck EQ 1b THEN goto, good2go

  ;; check for single channel image
  ;;===========================
  IF size(im0, / n_dim) NE 2 THEN BEGIN
    openw, 9, fn_logfile, /append
   printf, 9, 'Skipping invalid input (more than 1 band in the TIF image)'
    close, 9
    GOTO, skip_lm  ;; invalid input
  ENDIF

  ;; check for byte array
  ;;===========================
  IF size(im0, / type) NE 1 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (image is not of type BYTE)'
    close, 9
    GOTO, skip_lm  ;; invalid input
  ENDIF
  
  IF cat[nr_cat -1 ] ge imgminsize THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Kernel dimension larger than x or y image dimension'
    close, 9
    GOTO, skip_lm  ;; invalid input
  ENDIF

  ;; check min/max value in image
  ;;===========================
  mxx = max(im0, min = mii)
  IF mxx GT 3b THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (Image maximum is larger than 3 BYTE)'
    close, 9
    GOTO, skip_lm  
  ENDIF
  
  good2go:
  ;;==============================================================================
  ;; 2) process for LM
  ;;============================================================================== 
  fbn = file_basename(list[fidx], '.tif')
  outdir = dir_output + '/' + fbn + '_lm' & file_mkdir, outdir
  
  ;; image properties
  qmiss = where(im0 eq 0b,ctmiss, /l64) 
  
  
  ;; LM loop over observation scales
  kdim_cat = cat

   for isc = 0, nr_cat-1 do begin
     kdim_str = strtrim(kdim_cat[isc],2)
     kdim = kdim_cat[isc]
     time0 = systime( / sec)
     
     ;; run spatcon LM (Spatial Convolution metrics by K.Riitters)
     pushd, dir_proc
     mstr = '7' & resfloat = 0
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

     openw, 1, 'scinput' & writeu,1, im0 & close,1 
     file_copy, dir_gwb + '/spatcon_lin64', 'spatcon', /overwrite
     spawn, './spatcon', log
     ;; get the 103 classes result
     im103 = bytarr(sz(0),sz(1))
     openr, 1, 'scoutput'  & readu,1, im103 & close,1
     if ctmiss gt 0 then im103[qmiss] = 0b  ;;zero out missing pixels

     ;;================================================================================
     popd ;; return to normal pushd, dir_proc
     ;; calculate the heatmap from the im103 image
     ;;================================================================================
     ;; get unique frequencies excluding the missing pixels (0)
     hist = histogram(im103, /l64) ;; the frequencies for each class
     tot = total(hist[1:236]) & hn = hist/tot*100.0 & eps = 0.000005 & hmax = max(hn[1:*])
     ;; we are using the lm-colours! 20-black, 1-blue , 2-red, 17-darkgreen
     ;; white (0) no number if not present
     ;; black (20) if not hmax
     ;; invert black on white for hmax

     a = FINDGEN(49) * (!PI*2/48.) & USERSYM, COS(A), SIN(A), /FILL ;; define a circle, to use: symsize=8

     tri = read_png('idl/triangle.png') & szt = size(tri,/dim)
     window, 11, xsize=szt[1], ysize=szt[2], /pixmap, retain=2 & tv, tri, /true

     ;; row 1
     y1 = 225 & y2 = 270
     subt = hn[191] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 280,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 280,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[192] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 355,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 355,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[71] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 425,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 425,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[72] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 495,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 495,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[73] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 570,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 570,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[74] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 640,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 640,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[75] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 710,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 710,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[131] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 785,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 785,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[132] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 855,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 855,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[133] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 927,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 927,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[134] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1000,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1000,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[135] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1070,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1070,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[45] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1142,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1142,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[44] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1215,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1215,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[43] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1285,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1285,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[42] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1355,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1355,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[41] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1425,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1425,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[182] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1500,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1500,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[181] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1570,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1570,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device

     ;; row 2
     y1 = 350 & y2 = 395
     subt = hn[61] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 355,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 355,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[62] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 425,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 425,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[111] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 495,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 495,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[112] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 570,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 570,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[114] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 640,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 640,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[200] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 710,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 710,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[201] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 785,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 785,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[202] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 855,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 855,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[203] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 927,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 927,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[204] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1000,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1000,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[205] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1070,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1070,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[206] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1142,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1142,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[103] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1215,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1215,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[102] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1285,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1285,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[101] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1355,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1355,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[52] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1425,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1425,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[51] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1500,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1500,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device

     ;; row 3
     y1 = 475 & y2 = 520
     subt = hn[63] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 427,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 427,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[64] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 495,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 495,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[113] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 570,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 570,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[222] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 640,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 640,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[223] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 710,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 710,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[224] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 785,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 785,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[225] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 855,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 855,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[226] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 927,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 927,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[227] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1000,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1000,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[228] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1070,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1070,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[207] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1142,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1142,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[208] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1215,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1215,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[104] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1285,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1285,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[54] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1355,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1355,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[53] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1425,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1425,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device

     ;; row 4   delta:   125
     y1 = 600 & y2 = 645
     subt = hn[65] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 495,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 495,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[155] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 570,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 570,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[221] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 640,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 640,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[220] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 710,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 710,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[235] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 785,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 785,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[234] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 855,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 855,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[236] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 927,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 927,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[230] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1000,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1000,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[229] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1070,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1070,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[210] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1142,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1142,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[209] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1215,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1215,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[141] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1285,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1285,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[55] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1355,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1355,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device

     ;; row 5   delta:   125
     y1 = 725 & y2 = 770
     subt = hn[154] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 570,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 570,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[153] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 640,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 640,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[219] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 710,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 710,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[218] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 785,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 785,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[233] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 855,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 855,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[232] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 927,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 927,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[231] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1000,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1000,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[212] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1070,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1070,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[211] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1142,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1142,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[143] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1215,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1215,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[142] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1285,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1285,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device

     ;; row 6   delta:   125
     y1 = 850 & y2 = 895
     subt = hn[152] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 640,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 640,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[151] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 710,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 710,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[217] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 785,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 785,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[216] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 855,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 855,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[215] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 927,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 927,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[214] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1000,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1000,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[213] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1070,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1070,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[145] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1142,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1142,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[144] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1215,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1215,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device

     ;; row 7   delta:   125
     y1 = 975 & y2 = 1020
     subt = hn[95] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 710,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 710,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[94] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 785,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 785,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[124] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 855,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 855,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[122] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 927,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 927,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[123] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1000,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1000,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[84] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1070,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1070,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[85] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1142,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1142,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device

     ;; row 8   delta:   125
     y1 = 1100 & y2 = 1145
     subt = hn[93] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 785,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 785,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[92] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 855,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 855,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[121] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 927,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 927,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[82] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1000,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1000,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[83] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1070,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1070,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device

     ;; row 9   delta:   125
     y1 = 1225 & y2 = 1270
     subt = hn[91] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 855,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 855,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[172] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 927,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 927,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[81] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1000,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1000,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device

     ;; row 10   delta:   125
     y1 = 1350
     subt = hn[171] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 927,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 927,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device

     ;; the 3 extremes
     y1 = 95 & y2 = 1582
     subt = hn[190] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 87,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 87,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[180] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 1742,y1+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 1742,y1, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device
     subt = hn[170] & cl = subt eq hmax & cl_circ = cl*20 & cl_nr = (1-cl)*20
     plots, 925,y2+8, PSYM = 8, symsize=7, color=cl_circ, /device & t = round(subt)
     if subt gt eps then xyouts, 925,y2, strtrim(t,2), charsize=3, charthick=3, color=cl_nr, alignment=0.5, /device

     wset,11 & res = tvrd(/true) & wdelete, 11
     fn_out = outdir + '/' + fbn + '_lm_' + kdim_str + '_heatmap.png'
     write_png, fn_out, res

     ;; write sav-file for change analysis
     ;;===========================================
     hmap = fltarr(21,12)-1.0
     hmap[10,0] = hn[170] & hmap[10,1] = hn[171]
     hmap[9:11,2] = [hn[91],hn[172],hn[81]]
     hmap[8:12,3] = [hn[93],hn[92],hn[121],hn[82],hn[83]]
     hmap[7:13,4] = [hn[95],hn[94],hn[124],hn[122],hn[123],hn[84],hn[85]]
     hmap[6:14,5] = [hn[152],hn[151],hn[217],hn[216],hn[215],hn[214],hn[213],hn[145],hn[144]]
     hmap[5:15,6] = [hn[154],hn[153],hn[219],hn[218],hn[233],hn[232],hn[231],hn[212],hn[211],hn[143],hn[142]]
     hmap[4:16,7] = [hn[65],hn[155],hn[221],hn[220],hn[235],hn[234],hn[236],hn[230],hn[229],hn[210],hn[209],hn[141],hn[55]]
     hmap[3:17,8] = [hn[63],hn[64],hn[113],hn[222],hn[223],hn[224],hn[225],hn[226],hn[227],hn[228],hn[207],hn[208],hn[104],hn[54],hn[53]]
     hmap[2:18,9] = [hn[61],hn[62],hn[111],hn[112],hn[114],hn[200],hn[201],hn[202],hn[203],hn[204],hn[205],hn[206],hn[103],hn[102],hn[101],hn[52],hn[51]]
     hmap[1:19,10] = [hn[191],hn[192],hn[71],hn[72],hn[73],hn[74],hn[75],hn[131],hn[132],hn[133],hn[134],hn[135],hn[45],hn[44],hn[43],hn[42],hn[41],hn[182],hn[181]]
     hmap[0,11] = [hn[190]] & hmap[20,11] = [hn[180]]

     fn_out = outdir + '/' + fbn + '_lm_' + kdim_str + '_heatmap.sav'
     save, kdim_str, hn, hmap, filename = fn_out

     ;; add legends
     fn_out = outdir + '/heatmap_legend.png'
     file_copy, 'idl/heatmap_legend.png', fn_out, /overwrite
     fn_out = outdir + '/lm103class_legend.png'
     file_copy, 'idl/lm103class_legend.png', fn_out, /overwrite


     ;; write csv output
     ;;===========================================
     hns = round(hn*1000)/1000.0 & dot = strpos(hns,'.') & hnss = strarr(n_elements(hns))
     for i = 0, n_elements(hns)-1 do hnss[i] = strmid(hns[i],0,dot[i]+4)

     fn_out = outdir + '/' + fbn + '_lm_' + kdim_str + '_heatmap.csv'
     openw,12,fn_out
     printf,12, 'Landscape Mosaic using Window size (' + kdim_str + 'x' + kdim_str +')'+ ', , , , , , , , , , , , , , , , , , , , ,'
     printf,12, ', , , , , , , , , , ,' +hnss[170]+ ', , , , , , , , , ,'
     printf,12, ', , , , , , , , , , ,' +hnss[171]+ ', , , , , , , , , ,'
     printf,12, ', , , , , , , , , ,' +hnss[91]+','+hnss[172]+','+hnss[81]+', , , , , , , , ,'
     printf,12, ', , , , , , , , ,' +hnss[93]+','+hnss[92]+','+hnss[121]+','+hnss[82]+','+hnss[83]+', , , , , , , ,'
     printf,12, ', , , , , , , ,' +hnss[95]+','+hnss[94]+','+hnss[124]+','+hnss[122]+','+hnss[123]+','+hnss[84]+','+hnss[85]+', , , , , , ,'
     printf,12, ', , , , , , ,' +hnss[152]+','+hnss[151]+','+hnss[217]+','+hnss[216]+','+hnss[215]+','+hnss[214]+','+$
       hnss[213]+','+hnss[145]+','+hnss[144]+', , , , , ,'
     printf,12, ', , , , , ,'+hnss[154]+','+hnss[153]+','+hnss[219]+','+hnss[218]+','+hnss[233]+','+hnss[232]+','+$
       hnss[231]+','+hnss[212]+','+hnss[211]+','+hnss[143]+','+hnss[142]+', , , , ,'
     printf,12, ', , , , ,'+hnss[65]+','+hnss[155]+','+hnss[221]+','+hnss[220]+','+hnss[235]+','+hnss[234]+','+hnss[236]+','+$
       hnss[230]+','+hnss[229]+','+hnss[210]+','+hnss[209]+','+hnss[141]+','+hnss[55]+ ', , , ,'
     printf,12, ', , , ,'+hnss[63]+','+hnss[64]+','+hnss[113]+','+hnss[222]+','+hnss[223]+','+hnss[224]+','+hnss[225]+','+$
       hnss[226]+','+hnss[227]+','+hnss[228]+','+hnss[207]+','+hnss[208]+','+hnss[104]+','+hnss[54]+','+hnss[53]+', , ,'
     printf,12, ', , ,'+hnss[61]+','+hnss[62]+','+hnss[111]+','+hnss[112]+','+hnss[114]+','+hnss[200]+','+hnss[201]+','+$
       hnss[202]+','+hnss[203]+','+hnss[204]+','+hnss[205]+','+hnss[206]+','+hnss[103]+','+hnss[102]+','+$
       hnss[101]+','+hnss[52]+','+hnss[51]+', ,'
     printf,12, ', ,'+hnss[191]+','+hnss[192]+','+hnss[71]+','+hnss[72]+','+hnss[73]+','+hnss[74]+','+hnss[75]+','+$
       hnss[131]+','+hnss[132]+','+hnss[133]+','+hnss[134]+','+hnss[135]+','+hnss[45]+','+hnss[44]+','+$
       hnss[43]+','+hnss[42]+','+hnss[41]+','+hnss[182]+','+hnss[181]+','
     printf,12, ','+hnss[190]+', , , , , , , , , , , , , , , , , , , ,'+hnss[180]
     close,12

     ;; go back into dir_proc and finish the recoded image
     pushd, dir_proc
     ;; for recode: rows first, then columns!
     file_move, 'scsize.txt', 'recsize.txt', / overwrite ;;recode dimension file
     file_copy, dir_gwb + '/idl/recodelm103.sav', 'recode.txt', / overwrite ;; recode table
     file_move, 'scoutput', 'recinput', / overwrite ;; the unformatted spatcon output
     file_copy, dir_gwb + '/recode_lin64', 'recode', /overwrite
     spawn, './recode', log
     ;; get recoded result in 19 colors
     im = temporary(im103) * 0b
     openr, 1, 'recoutput' & readu,1, im & close,1
     if ctmiss gt 0 then im[qmiss] = 0b ;; add back missing
     ;; write out the LM image having the 19 colours only
     fboutdir = '../' + fbn + '_lm/'
     fn_out = fboutdir + fbn + '_lm_' + kdim_str + '.tif'

     ;; add the geotiff info if available
     IF is_geotiff GT 0 THEN $
       write_tiff, fn_out, im, red = r, green = g, blue = b, geotiff = geotiff, compression = 1 ELSE $
       write_tiff, fn_out, im, red = r, green = g, blue = b, compression = 1
     spawn, gedit + fn_out + ' > /dev/null 2>&1'

     ;; rename the 103 class image for later
     file_move, 'recinput', 'lm103class', /overwrite
     ;; write out the LM image having all the 103 classes
     fn_out = fboutdir  + fbn + '_lm_' + kdim_str + '_103class.tif'
     close,1 & openr, 1, 'lm103class'
     readu,1, im & close, 1
     IF is_geotiff gt 0 THEN $
       write_tiff, fn_out, im, geotiff = geotiff, compression = 1 ELSE write_tiff, fn_out, im, compression = 1
     spawn, gedit + fn_out + ' > /dev/null 2>&1'
     im = 0

     ;; clean up
     file_delete, 'scinput', 'scoutput', 'scpars.txt', 'scsize.txt', 'recsize.txt', 'recode.txt', 'recoutput', /allow_nonexistent, /quiet
     popd

     ;;=======================================
     file_delete, dir_proc + '/lm103class', /allow_nonexistent, /quiet
     openw, 9, fn_logfile, /append
     printf, 9, 'LM [ws '+kdim_str+ '] comp.time [sec]: ', systime( / sec) - time0
     close, 9   
   endfor  ;; LM loop over observation scales
   okfile = okfile + 1
  
  skip_lm: 
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
printf, 9, 'LM Batch Processing total comp.time: ', proctstr
printf, 9, 'Successfully processed files: ',strtrim(okfile,2)+'/'+ strtrim(nr_im_files,2)
printf, 9, '==============================================='
close, 9

print, 'LM finished sucessfully'

fin:
END
