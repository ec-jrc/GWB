PRO GWB_FOSCHANGE
;;==============================================================================
;; GWB script for FOSchange:
;; Change of Fragmentation/Connectivity for two GTB/GWB-generated directories of
;; FAD/FEC/FAC analysis at Fixed Observation Scale (FOS)
;;==============================================================================
;; 
;; Purpose: 
;;==============================================================================
;; IDL cmd-line script to conduct change of FAD/FED/FAC (no FAD/FED/FAC-APP!)
;; (https://forest.jrc.ec.europa.eu/en/activities/lpa/gtb/)
;; more info in the GTB manual and the Fragmentation/Connectivity productsheet:
;; (https://ies-ows.jrc.ec.europa.eu/gtb/GTB/psheets/GTB-Fragmentation-FADFOS.pdf)
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
GWB_mv = 'GWB_FOSCHANGE (version 1.9.9)'
;;
;; Module changelog:
;; 1.9.9: initial release
;;
;;==============================================================================
;; Input: two directories of GTB/GWB-generated FOS-analysis using FAD/FED/FAC 
;; for example '$HOME/input/FOS1' and '$HOME/input/FOS2'
;;==============================================================================
;;foschange-parameters.txt: (see info in input/foschange-parameters.txt)
;;a) full path to the GTB/GWB-generated FOS-directory at time A with 5 elements:
;;   the <FAD/FED/FAC>.png (histogram graph)
;;   the <FAD/FED/FAC>.sav (IDL-formatted summary statistics)
;;   the <FAD/FED/FAC>.tif (GeoTIFF map of fragmentation/connectivity)
;;   the <FAD/FED/FAC>.csv (fragmentation/connectivity summary spreadsheet)
;;   the <FAD/FED/FAC>.txt (fragmentation/connectivity summary plain text file)
;;b) full path to the GTB/GWB-generated FOS-directory at time B with 5 elements:
;;   the <FAD/FED/FAC>.png (histogram graph)
;;   the <FAD/FED/FAC>.sav (IDL-formatted summary statistics)
;;   the <FAD/FED/FAC>.tif (GeoTIFF map of fragmentation/connectivity)
;;   the <FAD/FED/FAC>.csv (fragmentation/connectivity summary spreadsheet)
;;   the <FAD/FED/FAC>.txt (fragmentation/connectivity summary plain text file)
;;
;;==============================================================================
;; Output: in the folder "output"
;;==============================================================================
;; a) FOSchange_hist.csv (FOSchange histogram and change statistics)
;; b) FOSchange.csv      (FOSchange matrix)
;; c) FOSchange.png      (FOSchange histogram graph)
;; d) FOSchange.tif      (FOSchange GeoTIFF map)
;;
;; Processing steps:
;; 1) verify parameter file and compatibility of the two input images
;; 2) process for FOSchange
;; 3) post-process (write-out and dostats)
;;
;;==============================================================================
;;==============================================================================
device, decomposed = 0
;; initial system checks
gpref = 'unset LD_LIBRARY_PATH; '
gdi = gpref + 'gdalinfo -noct '
desc = 'GTB_FOSCHANGE, https://forest.jrc.ec.europa.eu/en/activities/lpa/gtb/'
tagsw = 'TIFFTAG_SOFTWARE='+'"'+"GWB, https://forest.jrc.ec.europa.eu/en/activities/lpa/gwb/" +'" '
gedit = gpref + 'gdal_edit.py -mo ' + tagsw
gedit = gedit + '-mo TIFFTAG_IMAGEDESCRIPTION="'+desc + '" '
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

res = file_info(fn_dirs) ;; this or splitlump startup check?
IF res.exists EQ 1b THEN BEGIN
  ;; read user-specified directories
  openr, 1, fn_dirs & readf,1,tt & close,1
  dir_input = tt[0] & dir_output = tt[1]
  standalone = 0
ENDIF

;; echo selected directories 
print,'GWB_FOSCHANGE using:'
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
IF (file_info('idl/foschangecolors.sav')).exists EQ 0b THEN BEGIN
  print, "The file 'tools/idl/foschangecolors.sav' was not found."
  print, "Restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
ENDIF


mod_params = dir_input + '/foschange-parameters.txt'
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
;; read frag settings, we need at least 2 valid lines
fl = file_lines(mod_params)
IF fl LT 2 THEN BEGIN
  print, "The file: " + mod_params + " is in a wrong format."
  print, "Please copy the respective backup file into your input directory:"
  print,  dir_inputdef + "/input/backup/*parameters.txt, or"
  print, "restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
ENDIF
;; check the input parameters
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

;;==============================================================================
;; 1b) check directories and tif/sav files for compliance
;;==============================================================================
;; 1) dir_input1
dir_input1 = strtrim(finp(q[0]), 2)
res = strpos(dir_input1,' ') ge 0
IF res EQ 1 THEN BEGIN
  print, "Empty space in pathname of FOS1 directory : " + dir_input1
  print, "Exiting..."
  GOTO, fin
ENDIF
res = file_info(dir_input1)
IF res.directory EQ 0b THEN BEGIN
  print, "Pathname of FOS1 is not a directory: " + dir_input1
  print, "Exiting..."
  GOTO, fin
ENDIF

