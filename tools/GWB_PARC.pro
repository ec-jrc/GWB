PRO GWB_PARC
;;==============================================================================
;;         GWB script for Parcellation (PARC)
;;==============================================================================
;; 
;; Purpose: 
;;==============================================================================
;; IDL cmd-line script to conduct PARC as implemented in GuidosToolbox (GTB)
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
GWB_mv = 'GWB_PARC (version 2.0.0)'
;;
;; Module changelog:
;; 1.9.9: IDL 9.2.0
;; 1.9.7: increase computing precision
;; 1.9.6: add gpref, IDL 9.1.0
;; 1.9.4: IDL 9.0.0
;; 1.9.2: IDL 8.9.0
;; 1.9.1: added image size info
;; 1.9.0: added note to restore files, IDL 8.8.3
;; 1.8.8: flexible input reading
;; 1.8.7: IDL 8.8.2
;; 1.8.6: added mod_params check
;; 1.6  : nocheck, fixed minimum check, added output directory extension
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
;; [1, 255] byte: land cover classes
;;
;; b) parc-parameters.txt: (see header info in input/parc-parameters.txt)
;;  - 8  or  4 foreground connectivity
;;
;;==============================================================================
;; Output: in the subfolder "output"
;;==============================================================================
;; a) LM summary statistics
;; b) geotiff formatted color-coded image with up to 22 LM classes 
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
print,'GWB_PARC using:'
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
mod_params = dir_input + '/parc-parameters.txt'
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
;; read parc settings: 8conn, we need at least 1 valid line
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
;; get and check parameters
c_FGconn = strtrim(finp(q[0]), 2)
if c_FGconn eq '8' then begin
  conn8 = 1
endif else if c_FGconn eq '4' then begin
  conn8 = 0
endif else begin
  print, "The file: " + mod_params + " is in a wrong format."
  print, "Foreground connectivity is not 8 or 4."
  print, "Please copy the respective backup file into your input directory:"
  print,  dir_inputdef + "/input/backup/*parameters.txt, or"
  print, "restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
endelse


;;==============================================================================
;;==============================================================================
;; apply parc settings in a loop over all tif images 
;;==============================================================================
;;==============================================================================
fn_logfile = dir_output + '/parc.log'
nr_im_files = ct_tifs & time00 = systime( / sec) & okfile = 0l
nocheck = file_info(dir_input + '/nocheck.txt') & nocheck = nocheck.exists

