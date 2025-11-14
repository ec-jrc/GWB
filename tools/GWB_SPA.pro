PRO GWB_SPA
;;==============================================================================
;;                   GWB script for Spatial Pattern Analysis (SPA)
;;==============================================================================
;; 
;; Purpose: 
;;==============================================================================
;; IDL cmd-line script to conduct SPAx as implemented in GuidosToolbox (GTB)
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
GWB_mv = 'GWB_SPA (version 2.0.0)'
;;
;; Module changelog:
;; 1.9.9: IDL 9.2.0
;; 1.9.6: add gpref, IDL 9.1.0
;; 1.9.4: IDL 9.0.0
;; 1.9.2: IDL 8.9.0
;; 1.9.1: added image size info, statistic output option, SW tag
;; 1.9.0: added note to restore files, IDL 8.8.3
;; 1.8.8: flexible input reading
;; 1.8.7: IDL 8.8.2
;; 1.8.6: added mod_params check
;; 1.8.5: added porosity and contiguous area
;; 1.7  : added SPA2
;; 1.6  : nocheck 
;; 1.3  : added option for user-selectable input/output directories
;; 1.2  : initial internal release
;;
;;==============================================================================
;; Input: at least 2 files in the subfolder "input"
;;==============================================================================
;; a) input image(s) (geotiff):
;; at least 1 or more geotiff images in the subfolder "input"
;; the input image must be MSPA-compliant having the assignment:
;; 0 byte: missing or no-data (optional)
;; 1 byte: background pixels (mandatory)
;; 2 byte: foreground pixels (mandatory)
;; 
;; b) spa-parameters.txt: (see header info in input/spa-parameters.txt)
;;  - number of SPAx classes: 2 or 3 or 5 or 6
;;
;;==============================================================================
;; Output: in the subfolder "output"
;;==============================================================================
;; a) Summary statistics 
;; b) geotiff images showing SPAx
;;
;; Processing steps:
;; 1) verify parameter file and MSPA-compatibility of input image
;; 2) process for SPAx
;; 3) post-process (write out and dostats)
;;
;;==============================================================================
;;==============================================================================
device, decomposed = 0
;; initial system checks
;;
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
print,'GWB_SPA using:'
if standalone eq 1 then dir_input = dir_inputdef + "/input"
if standalone eq 1 then dir_output = dir_inputdef + "/output"
print, 'dir_input= ', dir_input 
print, 'dir_output= ', dir_output

;; restore colortable
IF (file_info('idl/mspacolorston.sav')).exists EQ 0b THEN BEGIN
  print, "The file 'tools/idl/mspacolorston.sav' was not found."
  print, "Restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
ENDIF
restore, 'idl/mspacolorston.sav' & tvlct, r, g, b

;; verify to have tif image(s) (should be a geotiff)
pushd, dir_input & list = file_search('*.tif', count=ct_tifs) & popd
IF ct_tifs EQ 0 THEN BEGIN
  print, "The input directory does not contain an image with the extension '.tif'"
  print, 'Please copy your geotiff image here.'
  print, "Exiting..."
  goto,fin
ENDIF
mod_params = dir_input + '/spa-parameters.txt'
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
;; read SPAx settings: we need at least 1 valid line
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
IF ct LT 2 THEN BEGIN
  print, "The file: " + mod_params + " is in a wrong format."
  print, "Please copy the respective backup file into your input directory:"
  print,  dir_inputdef + "/input/backup/*parameters.txt, or"
  print, "restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
ENDIF
;; get and check parameters
spax_str = strtrim(finp(q[0]), 2) 
true = (spax_str eq '2') + (spax_str eq '3') + (spax_str eq '5') + (spax_str eq '6')
IF true EQ 0 THEN BEGIN
  print, "The file: " + mod_params + " is in a wrong format."
  print, "SPAx class is not 2, 3, 5 or 6."
  print, "Please copy the respective backup file into your input directory:"
  print,  dir_inputdef + "/input/backup/*parameters.txt, or"
  print, "restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
ENDIF

;; statistics ?
c_stats = strtrim(finp(q[1]), 2)
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