;; 2) dir_input2
dir_input2 = strtrim(finp(q[1]), 2)
res = strpos(dir_input2,' ') ge 0
IF res EQ 1 THEN BEGIN
  print, "Empty space in pathname of FOS2 directory : " + dir_input2
  print, "Exiting..."
  GOTO, fin
ENDIF
res = file_info(dir_input2)
IF res.directory EQ 0b THEN BEGIN
  print, "Pathname of FOS2 is not a directory: " + dir_input2
  print, "Exiting..."
  GOTO, fin
ENDIF

;; 3) dir_output must exist and be empty
res = file_info(dir_output)
IF res.directory EQ 0b THEN BEGIN
  print, "Pathname of 'output' is not a directory: " + dir_output
  print, "Exiting..."
  GOTO, fin
ENDIF
IF res.write EQ 0b THEN BEGIN
  print, "no write-permissions in 'output' directory: " + dir_output
  print, "Exiting..."
  GOTO, fin
ENDIF
;; check if empty
pushd, dir_output
list = file_search()
IF list[0] NE '' THEN BEGIN
  print, "Please empty the 'output' directory: " + dir_output
  print, "Exiting..."
  popd
  GOTO, fin
ENDIF
popd
;; dir_output exists and is empty

;; now verify to have one sav and one tif image in dir_input1
pushd, dir_input1 & im1_file = file_search('*.tif', count=ct_tifs) & im1_sav = file_search('*.sav', count=ct_savs) & popd
IF ct_tifs NE 1 THEN BEGIN
  print, "The foschange input directory 1 does not or has more than one image with the extension '.tif'"
  print, 'Please use an unmodified GTB/GWB-generated FOS-analysis directory.'
  print, "Exiting..."
  goto,fin
ENDIF
IF ct_savs NE 1 THEN BEGIN
  print, "The foschange input directory 1 does not or has more than one file with the extension '.sav'"
  print, 'Please use an unmodified GTB/GWB-generated FOS-analysis directory.'
  print, "Exiting..."
  goto,fin
ENDIF
;; verify to have one sav and one tif image in dir_input2
pushd, dir_input2 & im2_file = file_search('*.tif', count=ct_tifs) & im2_sav = file_search('*.sav', count=ct_savs)  & popd
IF ct_tifs NE 1 THEN BEGIN
  print, "The foschange input directory 2 does not or has more than one image with the extension '.tif'"
  print, 'Please use an unmodified GTB/GWB-generated FOS-analysis directory.'
  print, "Exiting..."
  goto,fin
ENDIF
IF ct_savs NE 1 THEN BEGIN
  print, "The foschange input directory 2 does not or has more than one file with the extension '.sav'"
  print, 'Please use an unmodified GTB/GWB-generated FOS-analysis directory.'
  print, "Exiting..."
  goto,fin
ENDIF
im1_file = im1_file[0] & im2_file = im2_file[0] & im1_sav = im1_sav[0] & im2_sav = im2_sav[0]

;; test if names match
IF file_basename(im1_file,'.tif') NE file_basename(im1_sav,'.sav') THEN BEGIN
  print, "The foschange input directory 1 has a non-matching 'tif-sav' setup"
  print, 'Please use an unmodified GTB/GWB-generated FOS-analysis directory.'
  print, "Exiting..."
  goto,fin
ENDIF
IF file_basename(im2_file,'.tif') NE file_basename(im2_sav,'.sav') THEN BEGIN
  print, "The foschange input directory 2 has a non-matching 'tif-sav' setup"
  print, 'Please use an unmodified GTB/GWB-generated FOS-analysis directory.'
  print, "Exiting..."
  goto,fin
ENDIF

IF im1_file EQ im2_file THEN BEGIN
  msg = 'You have selected the same image for Images A and B.'
  print, "Exiting..."
  GOTO, fin
ENDIF


;;==============================================================================
;; 1c) investigate geoheader of image A and B
;;==============================================================================
cmd = gdi + dir_input1+'/'+im1_file & spawn, cmd, log1 & q = log1[0] & q = (q EQ 'Driver: GTiff/GeoTIFF')
qq=where(strmid(log1,0,34) eq "  TIFFTAG_IMAGEDESCRIPTION=GTB_FOS") & qq=qq[0]
IF q eq 0b OR qq LE 0 THEN BEGIN
  print, 'Input image A is not a geotiff or not a GTB/GWB-generated *_fos*.tif image.' 
  print, "Exiting..."
  GOTO, fin
ENDIF

cmd = gdi + dir_input2+'/'+im2_file & spawn, cmd, log2 & q = log2[0] & q = (q EQ 'Driver: GTiff/GeoTIFF')
qq=where(strmid(log2,0,34) eq "  TIFFTAG_IMAGEDESCRIPTION=GTB_FOS") & qq=qq[0]
IF q eq 0b OR qq LE 0 THEN BEGIN
  print, 'Input image B is not a geotiff or not a GTB/GWB-generated *_fos*.tif image.'
  print, "Exiting..."
  GOTO, fin
ENDIF

;; geoheader must be identical besides filename and metadata
cmd = gdi + ' -nomd ' + dir_input1+'/'+im1_file & spawn, cmd, log1 
cmd = gdi + ' -nomd ' + dir_input2+'/'+im2_file & spawn, cmd, log2
;; check for same coverage in geotiff
q1 = (strmatch(log1[0],'*GeoTIFF*') + strmatch(log2[0],'*GeoTIFF*')) EQ 2b
q = where(log1[5:*] NE log2[5:*],ct)