openw, 9, fn_logfile
if nocheck eq 0 then printf,9,GWB_mv else printf,9, GWB_mv + ' - nocheck'
printf, 9, 'Parcellation batch processing logfile: ', systime()
printf, 9, 'Number of files to be processed: ', nr_im_files
printf, 9, '==============================================='
close, 9
;; write out the path to the logfile to append RAM usage later on
fn_dirs2 = strmid(fn_dirs,0,strlen(fn_dirs)-12) + 'gwb_parc_log.txt'
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
  printf, 9, 'up to 22x RAM needed [GB]: ' + strtrim(imsizeGB*22.0,2)
  close, 9

  res = strpos(input,' ') ge 0
  IF res EQ 1 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (empty space in directory path or input filename)'
    close, 9
    GOTO, skip_par  ;; invalid input
  ENDIF
  
  res = query_tiff(input, inpinfo)
  IF inpinfo.type NE 'TIFF' THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (not a TIF image)'
    close, 9
    GOTO, skip_par  ;; invalid input
  ENDIF
 
  ;; check for single image in file
  IF inpinfo.num_images GT 1 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (more than 1 image in the TIF image)'
    close, 9
    GOTO, skip_par  ;; invalid input
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
    GOTO, skip_par  ;; invalid input
  ENDIF

  ;; check for byte/integer array
  ;;===========================
  tt = size(im, / type) & bi = [1, 2, 12, 3, 13, 14, 15]
  ;; byte or integer is one of the bi above
  q = where(tt eq bi, ct, /l64)
  IF ct eq 0 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (image is not of type BYTE or INTEGER)'
    close, 9
    GOTO, skip_par  ;; invalid input
  ENDIF
  
  mi = min(im, / nan, max=ma)
  IF mi EQ ma THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (image has only one class)'
    close, 9
    GOTO, skip_par  ;; invalid input
  ENDIF
  
  
  
  good2go:
  im = rotate(temporary(im),7) & sz=size(im,/dim) & xdim=sz[0] & ydim=sz[1]
  ;;==============================================================================
  ;; 2) process for PARC
  ;;==============================================================================
  time0 = systime( / sec)
  
  ;; label map for all classes
  ;; get uniq classes
  mi = min(im, /nan) & q = where(histogram(im, /L64, min=mi) GT 0, nr_classes) & classes = q+mi
  sz = size(im) & qmiss=where(im eq 0b,ctmiss, /l64) & data_area = sz[4]-float(ctmiss)
  ;; add outside frame of 0 to make label_region work
  ext1 = lonarr(sz(1) + 2, sz(2) + 2)
  ext1[1:sz(1), 1:sz(2)] = long(temporary(im))
  parc = 0.0 & vclass = 0 & parcels = 0l;; initialize
  p_vclass = ulon64arr(nr_classes) & p_qclass = p_vclass & p_mx = p_vclass
  p_atot = fltarr(nr_classes) & p_ba = [-1] & p_aps = p_atot
  p_aaps_rel = p_atot & p_aaps = p_atot & p_parc = p_atot & p_div_rel = p_atot
  div_up = -alog(1.0e-6) & div_scale = 100.0/div_up

  ;; loop through all classes
  for idx = 0, nr_classes-1 do begin
    qclass = classes[idx]
    if qclass ne 0 then begin ;; only proceed for classes other than 0 (reserved for nodata)
      vclass = vclass + 1
      blob = label_region(ext1 eq qclass, all_neighbors=conn8, / ulong) & mx = max(blob)
      barea = histogram(temporary(blob),/l64) & parcels = parcels + mx
      ba = barea[1:mx] & atot = total(ba,/double) & aps = atot/mx
      ;; meshsize/area averaged mean patch size:
      s = total(ba^2,/double) & aaps_rel = s/atot & aaps  = s/data_area
      ;; division index:
      s = total((ba/atot)^2,/double) & div_rel = 1.0 - s
      ;; alog-scale division index, set lower end to 20.0, then scale into [100, 1]%
      div = -alog(s) & div = div_up < div & parc = div_scale * abs(div)

      ;; put in array
      p_ba = [ba,[p_ba]]
      p_vclass[idx] = vclass & p_qclass[idx] = qclass & p_mx[idx] = mx
      p_atot[idx] = atot & p_div_rel[idx] = div_rel & p_parc[idx] = parc
      p_aps[idx] = aps & p_aaps_rel[idx] = aaps_rel & p_aaps[idx] = aaps
    endif
  endfor
  ext1 = 0

  ;; write stuff out to file
  ;; filter out 0-entry (if present) in array
  q = where(p_vclass eq 0, ct, /l64)
  if ct gt 0 then begin
    q=q[0]
    if q eq 0 then begin ;; all class numbers have positive numbers
      z = n_elements(p_vclass)
      if z eq 1 then begin ;; there is only one class in the image
        p_qclass = p_vclass & aps = 0.0 & aaps = 0.0 & div_im = 0.0 & parc = 0.0 
        goto, skip_parcb
      endif
      p_vclass = p_vclass[1:*] & p_qclass = p_qclass[1:*] & p_mx = p_mx[1:*]
      p_atot = p_atot[1:*] & p_aps = p_aps[1:*] & p_parc = p_parc[1:*]
      p_aaps_rel = p_aaps_rel[1:*] & p_aaps = p_aaps[1:*] & p_div_rel = p_div_rel[1:*]
    endif else begin ;; we have also negative class numbers
      q1=q-1 & q2=q+1
      p_vclass = [p_vclass[0:q1],p_vclass[q2:*]]
      p_qclass = [p_qclass[0:q1],p_qclass[q2:*]]
      p_mx = [p_mx[0:q1],p_mx[q2:*]]
      p_atot = [p_atot[0:q1],p_atot[q2:*]]
      p_aps = [p_aps[0:q1],p_aps[q2:*]]
      p_aaps_rel = [p_aaps_rel[0:q1],p_aaps_rel[q2:*]]
      p_aaps = [p_aaps[0:q1],p_aaps[q2:*]]
      p_div_rel = [p_div_rel[0:q1],p_div_rel[q2:*]]
      p_parc = [p_parc[0:q1],p_parc[q2:*]]
    endelse
  endif
  z = n_elements(p_vclass)
  
  ;; overall image values
  ;;===================================
  aps = data_area/parcels
  ;; amend p_ba: take off the last entry which is -1 from the original definition
  p_ba = p_ba[0:n_elements(p_ba)-2]
  aaps = total((p_ba^2),/double)/data_area
  ;; division index:
  s = total((p_ba/data_area)^2,/double) & div_im = 1.0 -s
  div = -alog(s) & div = div_up < div & parc = div_scale * abs(div )
  
  skip_parcb:  
  ;;=======================================
  ;; write the final result
  fbn = file_basename(list[fidx], '.tif')
  outdir = dir_output + '/' + fbn + '_parc' & file_mkdir, outdir

  ;; the parcellation statistics: csv
  fn_out = outdir + '/' + fbn + '_parc.csv'
  close,12 & openw,12, fn_out
  printf,12, 'Class, Value, Count, Area[pixels], APS, AWAPS, AWAPS/data, DIVISION, PARC[%]'
  for idx = 0, z-1 do printf, 12, strtrim(p_vclass[idx],2) + ',' + strtrim(p_qclass[idx],2) + ',' + $
    strtrim(p_mx[idx],2) + ',' + strtrim(p_atot[idx],2) + ',' + strtrim(p_aps[idx],2) + ',' + $
    strtrim(p_aaps_rel[idx],2) + ',' + strtrim(p_aaps[idx],2)+ ',' + $
    strtrim(p_div_rel[idx],2) + ',' + strtrim(p_parc[idx],2)
  if conn8 eq 1 then pp1 = ' (8-connected ' else pp1 = ' (4-connected ' & z10 = strtrim(parcels,2)
  pp = strmid(pp1,2,strlen(pp1)-2) + 'Parcels:, ,' + z10 + ', ' + strtrim(ulong64(data_area),2) + ',' + $
    strtrim(aps,2) + ', ,' + strtrim(aaps,2) + ',' + strtrim(div_im,2) + ',' + strtrim(parc,2)
  printf, 12, pp & close, 12
  
  ;; txt file
  fn_out = outdir + '/' + fbn + '_parc.txt'
  close, 12 & openw, 12, fn_out
  printf,12, '     Class   Value      Count     Area[pixels]     APS          AWAPS       AWAPS/data     DIVISION      PARC[%]'
  for idx = 0, z-1 do printf, 12, format = '(2(i8), i12, i14, 5(f14.4))', p_vclass[idx], p_qclass[idx], $
    p_mx[idx], p_atot[idx], strtrim(p_aps[idx],2), $
    strtrim(p_aaps_rel[idx],2), strtrim(p_aaps[idx],2), strtrim(p_div_rel[idx],2), strtrim(p_parc[idx],2)
  printf, 12,'================================================================================================================'
  if conn8 eq 1 then pp1 = '8-conn. Parcels: ' else pp1 = '4-conn. Parcels: '
  printf, 12, format = '(a16, a12, i14, f14.4, a14, 3(f14.4))', pp1, z10, data_area, aps, ' ', aaps, div_im, parc
  close, 12
    
  okfile = okfile + 1

  openw, 9, fn_logfile, /append 
  printf, 9, 'Parcellation comp.time [sec]: ', systime( / sec) - time0
  close, 9
  
  skip_par: 
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
printf, 9, 'PARC Batch Processing total comp.time: ', proctstr
printf, 9, 'Successfully processed files: ',strtrim(okfile,2)+'/'+ strtrim(nr_im_files,2)
printf, 9, '==============================================='
close, 9

print, 'PARC finished sucessfully'

fin:
END
