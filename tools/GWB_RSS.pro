PRO GWB_RSS
;;==============================================================================
;;          GWB script for Restoration Status Summary Analysis (RSS)
;;==============================================================================
;; 
;; Purpose: 
;;==============================================================================
;; IDL cmd-line script to conduct RSS as implemented in GuidosToolbox (GTB)
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
GWB_mv = 'GWB_RSS (version 2.0.0)'
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
;; 1.8.4: reduced memory footprint
;; 1.8.3: amended tabular output with restoration potential
;; 1.7.0: initial release
;;
;;==============================================================================
;; Input: at least 1 file in the subfolder "input"
;;==============================================================================
;; a) input image(s) (geotiff):
;; at least 1 or more geotiff images in the subfolder "input"
;; the input image must have the assignment:
;; 0 byte: missing or no-data (optional)
;; 1 byte: not allowed
;; 2 byte: foreground pixels (mandatory)
;; 3-100 byte: background resistance (mandatory)
;; 101 byte and larger are not allowed
;; 
;; b) rss-parameters.txt: 8/4-connectivity
;;
;;==============================================================================
;; Output: in the subfolder "output"
;;==============================================================================
;; a) Summary statistics 
;;
;; Processing steps:
;; 1) verify parameter file and compatibility of input image
;; 2) process for RSS
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
print,'GWB_RSS using:'
if standalone eq 1 then dir_input = dir_inputdef + "/input"
if standalone eq 1 then dir_output = dir_inputdef + "/output"
print, 'dir_input= ', dir_input 
print, 'dir_output= ', dir_output

;; verify to have tif image(s) (should be a geotiff)
pushd, dir_input & list = file_search('*.tif', count=ct_tifs) & popd
IF ct_tifs EQ 0 THEN BEGIN
  print, "The input directory does not contain an image with the extension '.tif'"
  print, 'Please copy your geotiff image here. Exiting...'
  goto,fin
ENDIF
mod_params = dir_input + '/rss-parameters.txt'
IF (file_info(mod_params)).exists EQ 0b THEN BEGIN
  print, "The file: " + mod_params + "  was not found."
  print, "Please copy the respective backup file into your input directory:"
  print,  dir_inputdef + "/input/backup/*parameters.txt, or"
  print, "restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
ENDIF

;;==============================================================================
;; verify parameter file
;;==============================================================================
;; read rss settings: 4/8-conn, we need at least 1 valid line
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

;;==============================================================================
;;==============================================================================
;; run RSS in a loop over all tif images 
;;==============================================================================
;;==============================================================================
fn_logfile = dir_output + '/rss' + conn8_str + '.log'
fn_rssfile = dir_output + '/rss' + conn8_str + '.csv'
nr_im_files = ct_tifs & time00 = systime( / sec) & okfile = 0l
nocheck = file_info(dir_input + '/nocheck.txt') & nocheck = nocheck.exists
conn8 = conn8_str eq '8'

openw, 9, fn_logfile
if nocheck eq 0 then printf,9,GWB_mv else printf,9, GWB_mv + ' - nocheck'
printf, 9, 'RSS batch processing logfile: ', systime()
printf, 9, 'Number of files to be processed: ', nr_im_files
printf, 9, 'FG-connectivity: ' + conn8_str
printf, 9, '==============================================='
close, 9
;; write out the path to the logfile to append RAM usage later on
fn_dirs2 = strmid(fn_dirs,0,strlen(fn_dirs)-12) + 'gwb_rss_log.txt'
close, 1 & openw, 1, fn_dirs2 & printf, 1, fn_logfile & close, 1