;;IF (q1 eq 1b) AND (q NE -1) THEN BEGIN ;; we have both GeoTIFF and equal coverage geotiff
IF (q1 NE 1b) THEN BEGIN ;; we have both GeoTIFF and equal coverage geotiff
  print, 'Input image A or B is not a GeoTIFF'
  print, "Exiting..."
  GOTO, fin
ENDIF

;;==============================================================================
;; 1d) restore and check the sav-files
;;==============================================================================
;; test for same graythreshold, input data type, and analysis scheme: fostype/fadtype
a_grayt_str = '' & a_fosinp = '' & a_fostype = ''
restore, filename = dir_input1 + '/' + im1_sav
;; should contain the following variables:
;; from GWB processing:
;; GRAYT_STR, FRAGTYPE,                , XDIM, YDIM, GEOTIFF_LOG, RARE, PATCHY, TRANSITIONAL, DOMINANT, INTERIOR, INTACT
;; SEPARATED, CONTINUOUS, FAD_AV, FADRU_AV, FGAREA, KDIM_STR, OBJ_LAST, CONN_STR, PIXRES_STR, KDIM, HEC, ACR
;; from GTB processing:
;; GRAYT_STR, FOSINP, FOSTYPE, FOSCLASS, XDIM, YDIM, GEOTIFF_LOG, RARE, PATCHY, TRANSITIONAL, DOMINANT, INTERIOR, INTACT
;; SEPARATED, CONTINUOUS, FAD_AV, FADRU_AV, FGAREA, OBJ_LAST, CONN_STR, PIXRES_STR, KDIM_STR, HEC, ACR.

if (size(fragtype))[1] eq 7 then begin ;; fragtype is used by GWB
  if strlen(fragtype) eq 9 then fostype = 'FOS'+strmid(fragtype,8)
  if strlen(fragtype) eq 5 then fostype = 'FOS'+strmid(fragtype,4)
  fosclass = fragtype+'class'
endif
a_xdim=xdim & a_ydim=ydim & a_fostype = fostype & s1len = strlen(a_fostype)
a_fosclass = fosclass & a_conn = conn_str & a_pres = pixres_str & a_kdim = kdim_str

;; check if fad_av was saved, if so then use it
a_tt = (size(fad_av))[1]
if a_tt eq 4 then a_fad_av = fad_av
a2_tt = (size(fadru_av))[1]
if a2_tt eq 4 then a_fadru_av = fadru_av


b_grayt_str = '' & b_fosinp = '' & b_fostype = ''
restore, filename = dir_input2 + '/' + im2_sav
if (size(fragtype))[1] eq 7 then begin ;; fragtype is used by GWB
  if strlen(fragtype) eq 9 then fostype = 'FOS'+strmid(fragtype,8)
  if strlen(fragtype) eq 5 then fostype = 'FOS'+strmid(fragtype,4)
endif

b_xdim=xdim & b_ydim=ydim & b_fostype = fostype & s2len = strlen(b_fostype)
b_fosclass = fosclass & b_conn = conn_str & b_pres = pixres_str & b_kdim = kdim_str
;; check if fad_av was saved, if so then use it
b_tt = (size(fad_av))[1]
if b_tt eq 4 then b_fad_av = fad_av
b2_tt = (size(fadru_av))[1]
if b2_tt eq 4 then b_fadru_av = fadru_av
fad_avok = a_tt + b_tt
fadru_avok = a2_tt + b2_tt

res = (a_xdim eq b_xdim) + (a_ydim eq b_ydim) + (strmid(a_conn,0,6) eq strmid(b_conn,0,6)) + (a_pres eq b_pres) + $
  (a_kdim eq b_kdim) + (a_fostype eq b_fostype) + (a_fosclass eq b_fosclass)


if res ne 7b then begin
  print, 'FOSchange analysis requires identical values for each of:' + string(10b) + $
    'X/Y-dimension, FG-connectivity, pixel resolution, window size, ' + string(10b) + $
    'FOS type (FAD/FED/FAC),and reporting class (5/6class).' + string(10b) + $
    'The settings of the two maps do not match. 
  print, "Exiting..."
  GOTO, fin
endif

;; grayscale stuff
IF a_grayt_str NE b_grayt_str THEN BEGIN
  print, 'FOSchange analysis requires comparing maps with the same grayscale threshold, which is not the case for the selected files:' + string(10b) + $
    'Image A: ' + a_grayt_str + string(10b) + 'Image B: ' + b_grayt_str 
  print, "Exiting..."
  GOTO, fin
ENDIF
IF a_fosinp NE b_fosinp THEN BEGIN
  print, 'FOSchange analysis requires comparing maps with the same data type analysis threshold, which is not the case for the selected files:' + string(10b) + $
    'Image A: ' + a_fosinp + string(10b) + 'Image B: ' + b_fosinp 
  print, "Exiting..."
  GOTO, fin
ENDIF

;; ensure it is not FOS-APP
if (s1len GT 4) OR (s2len GT 4) then begin
  print, 'FOSchange analysis cannot be applied to FOS-APP maps'
  print, "Exiting..."
  GOTO, fin 
endif