;;==============================================================================
;;==============================================================================
;; apply SPAx settings in a loop over all tif images 
;;==============================================================================
;;==============================================================================
gpref = 'unset LD_LIBRARY_PATH; '
desc = 'GTB_SPA, https://forest.jrc.ec.europa.eu/en/activities/lpa/gtb/'
tagsw = 'TIFFTAG_SOFTWARE='+'"'+"GWB, https://forest.jrc.ec.europa.eu/en/activities/lpa/gwb/" +'" '
gedit = gpref + 'gdal_edit.py -mo ' + tagsw
gedit = gedit + '-mo TIFFTAG_IMAGEDESCRIPTION="'+desc + '" '

fn_logfile = dir_output + '/spa' + spax_str + '.log'
nr_im_files = ct_tifs & time00 = systime( / sec) & okfile = 0l
nocheck = file_info(dir_input + '/nocheck.txt') & nocheck = nocheck.exists
se8 = replicate(1b, 3, 3) ;; structuring element = 8-conn kernel

openw, 9, fn_logfile
if nocheck eq 0 then printf,9,GWB_mv else printf,9, GWB_mv + ' - nocheck'
printf, 9, 'SPAx batch processing logfile: ', systime()
printf, 9, 'Statistics: ' + dostats
printf, 9, 'Number of files to be processed: ', nr_im_files
printf, 9, '==============================================='
close, 9
;; write out the path to the logfile to append RAM usage later on
fn_dirs2 = strmid(fn_dirs,0,strlen(fn_dirs)-12) + 'gwb_spa_log.txt'
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
    GOTO, skip_spa  ;; invalid input
  ENDIF
  
  res = query_tiff(input, inpinfo)
  IF inpinfo.type NE 'TIFF' THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (not a TIF image) '
    close, 9
    GOTO, skip_spa  ;; invalid input
  ENDIF
 
  ;; check for single image in file
  IF inpinfo.num_images GT 1 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (more than 1 image in the TIF image)'
    close, 9
    GOTO, skip_spa  ;; invalid input
  ENDIF

  ;; read it
  geotiff = 0
  im = read_tiff(input, geotiff=geotiff) & is_geotiff = (size(geotiff))[0]
  
  IF nocheck EQ 1b THEN goto, good2go

  ;; check for single channel image
  ;;===========================
  IF size(im, / n_dim) NE 2 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (more than 1 band in the TIF image)'
    close, 9
    GOTO, skip_spa  ;; invalid input
  ENDIF

  ;; check for byte array
  ;;===========================
  IF size(im, / type) NE 1 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (image is not of type BYTE) '
    close, 9
    GOTO, skip_spa  ;; invalid input
  ENDIF

  ;; check min/max value in image
  ;;===========================
  mxx = max(im, min = mii)
  IF mxx GT 2b THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (Image maximum is larger than 2 BYTE) '
    close, 9
    GOTO, skip_spa  ;; invalid input
  ENDIF ELSE IF mxx LT 2b THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (Image has no foreground (2 BYTE)) '
    close, 9
    GOTO, skip_spa  ;; invalid input
  ENDIF
  IF mii GT 1b THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (Image has no background (1 BYTE)) '
    close, 9
    GOTO, skip_spa  ;; invalid input
  ENDIF

  good2go:
  im = rotate(temporary(im),7)
  ;;==============================================================================
  ;; 2) process for SPAx
  ;;==============================================================================
  time0 = systime( / sec)

  ;; check for missing  pixels
  im_min = min(im) & ct_qmiss = 0
  if im_min eq 0b then begin
    missing = im eq 0b
    qmiss = where(missing eq 1b, ct_qmiss, /l64)
  endif
  area_image = (size(im))[4]
  area_data = area_image - ct_qmiss
  
  ;; extend the working image to ensure proper results for label_region
  sz = size(im,/dim) & ext1 = bytarr(sz(0) + 4, sz(1) + 4) + 1b & sz2=size(ext1,/dim)
  ext1[2:sz[0]+1, 2:sz[1]+1] = temporary(im) & all_n = 1 ;8-connectivity
  ;; count FG-objetcs
  nr_FG = max(label_region(ext1 eq 2b, all_neighbors=all_n, / ulong))
  ;; extend image data assignment into the surrounding buffer to not create artificial boundaries at the image outline
  ext1[2:sz[0]+1, 1] = ext1[2:sz[0]+1, 2] ;; bottom row
  ext1[2:sz[0]+1, sz2[1]-2] = ext1[2:sz[0]+1, sz2[1]-3] ;; top row
  ext1[1, 2:sz[1]+1] = ext1[2, 2:sz[1]+1] ;; left column
  ext1[sz2[0]-2, 2:sz[1]+1] = ext1[sz2[0]-3, 2:sz[1]+1] ;; right column
  ;; assign the corner pixels
  ext1[1,1] = ext1[2,2]  ;; left bottom
  ext1[1,sz2[1]-2] = ext1[2,sz2[1]-3] ;;  left top
  ext1[sz2[0]-2,1] = ext1[sz2[0]-3,2] ;; right bottom
  ext1[sz2[0]-2, sz2[1]-2] = ext1[sz2[0]-3, sz2[1]-3] ;; right top
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; FG
  fg = temporary(ext1) eq 2b ;; real FG
  ;; extend FG into missing to avoid getting boundaries there
  if im_min eq 0b then begin
    tmp = fg[2:sz[0]+1, 2:sz[1]+1]
    fg[2:sz[0]+1, 2:sz[1]+1] = dilate(tmp, se8) * missing + temporary(tmp)
    missing = 0
  endif

  ;; spa2: small, linear features
  if spax_str eq '2' then begin
    slf = fg - morph_open(fg, se8)
    im = (fg * 17b) - (slf * 16b)
    im = temporary(im[2:sz2(0)-3, 2:sz2(1)-3])
    if ct_qmiss gt 0 then im[qmiss] = 129b
    qmiss = 0
    zz = im eq 17b & nr_Cores = max(label_region(zz, all_neighbors=all_n, / ulong)) & zz = 0b
    zz = im eq 1b & nr_margin = max(label_region(zz, all_neighbors=all_n, / ulong)) & zz = 0b
    goto, spa2skipb0
  endif

  ;; Cores
  cores = erode(fg,se8)

  ;; Margin
  margin = fg - cores
  if spax_str eq '3' then fg = 0b

  ;; Holes, use 8-conn for FG <-> 4-conn for BG
  ;; holes must be done on extended BG to ensure the actual background is a hole
  holes = label_region(1b-cores,/ulong)
  ;; holes=0 -> FG; holes=1 -> image BG; holes gt 1 = actual holes inside Cores
  qholes = where(holes gt 1, ct_qholes, /l64) & holes = 0
  
  ;; visual display
  if spax_str eq '3' then begin
    im = temporary(cores)*17b
    if ct_qholes gt 0 then im[qholes] = 100b & qholes = 0
    ;; overplot the margin pixels on top of the holes of Core
    qmargin = where(margin eq 1b, /l64)
    im[qmargin] = 1b & margin = 0 & qmargin = 0
  endif else begin
    ct_qislets = 0
    
    ;; SPA6
    ;; at this point we have 3 data sets of extended size sz2:
    ;; - fg: the potential fixed fg at the intersection with missing
    ;; - cores: the core mask
    ;; - margin: all non-core FG

    if spax_str eq '6' then begin
      ;; reconstruction by dilation
      cord = cores & sum1 = 1 & sum2 = 0 & steps = 0
      while sum2 ne sum1 do begin
        sum1 = sum2
        cord = dilate(cord, se8) * fg
        sum2 = total(cord)
        steps = steps + 1
      endwhile
      cord = fg - temporary(cord)
      qislets = where(cord eq 1b, ct_qislets, /l64)
      cord = 0
    endif

    ;; continue with spa5
    core_boundary = dilate(cores,se8)*temporary(fg)-cores
    ;; start with Core
    im = temporary(cores)*17b
    ;; add core-holes
    if ct_qholes gt 0 then im[qholes] = 100b & qholes = 0
    ;; add core_boundary
    margin = temporary(margin)-core_boundary & qmargin = where(margin gt 0, ct_qmargin, /l64) & margin = 0
    im = temporary(im) + temporary(core_boundary)*3b
    ;; assign Perforation
    q = where(im eq 103b, ct, /l64)
    if ct gt 0 then im[q] = 5b
    q = 0
    ;; add margin pixels
    if ct_qmargin gt 0 then im[qmargin] = 1b
    qmargin = 0
    ;; add islet pixels
    if ct_qislets gt 0 then im[qislets] = 9b
    qislets = 0
  endelse ;; end of 5 or 6
  
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; only now after allclasses are assigned do the statistics for holes in the extended image
  ;; do them with 4-connectivity!
  ;; first, set the two box boundary to background, then do the labeling
  im[0:1,*] = 0b & im[sz2[0]-2:*,*] = 0b ;; left & right
  im[*,0:1] = 0b & im[*,sz2[1]-2:*] = 0b ;; bottom & top
  if ct_qmiss gt 0 then begin ;; add back the missing pixels
    zz = im[2:sz2(0)-3, 2:sz2(1)-3]
    zz[qmiss] = 129b & qmiss = 0
    im[2:sz2(0)-3, 2:sz2(1)-3] = temporary(zz)
  endif
  
  ;; can we skip statistics here?
  if tstats eq 0 then begin
    im = temporary(im[2:sz2(0)-3, 2:sz2(1)-3])
    goto, writeim   
  endif
  
  zz = im eq 100b & nr_holes = max(label_region(zz, / ulong)) & zz = 0b ;; core-holes with 4-connectivity
  zz = im eq 17b & nr_Cores = max(label_region(zz, all_neighbors=all_n, / ulong)) & zz = 0b
  if spax_str eq '3' then begin
    zz = im eq 1b & nr_margin = max(label_region(zz, all_neighbors=all_n, / ulong)) & zz = 0b
  endif else begin ;; spa5/6
    ;; add the remaining stats: edge, perf, margin
    zz = im eq 3b & nr_edge = max(label_region(zz, all_neighbors=all_n, / ulong)) & zz = 0b
    zz = im eq 5b & nr_perf = max(label_region(zz, all_neighbors=all_n, / ulong)) & zz = 0b
    zz = im eq 1b & nr_margin = max(label_region(zz, all_neighbors=all_n, / ulong)) & zz = 0b
    if spax_str eq '6' then begin
      zz = im eq 9b & nr_islet = max(label_region(zz, all_neighbors=all_n, / ulong)) & zz = 0b
    endif
    zz = im eq 17b or im eq 3b or im eq 5b 
    nr_contiguous = max(label_region(zz, all_neighbors=all_n, / ulong)) & zz = 0b
  endelse
  zz = 0b
  
  ;; go back to original dimension
  ;;=======================================
  im = temporary(im[2:sz2(0)-3, 2:sz2(1)-3])

  spa2skipb0:
  ;; get areas via histogram counting
  histo = histogram(im,/l64)
  area_miss = histo[129]
  area_Cores = histo[17]
  area_holes = histo[100]
  area_oBG = histo[0]
  area_bg = area_oBG + area_holes
  area_fg = area_data - area_bg

  ;; add the remaining stats: edge, perf, margin
  area_edge = histo[3]
  area_perf = histo[5]
  area_islet = histo[9]
  area_margin = histo[1]
  area_contiguous = area_Cores + area_edge + area_perf
  area_internal = area_contiguous + area_holes
  porosity = 100.0 - (double(area_contiguous) / area_internal * 100.0)

  ;;=======================================
  writeim:
  ;; write the final result
  fbn = file_basename(list[fidx], '.tif')
  outdir = dir_output + '/' + fbn + '_spa' + spax_str & file_mkdir, outdir
  fn_out = outdir + '/' + fbn + '_spa' + spax_str + '.tif'
  
  ;; add the geotiff info if available
  IF is_geotiff gt 0 THEN $
    write_tiff, fn_out, rotate(im,7), red = r, green = g, blue = b, geotiff = geotiff, compression = 1 ELSE $
    write_tiff, fn_out, rotate(im,7), red = r, green = g, blue = b, compression = 1
  spawn, gedit + fn_out + ' > /dev/null 2>&1'
  if tstats eq 0 then goto, skipstats
  
  ;; write out statistics
  fx = outdir + '/' + fbn + '_spa' + spax_str + '.txt' 
  file_delete,fx,/allow_nonexistent,/quiet
  conv1 = 100.0/area_data & conv2 = 100.0/area_fg & close, 12
  openw,12,fx
  printf, 12, 'SPA' + spax_str + ': 8-connected Foreground, summary analysis for image: '
  printf, 12, input
  printf, 12, '  '
  printf, 12, 'Image Dimension X/Y: ' + strtrim(sz(0),2) + '/' + strtrim(sz(1),2)
  printf, 12, 'Image Area =               Data Area                    + No Data (Missing) Area'
  printf, 12, '           = [ Foreground (FG) +   Background (BG)  ]     +          Missing    '
  printf, 12, '           = [        FG       + {Core-Opening + other BG} ] +       Missing    '
  printf, 12, '  '
  printf, 12, '================================================================================'
  printf, 12, '           Category              Area [pixels]: '
  printf, 12, '================================================================================'
  if spax_str eq '2' then begin
    printf, 12, format='(a20,i22)', '        Contiguous: ', area_contiguous
    printf, 12, format='(a20,i22)', '+              SLF: ', area_margin
    printf, 12, '--------------------------------------------------------------------------------'
    printf, 12, format='(a20,i22)',   '= Foreground Total: ', area_fg
    goto, spa2skipb1
  endif
  printf, 12, format='(a20,i22)',   '              Core: ', area_cores
  if spax_str eq '3' then begin
    printf, 12, format='(a20,i22)', '+           Margin: ', area_margin
  endif else begin ;;spa5/6
    if spax_str eq '6' then $
      printf, 12, format='(a20,i22)', '+            Islet: ', area_islet
    printf, 12, format='(a20,i22)', '+             Edge: ', area_edge
    printf, 12, format='(a20,i22)', '+      Perforation: ', area_perf
    printf, 12, format='(a20,i22)', '+           Margin: ', area_margin
    printf, 12, '(Contiguous = Core + Edge + Perforation: ' + strtrim(area_contiguous, 2) + ')'
  endelse
  printf, 12, '--------------------------------------------------------------------------------'
  printf, 12, format='(a20,i22)',   '= Foreground Total: ', area_fg
  printf, 12, '  '
  printf, 12, format='(a20,i22)',   '      Core-Opening: ', area_holes
  printf, 12, format='(a20,i22)',   '+         Other BG: ', area_oBG
  printf, 12, '--------------------------------------------------------------------------------'
  printf, 12, format='(a20,i22)',   '= Background Total: ', area_bg
  printf, 12, '  '
  printf, 12, format='(a20,i22)',   '  Foreground Total: ', area_fg
  spa2skipb1:
  printf, 12, format='(a20,i22)',   '+ Background Total: ', area_bg
  printf, 12, '--------------------------------------------------------------------------------'
  printf, 12, format='(a20,i22)',   '=  Data Area Total: ', area_data
  printf, 12, '  '
  printf, 12, format='(a20,i22)',   '         Data Area: ', area_data
  printf, 12, format='(a20,i22)',   '+          Missing: ', ct_qmiss
  printf, 12, '--------------------------------------------------------------------------------'
  printf, 12, format='(a20,i22)',   '= Image Area Total: ', area_image
  printf, 12, '  '
  printf, 12, '  '
  printf, 12, '================================================================================'
  printf, 12, '           Category    Proportion [%]: '
  printf, 12, '================================================================================'
  if spax_str eq '2' then begin
    printf, 12, format='(a20,f11.4)', '   Contiguous/Data: ', area_contiguous * conv1
    printf, 12, format='(a20,f11.4)', '+         SLF/Data: ', area_margin * conv1
    printf, 12, '--------------------------------------------------------------------------------'
    printf, 12, format='(a20,f11.4)',   '           FG/Data: ', area_fg * conv1
    printf, 12, '--------------------------------------------------------------------------------'
    printf, 12, format='(a20,f11.4)', '     Contiguous/FG: ', area_contiguous * conv2
    printf, 12, format='(a20,f11.4)', '+           SLF/FG: ', area_margin * conv2
    goto, spa2skipb2
  endif
  printf, 12, format='(a20,f11.4)',   ' Core-Opening/Data: ', area_holes * conv1
  printf, 12, '--------------------------------------------------------------------------------'
  printf, 12, format='(a20,f11.4)',   '         Core/Data: ', area_cores * conv1
  if spax_str eq '3' then begin
    printf, 12, format='(a20,f11.4)', '       Margin/Data: ', area_margin * conv1
  endif else begin
    if spax_str eq '6' then $
      printf, 12, format='(a20,f11.4)', '        Islet/Data: ', area_islet * conv1
    printf, 12, format='(a20,f11.4)', '         Edge/Data: ', area_edge * conv1
    printf, 12, format='(a20,f11.4)', '  Perforation/Data: ', area_perf * conv1
    printf, 12, format='(a20,f11.4)', '       Margin/Data: ', area_margin * conv1
    printf, 12, format='(a20,f11.4)', '   Contiguous/Data: ', area_contiguous * conv1
  endelse
  printf, 12, '--------------------------------------------------------------------------------'
  printf, 12, format='(a20,f11.4)',   '           FG/Data: ', area_fg * conv1
  printf, 12, '--------------------------------------------------------------------------------'
  printf, 12, format='(a20,f11.4)',   '           Core/FG: ', area_cores * conv2
  if spax_str eq '3' then begin
    printf, 12, format='(a20,f11.4)', '         Margin/FG: ', area_margin * conv2
  endif else begin
    if spax_str eq '6' then $
      printf, 12, format='(a20,f11.4)', '          Islet/FG: ', area_islet * conv2
    printf, 12, format='(a20,f11.4)', '           Edge/FG: ', area_edge * conv2
    printf, 12, format='(a20,f11.4)', '    Perforation/FG: ', area_perf * conv2
    printf, 12, format='(a20,f11.4)', '         Margin/FG: ', area_margin * conv2
    printf, 12, format='(a20,f11.4)', '     Contiguous/FG: ', area_contiguous * conv2
    printf, 12, format='(a20,f11.4)', '          Porosity: ', porosity
  endelse
  spa2skipb2:
  printf, 12, '================================================================================'
  printf, 12, '  '
  printf, 12, '  '
  printf, 12, '================================================================================'
  printf, 12, '           Category          Count [#]: '
  printf, 12, '================================================================================'
  if spax_str eq '2' then begin
    printf, 12, format='(a20,i15)',   '        Contiguous: ', nr_cores
    printf, 12, format='(a20,i15)',   '        FG Objects: ', nr_fg
    printf, 12, format='(a20,i15)',   '               SLF: ', nr_margin
    goto, spa2skipb3
  endif
  printf, 12, format='(a20,i15)',   '      Core-Opening: ', nr_holes
  printf, 12, format='(a20,i15)',   '        FG Objects: ', nr_fg
  printf, 12, '--------------------------------------------------------------------------------'
  printf, 12, format='(a20,i15)',   '              Core: ', nr_cores
  if spax_str eq '3' then begin
    printf, 12, format='(a20,i15)', '            Margin: ', nr_margin
  endif else begin
    if spax_str eq '6' then $
      printf, 12, format='(a20,i15)', '             Islet: ', nr_islet
    printf, 12, format='(a20,i15)', '              Edge: ', nr_edge
    printf, 12, format='(a20,i15)', '       Perforation: ', nr_perf
    printf, 12, format='(a20,i15)', '            Margin: ', nr_margin
    printf, 12, format='(a20,i15)', '        Contiguous: ', nr_contiguous
  endelse
  spa2skipb3:
  printf, 12, '================================================================================'
  close, 12
  
  skipstats:
  ;; update the log-file
  okfile = okfile + 1
  openw, 9, fn_logfile, /append
  printf, 9, 'SPA' + spax_str + ' comp.time [sec]: ', systime( / sec) - time0
  close, 9

  skip_spa:
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
printf, 9, 'SPA Batch Processing total comp.time: ', proctstr
printf, 9, 'Successfully processed files: ',strtrim(okfile,2)+'/'+ strtrim(nr_im_files,2)
printf, 9, '==============================================='
close, 9

print, 'SPA' + spax_str + ' finished sucessfully'

fin:
END
