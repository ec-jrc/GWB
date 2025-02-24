PRO GWB_ACC
;;==============================================================================
;;                    GWB APP for Accounting (ACC)
;;==============================================================================
;; 
;; Purpose: 
;;==============================================================================
;; IDL cmd-line app to conduct Accounting as implemented in GuidosToolbox (GTB)
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
GWB_mv = 'GWB_ACC (version 1.9.7)'
;;
;; Module changelog:
;; 1.9.6: add gpref, IDL 9.1.0
;; 1.9.4: IDL 9.0.0
;; 1.9.2: IDL 8.9.0
;; 1.9.1: added image size info, statistic output option, SW tag
;; 1.9.0: added note to restore files, IDL 8.8.3
;; 1.8.8: flexible input reading
;; 1.8.7: IDL 8.8.2
;; 1.8.6: added mod_params check
;; 1.8.4: decreased memory footprint, in particular for default processing
;; 1.8.1: fixed single threshold output, fixed csv output
;; 1.6  : nocheck, special BG 1/2
;; 1.5  : output directory name now has the correct module extension
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
;; 3 byte: special BG1 (blue) (optional)
;; 4 byte: special BG2 (pale blue) (optional)
;; 
;; b) acc-parameters.txt: (see header info in input/acc-parameters.txt)
;;  - Foreground connectivity
;;  - pixel resolution in meters
;;  - up to 5 area thresholds [pixels]
;;  - output option: default OR extended
;;
;;==============================================================================
;; Output: in the subfolder "output"
;;==============================================================================
;; a) Summary statistics on up to 6 area classes
;; b) geotiff formatted color-coded image with up to 6 different image object
;;    area-classes plus the 3 largest patches shown in different colours
;; c) geotiff images showing ID and area/ID (if output option = extended)
;;
;; Processing steps:
;; 1) verify parameter file and MSPA-compatibility of input image
;; 2) process for Accounting
;; 3) post-process (write out and dostats)
;;
;;==============================================================================
;;==============================================================================
device, decomposed = 0
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
print,'GWB_ACC using:'
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
mod_params = dir_input + '/acc-parameters.txt'
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
;; read accounting settings, we need at least 5 valid lines
fl = file_lines(mod_params)
IF fl LT 5 THEN BEGIN
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
IF ct LT 5 THEN BEGIN
  print, "The file: " + mod_params + " is in a wrong format."
  print, "Please copy the respective backup file into your input directory:"
  print,  dir_inputdef + "/input/backup/*parameters.txt, or"
  print, "restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
ENDIF
;; get and check parameters
conn8_str = strtrim(finp(q[0]), 2)
true = (conn8_str eq '8') + (conn8_str eq '4')
IF true EQ 0 THEN BEGIN
  print, "The file: " + mod_params + " is in a wrong format."
  print, "Foreground connectivity is not 8 or 4."
  print, "Please copy the respective backup file into your input directory:"
  print,  dir_inputdef + "/input/backup/*parameters.txt, or"
  print, "restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
ENDIF

;; Pixel resolution
pixres_str = strtrim(finp(q[1]), 2) & pixres = abs(float(pixres_str))
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

;; output option
outopt = strtrim(finp(q[3]), 2)
true = (outopt EQ 'default') + (outopt EQ 'detailed')
IF true EQ 0 THEN BEGIN
  print, "The file: " + mod_params + " is in a wrong format."
  print, "output option is not 'default' or 'detailed'."
  print, "Please copy the respective backup file into your input directory:"
  print,  dir_inputdef + "/input/backup/*parameters.txt, or"
  print, "restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
ENDIF

;; big3pink switch
big3pink = strtrim(finp(q[4]), 2)
true = (big3pink eq '0') + (big3pink eq '1')
IF true EQ 0 THEN BEGIN
  print, "The file: " + mod_params + " is in a wrong format."
  print, "big3pink is not '0' or '1'."
  print, "Please copy the respective backup file into your input directory:"
  print,  dir_inputdef + "/input/backup/*parameters.txt, or"
  print, "restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
ENDIF