;;==============================================================================
;; 1d) read the two FOS maps
;;==============================================================================
im1 = read_tiff(dir_input1+'/'+im1_file)
im2 = read_tiff(dir_input2+'/'+im2_file, geotiff=geotiff)
;; the frag datasets have values for forest [0, 100], BG [101],
;; missing [102], special BG water [105], non-fragmenting BG [106]

;; test if maps are identical
q = where(im1 ne im2, ct, /l64) & q = 0
IF ct eq 0 THEN BEGIN
  print, 'Pixel values of Images A and B are identical.'
  print, "Exiting..."
  GOTO, fin
ENDIF

;; check for presence of non-fragm. BG pixels
q = where(im1 eq 106b, im1_nfBG, /l64) & im1_nfBG = im1_nfBG gt 0
q = where(im2 eq 106b, im2_nfBG, /l64) & im2_nfBG = im2_nfBG gt 0
IF im1_nfBG ne im2_nfBG THEN BEGIN
  print, 'One of the input images has non-fragmenting background pixels.' + string(10b) + $
    'A FOSchange analysis is only meaningful if either both or none' + string(10b) + $
    'of the two input images have non-fragmenting background pixels.' 
  print, "Exiting..."
  GOTO, fin
ENDIF

fn_logfile = dir_output + '/' + 'foschange.log'
time00 = systime( / sec) 
openw, 9, fn_logfile
printf,9,GWB_mv
printf, 9, 'FOSCHANGE processing logfile: ', systime()
printf, 9, 'FOS1: ' + dir_input1+im1_file
printf, 9, 'FOS2: ' + dir_input2+im2_file
close, 9
;; write out the path to the logfile to append RAM usage later on
fn_dirs2 = strmid(fn_dirs,0,strlen(fn_dirs)-12) + 'gwb_foschange_log.txt'
close, 1 & openw, 1, fn_dirs2 & printf, 1, fn_logfile & close, 1

;;==============================================================================
;; 2a) do the foschange map
;;==============================================================================
farea_a = total(im1 LT 101b,/double) & farea_b = total(im2 LT 101b,/double) & nc = farea_b - farea_a
;; a) the FOSchange (delta FOS) difference map
im = (im1 + 100b) - im2
;; now overplot all other types of forest-nonforest interactions
;; 250: gain - from nonforest to forest
x = (im1 EQ 101b) * (im2 LE 100b) & im = (x EQ 1b)*250b + (x EQ 0b)*temporary(im)
;; 251:loss - from forest to nonforest
x = (im1 LE 100b) * (im2 EQ 101b) & im = (x EQ 1b)*251b + (x EQ 0b)*temporary(im)
;; 252: background at both times
x = (im1 EQ 101b) * (im2 EQ 101b) & im = (x EQ 1b)*252b + (x EQ 0b)*temporary(im)
;; 253: special BG / water at either time
x = (im1 EQ 105b) OR (im2 EQ 105b) & im = (x EQ 1b)*253b + (x EQ 0b)*temporary(im)
;; 254: Missing at either time
x = (im1 EQ 102b) OR (im2 EQ 102b) & im = (x EQ 1b)*254b + (x EQ 0b)*temporary(im)

restore, 'idl/foschangecolors.sav' & tvlct, r, g, b
fn_out = dir_output +'/FOSchange.tif'
write_tiff, fn_out, im, red = r, green = g, blue = b, geotiff = geotiff, compression = 1
 spawn, gedit + fn_out + ' > /dev/null 2>&1'
;;==============================================================================
;; 2b) do the foschange histogram values as a table
;;==============================================================================
diffsim = temporary(im)
h = histogram(diffsim,/l64) & marea = (size(diffsim))[4]
h_rev = h & h_rev[0:200] = reverse(h[0:200])

ss = replicate('High decrease (red)',256) & ss[80:89] = 'Medium decrease (orange)'
ss[90:98] = 'Low decrease (yellow)' & ss[99:101] = 'Insignificant or no change (light gray)'
ss[102:110] = 'Low increase (light green)' & ss[111:120] = 'Medium increase (medium green)'
ss[121:200] = 'High increase (dark green)' & ss[201:249] = ' '
ss[250:*] = ['Foreground gain (BG->FG bright green)', 'Foreground loss (FG->BG black)', 'BG stable (BG->BG gray)',$
  'Water at one/both time(s) (blue)', 'Missing at one/both time(s) (white)', 'Outside at one/both time(s) (white)']
;; the delta value
ss2 = strtrim(indgen(256) - 100,2) & ss2[201:*] = ''
if strlen(fosclass) eq 10 then method = strmid(fosclass,0,3) else method = strmid(fosclass,0,7)

ch_pref = 'fos-' + strlowcase(fosclass)+ '_' + a_kdim
f_out = dir_output +'/FOSchange_hist.csv'
close, 1 & openw, 1, f_out
printf,1,'Pixel Value, Delta-' + method + ', Pixel Count, Connectivity'
;; show the full change entries of the histogram in [0, 200]
for i = 0, 200 do printf, 1, strtrim(i,2) + ', ' + ss2[i] + ', ' + strtrim(h_rev[i],2) + ', ' + ss[i]
;; skip the empty histogram entries, usually [201, 249] but if there are wrong ones then show them anyway
for i = 201, 255 do begin
  if h_rev[i] gt 0 then printf, 1, strtrim(i,2) + ', ' + ss2[i] + ', ' + strtrim(h_rev[i],2) + ', ' + ss[i]