;; open the summary spreadsheet for all files
close, 1 & openw, 1, fn_rssfile
printf, 1, 'REP_UNIT, AREA, RAC[%], NR_OBJ, LARG_OBJ, APS, CNOA, ECA, COH[%], REST_POT[%]'
close, 1

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
    GOTO, skip_rss  ;; invalid input
  ENDIF
  
  res = query_tiff(input, inpinfo)
  IF inpinfo.type NE 'TIFF' THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (not a TIF image)'
    close, 9
    GOTO, skip_rss  ;; invalid input
  ENDIF
 
  ;; check for single image in file
  IF inpinfo.num_images GT 1 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (more than 1 image in the TIF image)'
    close, 9
    GOTO, skip_rss  ;; invalid input
  ENDIF

  ;; read it
  geotiff = 0
  im = read_tiff(input, geotiff=geotiff)
  IF nocheck EQ 1b THEN goto, good2go

  ;; check for single channel image
  ;;===========================
  IF size(im, / n_dim) NE 2 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (more than 1 band in the TIF image)
    close, 9
    GOTO, skip_rss  ;; invalid input
  ENDIF

  ;; check for byte array
  ;;===========================
  IF size(im, / type) NE 1 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (image is not of type BYTE)'
    close, 9
    GOTO, skip_rss  ;; invalid input
  ENDIF

  ;; check image values
  ;;===========================
  histo = histogram(im, min=0, /l64)
  IF histo[2] EQ 0 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input file (no FG-objects - 2b)'
    close, 9
    GOTO, skip_rss
  ENDIF

  good2go:
  ;;==============================================================================
  ;; 2) process for RSS
  ;;==============================================================================
  time0 = systime( / sec)
  
  ;; check for missing  pixels
  ctqm = 0 &  qm = where(im EQ 0b, ctqm, /l64)
  eew = 2  & eew2 = eew * 2 & sz = size(im)
  ext = bytarr(sz[1] + eew2, sz[2] + eew2)
  ext[eew:eew + sz[1] - 1, eew:eew + sz[2] - 1] = temporary(im) eq 2b
  data_area = float(sz[4]) - ctqm
  im = temporary(ext)

  ;; FG-components
  lbl_comp = label_region(im, all=conn8, / ulong)
  nr_comp = max(lbl_comp) ;; total # of components
  h_comp_area = histogram(lbl_comp, /l64)
  obj_big = max(h_comp_area[1: * ])
    
  ;; PCnum:= overall connectivity. Sum of [ (areas per component)^2 ]
  pcnum_orig = total((h_comp_area[1: * ])^2, / double)

  ;; ECA: equivalent connected component area = sqrt(pcnum) [unit area, hectares]
  ECA_orig = sqrt(pcnum_orig)
  ECA_max = total(h_comp_area[1: * ],/double)
  DOC_orig = ECA_orig/ECA_max*100.0
  REST_POT = 100.0-doc_orig
  RAC_orig = ECA_max / data_area *100.0
  aps = ECA_MAX/nr_comp
  ;; CNOA: Criticial New Object Area
  b = ECA_max & c = ECA_orig
  CNOA = (2.0 * b * c^2)/(b^2 - c^2)
  CNOA = ulong64(cnoa+1.0)
  input2 = file_basename(input)
  
  ;;if nocheck eq 1b then save, h_comp_area, nr_comp, data_area, filename=dir_output + '/'+input2+'.sav'
 
  rowstr = input2 + ',' + strtrim(eca_max,2) + ',' + strtrim(rac_orig,2) + ',' + $
    strtrim(nr_comp,2) + ',' + strtrim(obj_big, 2) + ',' + $
    strtrim(aps, 2) + ',' + strtrim(cnoa, 2) + ',' + $
    strtrim(eca_orig,2) + ',' + strtrim(doc_orig,2) + ',' + strtrim(rest_pot,2)
  openw, 1, fn_rssfile, /append
  printf, 1, rowstr
  close, 1

  ;; update the log-file
  okfile = okfile + 1
  openw, 9, fn_logfile, /append
  printf, 9, 'RSS comp.time [sec]: ', systime( / sec) - time0
  close, 9

  skip_rss:
  print, 'Done with: ' + file_basename(input)
  ;; clean up
  qm=0 & res=0 & hist=0 & ctqm=0 & qm=0 & lbl_comp=0 & im=0 & h_comp_area=0

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
printf, 9, 'RSS Batch Processing total comp.time: ', proctstr
printf, 9, 'Successfully processed files: ',strtrim(okfile,2)+'/'+ strtrim(nr_im_files,2)
printf, 9, '==============================================='
close, 9

print, 'RSS finished sucessfully'

fin:
END