;; area thresholds, maximum 5
ath = strtrim(finp(q[2]), 2)
res = strsplit(ath,' ',/extract) & nr_res = n_elements(res)
cl1 = 0 & cl2 = 0 & cl3 = 0 & cl4 = 0 & cl5 = 0
;; constrain area threshold to 0 to 1000000000000000000
cl1_str = res[0] & cl1 = 0 > ulong64(cl1_str) 
if cl1 gt 1000000000000000000 then cl1 = 0
IF nr_res GE 2 THEN BEGIN
  cl2_str = res[1] & cl2 = 0 > ulong64(cl2_str) 
  if cl2 gt 1000000000000000000 then cl2 = 0
ENDIF
IF nr_res GE 3 THEN BEGIN
  cl3_str = res[2] & cl3 = 0 > ulong64(cl3_str) 
  if cl3 gt 1000000000000000000 then cl3 = 0
ENDIF
IF nr_res GE 4 THEN BEGIN
  cl4_str = res[3] & cl4 = 0 > ulong64(cl4_str) 
  if cl4 gt 1000000000000000000 then cl4 = 0
ENDIF
IF nr_res GE 5 THEN BEGIN ;; more than 5 will be neglected
  cl5_str = res[4] & cl5 = 0 > ulong64(cl5_str) 
  if cl5 gt 1000000000000000000 then cl5 = 0
ENDIF

cat = [cl1, cl2, cl3, cl4, cl5] ;; the defined size category thresholds
;; filter out invalid settings
q = where(cat ge 1,ct)
if ct eq 0 then begin
  print, "The file: " + mod_params + " is in a wrong format."
  print, "Invalid accouting threshold settings."
  print, "Threshold(s) must be integers within"
  print, "[1, 1000000000000000000]."
  print, "Please copy the respective backup file into your input directory:"
  print,  dir_inputdef + "/input/backup/*parameters.txt, or"
  print, "restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
endif else begin
  cat=cat[q]
endelse
;; sort it, remove double entries, increasing order
cat = cat(sort(cat)) & cat = cat(uniq(cat))
nr_cat = n_elements(cat) 
IF total(cat) LT 1.0 THEN BEGIN
  print, "The file: " + mod_params + " is in a wrong format."
  print, "Threshold(s) must be integers within"
  print, "[1, 1000000000000000000]."
  print, "Please copy the respective backup file into your input directory:"
  print,  dir_inputdef + "/input/backup/*parameters.txt, or"
  print, "restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
ENDIF
cat_ID = cat*0    ;; # of objects in each cateory
cat_area = cat*0   ;; total area of objects in each cateory
cat_idlast = 0 & cat_arealast = 0

;;==============================================================================
;;==============================================================================
;; apply accounting settings in a loop over all tif images 
;;==============================================================================
;;==============================================================================
gpref = 'unset LD_LIBRARY_PATH; '
desc = 'GTB_ACC, https://forest.jrc.ec.europa.eu/en/activities/lpa/gtb/'
tagsw = 'TIFFTAG_SOFTWARE='+'"'+"GWB, https://forest.jrc.ec.europa.eu/en/activities/lpa/gwb/" +'" '
gedit = gpref + 'gdal_edit.py -mo ' + tagsw
gedit = gedit + '-mo TIFFTAG_IMAGEDESCRIPTION="'+desc + '" '

fn_logfile = dir_output + '/acc.log'
nr_im_files = ct_tifs & time00 = systime( / sec) & okfile = 0l
nocheck = file_info(dir_input + '/nocheck.txt') & nocheck = nocheck.exists

openw, 9, fn_logfile
if nocheck eq 0 then printf,9,GWB_mv else printf,9, GWB_mv + ' - nocheck'
printf, 9, 'Accounting batch processing logfile: ', systime()
printf, 9, 'Number of files to be processed: ', nr_im_files
printf, 9, '==============================================='
close, 9
;; write out the path to the logfile to append RAM usage later on
fn_dirs2 = strmid(fn_dirs,0,strlen(fn_dirs)-12) + 'gwb_acc_log.txt'
close, 1 & openw, 1, fn_dirs2 & printf, 1, fn_logfile & close, 1