endfor

;; 7-class statistical summary
x = indgen(201)-100 & y = h[0:200]
;; forcom = forest area at both times, which is subject to fragmentation change
;; equivalent to area under the histogram curve
forcom = total(y,/double)
dec3 = total(y[0:79],/double) / forcom * 100.0 & if finite(dec3) eq 0b then dec3 = 'NaN'
dec2 = total(y[80:89],/double) /forcom * 100.0 & if finite(dec2) eq 0b then dec2 = 'NaN'
dec1 = total(y[90:98],/double) / forcom * 100.0 & if finite(dec1) eq 0b then dec1 = 'NaN'
neu = total(y[99:101],/double) /forcom * 100.0 & if finite(neu) eq 0b then neu = 'NaN'
inc1 = total(y[102:110],/double) / forcom * 100.0 & if finite(inc1) eq 0b then inc1 = 'NaN'
inc2 = total(y[111:120],/double) / forcom * 100.0 & if finite(inc2) eq 0b then inc2 = 'NaN'
inc3 = total(y[121:*],/double) / forcom * 100.0 & if finite(inc3) eq 0b then inc3 = 'NaN'

printf, 1, ' '
if fadru_avok eq 8 then begin
  printf, 1, 'Average Connectivity at reporting unit level:'
  printf, 1, 'AVCON (A) [%]:, ' + strtrim(a_fadru_av,2)
  printf, 1, 'AVCON (B) [%]:, ' + strtrim(b_fadru_av,2)
  printf, 1, 'Delta AVCON (A->B) [%]:, ' + strtrim(b_fadru_av - a_fadru_av,2)
  printf, 1, ' '
endif
if fad_avok eq 8 then begin
  printf, 1, 'Average Connectivity at foreground level:'
  printf, 1, 'FOS-Type:, ' + strtrim(fosclass,2)
  printf, 1, 'Method:, ' + method
  printf, 1, 'Reporting classes:, ' + strmid(fostype,3)
  printf, 1, 'Average ' + method + ' (A) [%]:, ' + strtrim(a_fad_av,2)
  printf,1, 'Average ' + method + ' (B) [%]:, ' + strtrim(b_fad_av,2)
  printf,1, 'Delta ' + method + ' (A->B) [%]:, ' + strtrim(b_fad_av - a_fad_av,2)
  printf, 1, ' '
endif
printf, 1, 'Map area [pixels]:,' + strtrim(marea,2)
printf, 1, 'Foreground cover at time A [pixels]:,' + strtrim(farea_a,2)
printf, 1, 'Foreground cover at time B [pixels]:,' + strtrim(farea_b,2)
printf, 1, 'Net foreground cover change (A->B) [pixels]:,' + strtrim(nc,2)
printf, 1, 'FORCOM: common foreground cover at both times [pixels]:,' + strtrim(forcom,2)
printf, 1, 'Percentage of FORCOM in Connectivity change category'
printf, 1, 'High connectivity decrease [%]:,' + strtrim(inc3,2)
printf, 1, 'Medium connectivity decrease [%]:,' + strtrim(inc2,2)
printf, 1, 'Low connectivity decrease [%]:,' + strtrim(inc1,2)
printf, 1, 'Insignificant/No Change [%]:,' + strtrim(neu,2)
printf, 1, 'Low connectivity increase [%]:,' + strtrim(dec1,2)
printf, 1, 'Medium connectivity increase [%]:,' + strtrim(dec2,2)
printf, 1, 'High connectivity increase [%]:,' + strtrim(dec3,2)
close, 1

;;==============================================================================
;; 2c) do the foschange barplot
;;==============================================================================
y100 = y[100] & y[100] = 0 & forcomc = total(y,/double)
xrg = 101 & wdt = 1.0 & y = h[0:200] 
if total(y[50:150])/forcomc gt 0.97 then xrg=51 ; was 51, 41 , etc
if total(y[60:140])/forcomc gt 0.97 then xrg=41
if total(y[70:130])/forcomc gt 0.97 then xrg=31
if total(y[80:120])/forcomc gt 0.97 then xrg=21
if total(y[90:110])/forcomc gt 0.97 then xrg=11

y = h_rev[0:200]/forcom*100.0  ;; convert to %
ymax = max(y)*1.05 & if ymax lt 1.0 then ymax = 1.05
tit = 'FOSchange'
b0 = barplot(x[99:101], y[99:101], xrange = [-xrg,xrg], yrange = [0, ymax], xticklen=0.02, yticklen=0.02, $
  title = tit, width=wdt, histogram = 0, ytitle = 'Frequency [%]', /buffer,thick=0, font_size=10, $ 
  xtitle = '<- connectivity decrease [% points] | connectivity increase [% points] ->', fill_color = [240,240,200])
b0 = barplot(x[90:98], y[90:98], width=wdt, histogram = 0, fill_color = [255,215,100],thick=0, /overplot) ;; small increase
b0 = barplot(x[80:89], y[80:89],width=wdt, histogram = 0, fill_color = [255,150,40],thick=0, /overplot) ;; medium increase
b0 = barplot(x[0:79], y[0:79],width=wdt, histogram = 0, fill_color = [205,75,0],thick=0, /overplot) ;; strong increase
b0 = barplot(x[102:110], y[102:110], width=wdt, histogram = 0, fill_color = [130,210,170],thick=0, /overplot) ;; small decrease
b0 = barplot(x[111:120], y[111:120], width=wdt, histogram = 0, fill_color = [90,170,130],thick=0, /overplot) ;; medium decrease
b0 = barplot(x[121:200], y[121:200], width=wdt, histogram = 0, fill_color = [60,130,90],thick=0, /overplot) ;; strong decrease
b0.save, dir_output + '/FOSchange.png', resolution=300

;;==============================================================================
;; 2d) do the foschange matrix
;;==============================================================================
;; exclude missing data from both maps, temporarily set them to 150b
q = where(im1 eq 102b or im2 eq 102b, ctmiss, /l64)
if ctmiss gt 0 then begin
  im1[q]=150b & im2[q]=150b
endif
;; collapse all background types in im1 and im2, temporarily set them to 110b
q = where(im2 gt 100b and im2 lt 150b, ct, /l64) & if ct gt 0 then im2[q]=110b
q = where(im1 gt 100b and im1 lt 150b, ct, /l64) & if ct gt 0 then im1[q]=110b


if fostype eq 'FOS5' then begin
  change = dblarr(6, 6) & change0 = change & ch = change0 ; reset change vector
  ;; get pixels of each class type in im1 and look what they changed to in im2
  if ct gt 0 then begin ;; im1 has BG-pixels
    h=histogram(im2[q]) & ch = [h[110],total(h[0:9]),total(h[10:39]),total(h[40:59]),total(h[60:89]),total(h[90:100])]
    change[*,0] = ch
  endif
  ch = ch*0 & q = where(im1 lt 10b, ct, /l64)
  if ct gt 0 then begin ;; im1 has rare pixels
    h=histogram(im2[q]) & ch = [h[110],total(h[0:9]),total(h[10:39]),total(h[40:59]),total(h[60:89]),total(h[90:100])]
    change[*,1] = ch
  endif
  ch = ch*0 & q = where(im1 ge 10b and im1 le 39b, ct, /l64)
  if ct gt 0 then begin ;; im1 has patchy pixels
    h=histogram(im2[q]) & ch = [h[110],total(h[0:9]),total(h[10:39]),total(h[40:59]),total(h[60:89]),total(h[90:100])]
    change[*,2] = ch
  endif
  ch = ch*0 & q = where(im1 ge 40b and im1 le 59b, ct, /l64)
  if ct gt 0 then begin ;; im1 has transitional pixels
    h=histogram(im2[q]) & ch = [h[110],total(h[0:9]),total(h[10:39]),total(h[40:59]),total(h[60:89]),total(h[90:100])]
    change[*,3] = ch
  endif
  ch = ch*0 & q = where(im1 ge 60b and im1 le 89b, ct, /l64)
  if ct gt 0 then begin ;; im1 has dominant pixels
    h=histogram(im2[q]) & ch = [h[110],total(h[0:9]),total(h[10:39]),total(h[40:59]),total(h[60:89]),total(h[90:100])]
    change[*,4] = ch
  endif
  ch = ch*0 & q = where(im1 ge 90b and im1 le 100b, ct, /l64)
  if ct gt 0 then begin ;; im1 has interior pixels
    h=histogram(im2[q]) & ch = [h[110],total(h[0:9]),total(h[10:39]),total(h[40:59]),total(h[60:89]),total(h[90:100])]
    change[*,5] = ch
  endif
endif else begin  ;; FOS 6-class
  change = dblarr(7, 7) & change0 = change & ch = change0 ; reset change vector
  ;; get pixels of each class type in im1 and look what they changed to in im2
  if ct gt 0 then begin ;; im1 has BG-pixels
    h=histogram(im2[q]) & ch = [h[110],total(h[0:9]),total(h[10:39]),total(h[40:59]),total(h[60:89]),total(h[90:99]),h[100]]
    change[*,0] = ch
  endif
  ch = ch*0 & q = where(im1 lt 10b, ct, /l64)
  if ct gt 0 then begin ;; im1 has rare pixels
    h=histogram(im2[q]) & ch = [h[110],total(h[0:9]),total(h[10:39]),total(h[40:59]),total(h[60:89]),total(h[90:99]),h[100]]
    change[*,1] = ch
  endif
  ch = ch*0 & q = where(im1 ge 10b and im1 le 39b, ct, /l64)
  if ct gt 0 then begin ;; im1 has patchy pixels
    h=histogram(im2[q]) & ch = [h[110],total(h[0:9]),total(h[10:39]),total(h[40:59]),total(h[60:89]),total(h[90:99]),h[100]]
    change[*,2] = ch
  endif
  ch = ch*0 & q = where(im1 ge 40b and im1 le 59b, ct, /l64)
  if ct gt 0 then begin ;; im1 has transitional pixels
    h=histogram(im2[q]) & ch = [h[110],total(h[0:9]),total(h[10:39]),total(h[40:59]),total(h[60:89]),total(h[90:99]),h[100]]
    change[*,3] = ch
  endif
  ch = ch*0 & q = where(im1 ge 60b and im1 le 89b, ct, /l64)
  if ct gt 0 then begin ;; im1 has dominant pixels
    h=histogram(im2[q]) & ch = [h[110],total(h[0:9]),total(h[10:39]),total(h[40:59]),total(h[60:89]),total(h[90:99]),h[100]]
    change[*,4] = ch
  endif
  ch = ch*0 & q = where(im1 ge 90b and im1 lt 100b, ct, /l64)
  if ct gt 0 then begin ;; im1 has interior pixels
    h=histogram(im2[q]) & ch = [h[110],total(h[0:9]),total(h[10:39]),total(h[40:59]),total(h[60:89]),total(h[90:99]),h[100]]
    change[*,5] = ch
  endif
  ch = ch*0 & q = where(im1 eq 100b, ct, /l64)
  if ct gt 0 then begin ;; im1 has 100-intact pixels
    h=histogram(im2[q]) & ch = [h[110],total(h[0:9]),total(h[10:39]),total(h[40:59]),total(h[60:89]),total(h[90:99]),h[100]]
    change[*,6] = ch
  endif