FOR fidx = 0, nr_im_files - 1 DO BEGIN
  counter = strtrim(fidx + 1, 2) + '/' + strtrim(nr_im_files, 2)
  input = dir_input + '/' +list[fidx]
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
  printf, 9, 'up to 30x RAM needed [GB]: ' + strtrim(imsizeGB*30.0,2)
  close, 9
  

  res = strpos(input,' ') ge 0
  IF res EQ 1 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (empty space in directory path or input filename) '
    close, 9
    GOTO, skip_acc  ;; invalid input
  ENDIF
  
  res = query_tiff(input, inpinfo)
  IF inpinfo.type NE 'TIFF' THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (not a TIF image) '
    close, 9
    GOTO, skip_acc  ;; invalid input
  ENDIF
 
  ;; check for single image in file
  IF inpinfo.num_images GT 1 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (more than 1 image in the TIF image) '
    close, 9
    GOTO, skip_acc  ;; invalid input
  ENDIF

  ;; read it
  geotiff = 0
  im = read_tiff(input, geotiff=geotiff) & is_geotiff = (size(geotiff))[0]
  
  ;; check for single channel image
  ;;===========================
  IF size(im, / n_dim) NE 2 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (more than 1 band in the TIF image) '
    close, 9
    GOTO, skip_acc  ;; invalid input
  ENDIF

  IF nocheck EQ 1b THEN goto, good2go

  ;; check for byte array
  ;;===========================
  IF size(im, / type) NE 1 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (image is not of type BYTE) '
    close, 9
    GOTO, skip_acc  ;; invalid input
  ENDIF

  ;; check min/max value in image
  ;;===========================
  mxx = max(im, min = mii)
  IF mxx GT 4b THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (Image maximum is larger than 4 BYTE)'
    close, 9
    GOTO, skip_acc  ;; invalid input
  ENDIF ELSE IF mxx LT 2b THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (Image has no foreground (2 BYTE))'
    close, 9
    GOTO, skip_acc  ;; invalid input
  ENDIF
  IF mii GT 1b THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (Image has no background (1 BYTE))'
    close, 9
    GOTO, skip_acc  ;; invalid input
  ENDIF
  ;; we must have foreground pixels (2) and we must have BG-pixels (1)
  upv = where(histogram(im, /l64) GT 0)
  q=where(upv eq 2, ct)
  IF ct NE 1 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'No pixels with mandatory FG-data value 2 BYTE found'
    close, 9
    GOTO, skip_acc  ;; invalid input
  ENDIF
  q=where(upv eq 1, ct)
  IF ct NE 1 THEN BEGIN
    openw, 9, fn_logfile, /append
     printf, 9, 'No pixels with mandatory BG-data value 1 BYTE found'
    close, 9
    GOTO, skip_acc  ;; invalid input
  ENDIF

  good2go:
  im = rotate(temporary(im),7) & sz=size(im,/dim)
  ;;==============================================================================
  ;; 2) process for Accounting
  ;;==============================================================================
  time0 = systime( / sec)
  
  ;; extend the image with background so label_region can do a flood-fill in the BG
  ext=bytarr(sz[0]+10,sz[1]+10)
  ext[5:sz[0]+4,5:sz[1]+4] = temporary(im) eq 2b & tot_area = total(ext,/double)
  cl = byte([103, 33, 65, 1, 9, 17]) ;; colors to be used for the 6 size classes
  cl_name = ['black', 'red', 'yellow', 'orange', 'brown', 'green']
  conn8 = conn8_str eq '8'
  nw_ids = label_region(ext, all=conn8, / ulong)
  tot_ids = max(nw_ids) ;; total # of objects, the first one does not count because it is the background
  obj_area = histogram(nw_ids, reverse_indices = revind, / l64)
  oba_max = max(obj_area[1:*]) ;; neglect background and get the area of the largest object
  obj_area[0]=9000000000000000000  ;; set BG to a high number so we can search for size classes in one statement
 
  ;;====================================================================================
  ;; statistical summary of nw_id image
  ;;====================================================================================
  oba = histogram(nw_ids, / l64) ;; oba has only the valid objects !!!
  oba = oba[1:*] ;; remove the background
  
  ;; reset all entries
  cat_idlast = 0 & cat_arealast = 0
  cat_ID = cat*0    ;; # of objects in each cateory
  cat_area = cat*0   ;; total area of objects in each cateory 

  ;; first category
  q = where(oba LE cat[0], ct, /l64)
  if ct gt 0 then begin
    cat_id[0] = ct & cat_area[0] = total(oba[q],/double)
  endif
  ;; other categories
  for idx = 1, nr_cat do begin
    if idx lt nr_cat then begin ;; not the last category
      q = where(oba GT cat[idx-1] and oba LE cat[idx], ct, /l64)
      if ct gt 0 then begin
        cat_id[idx] = ct & cat_area[idx] = total(oba[q],/double)
      endif
    endif else begin ;; the last category
      q = where(oba GT cat[idx-1], ct, /l64)
      if ct gt 0 then begin
        cat_idlast = ct & cat_arealast = ulong64(total(oba[q],/double))
      endif
    endelse
  endfor
  
  fbn = file_basename(list[fidx], '.tif')
  outdir = dir_output + '/' + fbn + '_acc' & file_mkdir, outdir
  z = outdir + '/' + fbn + '_acc.txt'
  hec = ((pixres)^2) / 10000.0
  acr = hec * 2.47105

  openw,1, z
  printf, 1, 'Accounting size classes result using: '
  printf, 1, fbn
  printf, 1, 'Base settings: ' + conn8_str + '-connectivity, pixel resolution: ' + pixres_str + ' [m]'
  printf, 1, 'Conversion factor: pixel_to_hectare: ' + strtrim(hec,2) + ', ' + 'pixel_to_acres: ' + strtrim(acr,2)
  printf, 1, '--------------------------------------------------------------------------------------------- '
  printf, 1, ' Size class 1: [1 - ' + strtrim(cat[0],2) + '] pixels; color: ' + cl_name[0]
  printf, 1, '          # Objects      Area[pixels]     % of all objects  % of total FGarea'
  printf, 1, format='(4(a18))', strtrim(cat_id[0],2), strtrim(cat_area[0],2), strtrim(cat_id[0]*100.0/tot_ids,2), strtrim(cat_area[0]*100.0/tot_area,2)
  printf, 1, '--------------------------------------------------------------------------------------------- '
  if nr_cat ge 2 then begin
    printf, 1, ' Size class 2: [' + strtrim(cat[0]+1,2) + ' - ' + strtrim(cat[1],2) + '] pixels; color: ' + cl_name[1]
    printf, 1, '          # Objects      Area[pixels]     % of all objects  % of total FGarea'
    printf, 1, format='(4(a18))', strtrim(cat_id[1],2), strtrim(cat_area[1],2), strtrim(cat_id[1]*100.0/tot_ids,2), strtrim(cat_area[1]*100.0/tot_area,2)
    printf, 1, '--------------------------------------------------------------------------------------------- '
  endif
  if nr_cat ge 3 then begin
    printf, 1, ' Size class 3: [' + strtrim(cat[1]+1,2) + ' - ' + strtrim(cat[2],2) + '] pixels; color: ' + cl_name[2]
    printf, 1, '          # Objects      Area[pixels]     % of all objects  % of total FGarea'
    printf, 1, format='(4(a18))', strtrim(cat_id[2],2), strtrim(cat_area[2],2), strtrim(cat_id[2]*100.0/tot_ids,2), strtrim(cat_area[2]*100.0/tot_area,2)
    printf, 1, '--------------------------------------------------------------------------------------------- '
  endif
  if nr_cat ge 4 then begin
    printf, 1, ' Size class 4: [' + strtrim(cat[2]+1,2) + ' - ' + strtrim(cat[3],2) + '] pixels; color: ' + cl_name[3]
    printf, 1, '          # Objects      Area[pixels]     % of all objects  % of total FGarea'
    printf, 1, format='(4(a18))', strtrim(cat_id[3],2), strtrim(cat_area[3],2), strtrim(cat_id[3]*100.0/tot_ids,2), strtrim(cat_area[3]*100.0/tot_area,2)
    printf, 1, '--------------------------------------------------------------------------------------------- '
  endif
  if nr_cat ge 5 then begin
    printf, 1, ' Size class 5: [' + strtrim(cat[3]+1,2) + ' - ' + strtrim(cat[4],2) + '] pixels; color: ' + cl_name[4]
    printf, 1, '          # Objects      Area[pixels]     % of all objects  % of total FGarea'
    printf, 1, format='(4(a18))', strtrim(cat_id[4],2), strtrim(cat_area[4],2), strtrim(cat_id[4]*100.0/tot_ids,2), strtrim(cat_area[4]*100.0/tot_area,2)
    printf, 1, '--------------------------------------------------------------------------------------------- '
  endif
  ;; the last class
  if cat_idlast gt 0 then begin
    printf, 1, ' Size class ' + strtrim(nr_cat + 1,2) + ': [' + strtrim(cat[nr_cat-1]+1,2) + ' -> ] pixels; color: ' + cl_name[nr_cat]
    printf, 1, '          # Objects      Area[pixels]     % of all objects  % of total FGarea'
    printf, 1, format='(4(a18))', strtrim(cat_idlast,2), strtrim(cat_arealast,2), strtrim(cat_idlast*100.0/tot_ids,2), strtrim(cat_arealast*100.0/tot_area,2)
    printf, 1, '--------------------------------------------------------------------------------------------- '
  endif
  printf, 1, '--------------------------------------------------------------------------------------------- '
  printf, 1, 'Sum of all classes:'
  printf, 1, '          # Objects      Area[pixels]     % of all objects  % of total FGarea'
  allid = ulong64(total(cat_id,/double) + cat_idlast)
  allarea = ulong64(total(cat_area,/double) + cat_arealast)
  ss = moment(oba, sdev=sdev, mean=aps) & medps = long64(median(oba))
  printf, 1, format='(4(a18))', strtrim(allid,2), strtrim(allarea,2), strtrim(allid*100.0/tot_ids,2), strtrim(allarea*100.0/tot_area,2)
  printf, 1, ' '
  printf, 1, format='(a20,a16)', 'Median Patch Size: ', strtrim(medps,2)
  printf, 1, format='(a20,a16)', 'Average Patch Size: ', strtrim(aps,2)
  printf, 1, format='(a20,a16)', 'Standard Deviation: ', strtrim(sdev,2)
  printf, 1, ' ' 
  
  ;;====================================================================================
  ;; ext3 = nw_area per ID in extended size
  ;;====================================================================================
  IF outopt EQ 'default' THEN ext3=long(0)*temporary(nw_ids) ELSE ext3=long(0)*nw_ids
  ;; assign object area to object polygon
  nr_obj = n_elements(obj_area)
  FOR i = 1l, nr_obj - 1 DO ext3[revind[revind[i]:revind[i + 1] - 1]] = obj_area(i)
  IF outopt EQ 'default' THEN ext3 = 0
  if (nr_obj gt 3) and (big3pink eq 1) then save, obj_area, filename = dir_output + '/obj_area.sav'

  ;; ext = viewport image, assign colors for up to 6 area classes
  for i_class = 0, nr_cat do begin
    if i_class eq nr_cat then begin
      qsmall = where(obj_area NE 9000000000000000000,c_small, /l64)
    endif else begin
      qsmall = where(obj_area LE cat(i_class),c_small, /l64) ;; where the histogram area is in area class
    endelse
    if c_small gt 0 then begin
      for id = 0, c_small-1 do begin
        il = qsmall[id] & q = revind[revind[il]:revind[il+1]-1] & ext[q] = cl(i_class)
      endfor
      ;; set qsmall to a high number
      if i_class eq nr_cat then obj_area = 0 else obj_area[qsmall] = 9000000000000000000
    endif
  endfor
  
  ;; show the 3 largest objects in pink (80b)
  if (nr_obj gt 3) and (big3pink eq 1) then begin
    restore, dir_output + '/obj_area.sav' & file_delete, dir_output + '/obj_area.sav', /quiet, /allow_nonexistent
    oba_max1 = oba_max & id_max1 = 0 & oba_max2 = 0 & id_max2 = 0 & oba_max3 = 0 & id_max3 = 0
    ;; the biggest object
    qsmall = where(obj_area eq oba_max1, c_small, /l64)
    if c_small gt 0 then begin
      for id = 0, c_small-1 do begin
        il = qsmall[id] & q = revind[revind[il]:revind[il+1]-1] & ext[q] = 80b
      endfor
      ;; set qsmall to a high number
      obj_area[qsmall] = 9000000000000000000
      id_max1 = qsmall
      printf, 1, 'Three largest object IDs and area[pixels]; color: pink'
      printf, 1, 'These 3 objects overlay objects listed above'
      printf, 1, format='(a3,a18, a18)', '1) ', strtrim(id_max1,2), strtrim(oba_max1,2)
    endif
    ;; the second biggest object
    oba_max2 = max((obj_area lt 9000000000000000000)*obj_area)
    qsmall = where(obj_area eq oba_max2, c_small, /l64)
    if c_small gt 0 then begin
      for id = 0, c_small-1 do begin
        il = qsmall[id] & q = revind[revind[il]:revind[il+1]-1] & ext[q] = 80b
      endfor
      ;; set qsmall to a high number
      obj_area[qsmall] = 9000000000000000000
      id_max2 = qsmall
      printf, 1, format='(a3,a18, a18)', '2) ', strtrim(id_max2,2), strtrim(oba_max2,2)
    endif
    ;; the third biggest object
    oba_max3 = max((obj_area lt 9000000000000000000)*obj_area)
    qsmall = where(obj_area eq oba_max3, c_small, /l64)
    if c_small gt 0 then begin
      for id = 0, c_small-1 do begin
        il = qsmall[id] & q = revind[revind[il]:revind[il+1]-1] & ext[q] = 80b
      endfor
      ;; set qsmall to a high number
      obj_area[qsmall] = 9000000000000000000
      id_max3 = qsmall
      printf, 1, format='(a3,a18, a18)', '3) ', strtrim(id_max3,2), strtrim(oba_max3,2)
    endif
  endif else begin
    printf,1, 'Largest object:     ', strtrim(oba_max, 2)
  endelse
  ;; close the statistics file
  close, 1
  
  ;; write csv output
  z = outdir + '/' + fbn + '_acc.csv' & file_delete,z,/allow_nonexistent,/quiet  
  openw,12,z
  printf,12, 'Accounting size classes result using: ' + input + ' (more info in: acc.txt), , , , , ,'
  printf,12, ', Size class [pixels], Color, # Objects, Area[pixels], % of all objects, % of total FGarea'
  printf,12,  ', 1: [1 - ' + strtrim(cat[0],2) + '],' + cl_name[0] + ', ' + $
    strtrim(cat_id[0],2) + ', ' + strtrim(cat_area[0],2) + ', ' + $
    strtrim(cat_id[0]*100.0/tot_ids, 2) + ', ' + strtrim(cat_area[0]*100.0/tot_area, 2)
    
  if nr_cat ge 2 then printf,12, ', 2: [' + strtrim(cat[0]+1,2) + ' - ' + strtrim(cat[1],2) + '],' + $
    cl_name[1] + ', ' + strtrim(cat_id[1], 2) + ', ' + strtrim(cat_area[1],2) + ', ' + $
    strtrim(cat_id[1]*100.0/tot_ids, 2) + ', ' + strtrim(cat_area[1]*100.0/tot_area, 2)
    
  if nr_cat ge 3 then printf,12, ', 3: [' + strtrim(cat[1]+1,2) + ' - ' + strtrim(cat[2],2) + '], ' + $
    cl_name[2] + ', ' + strtrim(cat_id[2], 2) + ', '  + strtrim(cat_area[2],2) + ', ' + $
    strtrim(cat_id[2]*100.0/tot_ids, 2) + ', ' + strtrim(cat_area[2]*100.0/tot_area, 2)
    
  if nr_cat ge 4 then printf,12, ', 4: [' + strtrim(cat[2]+1,2) + ' - ' + strtrim(cat[3],2) + '],' + $
    cl_name[3] + ', ' + strtrim(cat_id[3], 2) + ', ' + strtrim(cat_area[3],2) + ', ' + $
    strtrim(cat_id[3]*100.0/tot_ids, 2) + ', ' + strtrim(cat_area[3]*100.0/tot_area, 2)
    
  if nr_cat ge 5 then printf,12, ', 5: [' + strtrim(cat[3]+1,2) + ' - ' + strtrim(cat[4],2) + '], ' + $
    cl_name[4] + ', ' + strtrim(cat_id[4], 2) + ', ' + strtrim(cat_area[4],2) + ', ' + $
    strtrim(cat_id[4]*100.0/tot_ids, 2) + ', ' + strtrim(cat_area[4]*100.0/tot_area, 2)
    
  ;; the last class
  if cat_idlast gt 0 then begin
    printf,12, ', ' + strtrim(nr_cat + 1,2) + ': [' + strtrim(cat[nr_cat-1]+1,2) + ' -> ], ' + $
      cl_name[nr_cat] + ', ' + strtrim(cat_idlast, 2) + ', ' + strtrim(cat_arealast,2) + ', ' + $
      strtrim(cat_idlast*100.0/tot_ids, 2) + ', ' + strtrim(cat_arealast*100.0/tot_area, 2)
  endif
  close,12 

  ;;==============================================================================
  ;; 3) post-process
  ;;==============================================================================
  ;; cut back to original
  ext = temporary(ext[5:sz[0]+4,5:sz[1]+4])
  IF outopt NE 'default' THEN BEGIN
    ext3 = temporary(ext3[5:sz[0]+4,5:sz[1]+4])
    ext2 = temporary(long(nw_ids[5:sz[0]+4,5:sz[1]+4]))
  ENDIF

  ;; put back missing, water and special BG
  im = read_tiff(input) & im = rotate(temporary(im),7)
  q=where(im eq 0b, ct_q, /l64) 
  IF ct_q GT 0 THEN BEGIN
    ext[q] = 129b ; image in viewport
    IF outopt NE 'default' THEN ext2[q]= -1   ; id of object
    IF outopt NE 'default' THEN ext3[q]= -1   ; area of object
  ENDIF 
  q = where(im eq 3b, ct_q, /l64) ;; water bodies - blue
  IF ct_q GT 0 THEN BEGIN
    ext[q] = 105b ; image in viewport
    IF outopt NE 'default' THEN ext2[q]= -3   ; id of object
    IF outopt NE 'default' THEN ext3[q]= -3   ; area of object
  ENDIF
  q = where(im eq 4b, ct_q, /l64) ;; special BG - pale-blue
  IF ct_q GT 0 THEN BEGIN
    ext[q] = 176b ; image in viewport
    IF outopt NE 'default' THEN ext2[q]= -4   ; id of object
    IF outopt NE 'default' THEN ext3[q]= -4   ; area of object
  ENDIF
  im = 0 

  ;; write out resulting files
  ;====================================================
  outbase = outdir + '/' + file_basename(list[fidx], '.tif') + '_acc'

  ;; a) the viewport image
  fn_out = outbase + '.tif' 
  IF is_geotiff EQ 0b THEN $
    write_tiff, fn_out, rotate(ext,7), red=r, green=g, blue=b, compression=1 ELSE $
    write_tiff, fn_out, rotate(ext,7), red=r, green=g, blue=b, geotiff=geotiff, compression=1 
    spawn, gedit + fn_out + ' > /dev/null 2>&1'
  ext = 0

  IF outopt NE 'default' THEN BEGIN ;; output images showing ID and area per ID
    ;; b) image of IDs
    fn_out = outbase + '_ids.tif'
    IF is_geotiff EQ 0b THEN $
      write_tiff, fn_out, rotate(ext2,7), /long, /signed, compression=1 ELSE $
      write_tiff, fn_out, rotate(ext2,7), /long, /signed, geotiff=geotiff, compression=1
    spawn, gedit + fn_out + ' > /dev/null 2>&1'
    ext2 = 0
      
    ;; c) image of area per ID
    fn_out = outbase + '_pixels.tif'
    IF is_geotiff EQ 0b THEN $
      write_tiff, fn_out, rotate(ext3,7), /long, /signed, compression=1 ELSE $
      write_tiff, fn_out, rotate(ext3,7), /long, /signed, geotiff=geotiff, compression=1
    spawn, gedit + fn_out + ' > /dev/null 2>&1'
    ext3 = 0
  ENDIF
  
  okfile = okfile + 1
  openw, 9, fn_logfile, /append
  printf, 9, 'Accounting comp.time [sec]: ', systime( / sec) - time0
  close, 9

  skip_acc: 
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
printf, 9, 'ACC Batch Processing total comp.time: ', proctstr
printf, 9, 'Successfully processed files: ',strtrim(okfile,2)+'/'+ strtrim(nr_im_files,2)
printf, 9, '==============================================='
close, 9

print, 'Accounting finished sucessfully'

fin:
END