endelse

;; calculate percentage of change in the sub-matrix of change
mch = change[1:*,1:*]
;; null diagonal
diag = 0
if fostype eq 'FOS6' then nft = 5 else nft = 4
for ix = 0,nft do begin
  for iy = 0,nft do begin
    if ix eq iy then begin
      diag = diag + mch[ix,iy]
      mch[ix,iy] = 0
    endif
  endfor
endfor
chpix = total(mch)
perc = mch/chpix*100

;; sum of percentage with connectivity increase = above matrix diagonal
sum_above = total(perc[0:*,0],/double) + total(perc[1:*,1],/double) + total(perc[2:*,2],/double) + total(perc[3:*,3],/double)
if fostype eq 'FOS6' then sum_above = sum_above + total(perc[4:*,4],/double)
;; sum of percentage with connectivity decrease = below matrix diagonal
sum_below = total(perc,/double) - sum_above

uchange = strtrim(ulong64(change),2)
ch_pref = 'fos-' + strlowcase(fosclass)+ '_' + a_kdim

;; save the tables as a csv-file
z=strtrim(change,2) & zp=strtrim(perc,2)
f_out = dir_output + '/FOSchange.csv'

;; test if forcom is defined, else calculate it
IF total(size(forcom)) LT 0.1 THEN BEGIN
  forcom = total((im1 lE 100b)*(im2 LE 100b),/double)
ENDIF
close,12 & openw,12, f_out
printf,12, ch_pref + ': Fragmentation class change from A -> B'
;; try to write out more user-freindly
IF strmid(dir_input1,0,6) EQ '$HOME/' THEN dir_input1 = '/home/'+getenv('USER')+strmid(dir_input1,5)
IF strmid(dir_input2,0,6) EQ '$HOME/' THEN dir_input2 = '/home/'+getenv('USER')+strmid(dir_input2,5)
printf,12, 'A: ' + dir_input1 + '/' + im1_file
printf,12, 'B: ' + dir_input2 + '/' + im2_file
printf,12, 'Fragmentation class at observation scale: ' + strtrim(hec,2) + ' hectares/' + strtrim(acr,2) + ' acres'
printf,12, '(Pixel resolution: ' + pixres_str + '[m] Window size: ' + kdim_str + 'x' + kdim_str +')'
printf, 12, 'Foreground cover at time A [pixels]: ' + strtrim(farea_a,2)
printf, 12, 'Foreground cover at time B [pixels]: ' + strtrim(farea_b,2)
printf, 12, 'Net foreground cover change (A->B) [pixels]: ' + strtrim(nc,2)
if fadru_avok eq 8 then printf,12, 'AVCON (A->B) [%]: ' + strtrim(a_fadru_av,2) + ' -> ' + $
  strtrim(b_fadru_av,2) + ': ' + strtrim(b_fadru_av - a_fadru_av,2)
if fad_avok eq 8 then printf,12, strmid(fosclass,0,3) + '_av (A->B) [%]: ' + strtrim(a_fad_av,2) + ' -> ' + $
  strtrim(b_fad_av,2) + ': ' + strtrim(b_fad_av - a_fad_av,2)
printf,12, ' '
printf,12, 'Change matrix constrained to FORCOM: common foreground cover at both times [pixels]: ' + strtrim(forcom,2)
printf,12, 'Number of pixels in the same fragmentation class (matrix diagonal): ' + strtrim(diag,2)
printf,12, 'Number of pixels in different fragmentation classes: ' + strtrim(chpix,2)
if fostype eq 'FOS6' then begin
  printf,12, 'A->B [pixels], B0-Background, B1-Rare, B2-Patchy, B3-Transitional, B4-Dominant, B5-Interior, B6-Intact'
  printf,12, 'A0-Background,  '+z[0,0]+', '+z[1,0]+', '+z[2,0]+', '+z[3,0]+', '+z[4,0]+', '+z[5,0]+', '+z[6,0]
  printf,12, 'A1-Rare,        '+z[0,1]+', '+z[1,1]+', '+z[2,1]+', '+z[3,1]+', '+z[4,1]+', '+z[5,1]+', '+z[6,1]
  printf,12, 'A2-Patchy,      '+z[0,2]+', '+z[1,2]+', '+z[2,2]+', '+z[3,2]+', '+z[4,2]+', '+z[5,2]+', '+z[6,2]
  printf,12, 'A3-Transitional,'+z[0,3]+', '+z[1,3]+', '+z[2,3]+', '+z[3,3]+', '+z[4,3]+', '+z[5,3]+', '+z[6,3]
  printf,12, 'A4-Dominant,    '+z[0,4]+', '+z[1,4]+', '+z[2,4]+', '+z[3,4]+', '+z[4,4]+', '+z[5,4]+', '+z[6,4]
  printf,12, 'A5-Interior,    '+z[0,5]+', '+z[1,5]+', '+z[2,5]+', '+z[3,5]+', '+z[4,5]+', '+z[5,5]+', '+z[6,5]
  printf,12, 'A6-Intact,      '+z[0,6]+', '+z[1,6]+', '+z[2,6]+', '+z[3,6]+', '+z[4,6]+', '+z[5,6]+', '+z[6,6]
endif else begin
  printf,12, 'A->B [pixels], B0-Background, B1-Rare, B2-Patchy, B3-Transitional, B4-Dominant, B5-Interior'
  printf,12, 'A0-Background,  '+z[0,0]+', '+z[1,0]+', '+z[2,0]+', '+z[3,0]+', '+z[4,0]+', '+z[5,0]
  printf,12, 'A1-Rare,        '+z[0,1]+', '+z[1,1]+', '+z[2,1]+', '+z[3,1]+', '+z[4,1]+', '+z[5,1]
  printf,12, 'A2-Patchy,      '+z[0,2]+', '+z[1,2]+', '+z[2,2]+', '+z[3,2]+', '+z[4,2]+', '+z[5,2]
  printf,12, 'A3-Transitional,'+z[0,3]+', '+z[1,3]+', '+z[2,3]+', '+z[3,3]+', '+z[4,3]+', '+z[5,3]
  printf,12, 'A4-Dominant,    '+z[0,4]+', '+z[1,4]+', '+z[2,4]+', '+z[3,4]+', '+z[4,4]+', '+z[5,4]
  printf,12, 'A5-Interior,    '+z[0,5]+', '+z[1,5]+', '+z[2,5]+', '+z[3,5]+', '+z[4,5]+', '+z[5,5]
endelse
printf,12, '  '
printf,12, 'Change matrix constrained to the ' + strtrim(chpix,2) + ' pixels in different fragmentation classes [%]: '
printf,12, 'Fragmentation decrease (=connectivity increase) - above the matrix diagonal [%]: ' + strtrim(sum_above,2)
printf,12, 'Fragmentation increase (=connectivity decrease) - below the matrix diagonal [%]: ' + strtrim(sum_below,2)
if fostype eq 'FOS6' then begin
  printf,12, 'A->B [%], , B1-Rare, B2-Patchy, B3-Transitional, B4-Dominant, B5-Interior, B6-Intact'
  printf,12, 'A1-Rare      ,  ,'+zp[0,0]+','+zp[1,0]+','+zp[2,0]+','+zp[3,0]+','+zp[4,0]+','+zp[5,0]
  printf,12, 'A2-Patchy    ,  ,'+zp[0,1]+','+zp[1,1]+','+zp[2,1]+','+zp[3,1]+','+zp[4,1]+','+zp[5,1]
  printf,12, 'A3-Transitional, ,'+zp[0,2]+','+zp[1,2]+','+zp[2,2]+','+zp[3,2]+','+zp[4,2]+','+zp[5,2]
  printf,12, 'A4-Dominant  ,  ,'+zp[0,3]+','+zp[1,3]+','+zp[2,3]+','+zp[3,3]+','+zp[4,3]+','+zp[5,3]
  printf,12, 'A5-Interior  ,  ,'+zp[0,4]+','+zp[1,4]+','+zp[2,4]+','+zp[3,4]+','+zp[4,4]+','+zp[5,4]
  printf,12, 'A6-Intact    ,  ,'+zp[0,5]+','+zp[1,5]+','+zp[2,5]+','+zp[3,5]+','+zp[4,5]+','+zp[5,5]
endif else begin
  printf,12, 'A->B [%], , B1-Rare, B2-Patchy, B3-Transitional, B4-Dominant, B5-Interior'
  printf,12, 'A1-Rare      ,  ,'+zp[0,0]+','+zp[1,0]+','+zp[2,0]+','+zp[3,0]+','+zp[4,0]
  printf,12, 'A2-Patchy    ,  ,'+zp[0,1]+','+zp[1,1]+','+zp[2,1]+','+zp[3,1]+','+zp[4,1]
  printf,12, 'A3-Transitional, ,'+zp[0,2]+','+zp[1,2]+','+zp[2,2]+','+zp[3,2]+','+zp[4,2]
  printf,12, 'A4-Dominant  ,  ,'+zp[0,3]+','+zp[1,3]+','+zp[2,3]+','+zp[3,3]+','+zp[4,3]
  printf,12, 'A5-Interior  ,  ,'+zp[0,4]+','+zp[1,4]+','+zp[2,4]+','+zp[3,4]+','+zp[4,4]
endelse
close,12

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
printf, 9, '==============================================='
printf, 9, 'FOSCHANGE Processing total comp.time: ', proctstr
printf, 9, '==============================================='
close, 9

print, 'FOSchange finished sucessfully'

fin:
END
