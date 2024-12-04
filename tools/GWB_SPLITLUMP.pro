PRO GWB_SPLITLUMP
;;==============================================================================
;;   GWB APP for buffered splitting and lumping of a large image (SPLITLUMP)
;;   GWB: https://forest.jrc.ec.europa.eu/en/activities/lpa/gwb
;;==============================================================================
;;
;; Purpose:
;;==============================================================================
;; cmd-line app to cut a large image into buffered stripes for GWB processing:
;; a) splitter.sh: cut the large input map into buffered stripes
;; b) run the GWB_X module to do the processing of your choice
;; c) lumper.sh: cut the GWB-processed buffered stripes and reassemble them
;;    into the final resulting map
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
;;
;;==============================================================================
GWB_mv = 'GWB_SPLITLUMP (version 1.9.6)'
;;
;; Module changelog:
;; 1.9.6: add gpref, IDL 9.1.0
;; 1.9.4: IDL 9.0.0
;; 1.9.3: fixed standalone execution
;; 1.9.2: IDL 8.9.0, enforec working directory splitlump
;; 1.9.1: initial release
;;
;;==============================================================================
;; Input:
;;==============================================================================
;; a) splitlump-parameters.txt: (see info in input/splitlump-parameters.txt)
;;  - full path to the splitlump directory (must exist and must be empty)
;;  - full path to the large geotiff image of at least 12,000 x 12,000 pixels
;;  - number of buffered stripes
;;  - buffer width [pixels]
;;  - orientation of stripes: horizontal (default) OR vertical (MUCH slower)
;;
;;==============================================================================
;; Output: two shell scripts in the splitlump directory
;;==============================================================================
;; a) splitter.sh: bash script to cut the large input map into buffered stripes
;; b) lumper.sh: bash script to cut the GWB-processed buffered stripes and merge 
;;    them back into the final resulting map
;;
;; GWB_SPLITLUMP processing steps:
;; 1) verify the input/splitlump-parameters.txt parameter file
;; 2) setup the script splitter.sh and echo the respective stripe file size
;; 3) setup the script: ./lumper.sh
;;
;;==============================================================================
;;==============================================================================
;; initial system checks
gpref = 'unset LD_LIBRARY_PATH; '
gdi = gpref + 'gdalinfo -noct '
gtrans = gpref + 'gdal_translate -co COMPRESS=LZW -srcwin '
gedit = gpref + 'gdal_edit.py '
gbuildvrt = gpref + 'gdalbuildvrt '
;;==============================================================================
;; 0) get path to directories or use default
;;==============================================================================
spawn,'echo $USER',res & res = res[0]
fn_dirs = '/home/' + res + '/.gwb/gwb_dirs.txt'
tt = strarr(2) & close,1 & standalone = 1

;; default directories within application
pushd, '..' & cd, current = dir_inputdef & popd
dir_input = '../input'

res = file_info(fn_dirs)
IF res.exists EQ 1b THEN BEGIN
  ;; for splitlump we get the actual base directory of the splitlump-parameters.txt file location
  ;; from the file $HOME/.gwb/gwb_splitlump_param.txt
  ;; which is written by the bash script GWB_SPLITLUMP
  q = ' ' & fn = file_dirname(fn_dirs) + '/gwb_splitlump_param.txt'
  res = file_info(fn)
  IF res.exists EQ 0b THEN BEGIN ;; something went wrong
    print, "Please run again using the default location for splitlump-parameters.txt:"
    print, "$HOME/input/splitlump-parameters.txt"
    print, "Exiting..."
    goto,fin
  ENDIF 
  ;; read user-specified directories
  close, 1 & openr, 1, fn & readf,1,q & close,1
  dir_input = strtrim(file_dirname(q),2) 
  standalone = 0
ENDIF 

;; get full path of dir_input
pushd, dir_input & cd, current = dir_inputdef & popd
dir_input = dir_inputdef

;; retrive full path to mod_params
mod_params = dir_input + '/splitlump-parameters.txt'
IF (file_info(mod_params)).exists EQ 0b THEN BEGIN
  print, "The file: " + mod_params + "  was not found."
  print, "Please copy the respective backup file into your input directory:"
  print,  dir_inputdef + "/input/backup/*parameters.txt, or"
  print, "restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
ENDIF
print, 'parameter file: ' + mod_params

;;==============================================================================
;; 1a) verify parameter file
;;==============================================================================
;; read SPLITLUMP settings: we need at least 5 valid lines
fl = file_lines(mod_params)
IF fl LT 6 THEN BEGIN
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
IF ct LT 6 THEN BEGIN
  print, "The file: " + mod_params + " is in a wrong format."
  print, "Please copy the respective backup file into your input directory:"
  print,  dir_inputdef + "/input/backup/*parameters.txt, or"
  print, "restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
ENDIF

;; 1) dir_splitlump
dir_splitlump = strtrim(finp(q[0]), 2)
res = strpos(dir_splitlump,' ') ge 0
IF res EQ 1 THEN BEGIN
  print, "Empty space in pathname of splitlump directory : " + dir_splitlump
  print, "Exiting..."
  GOTO, fin
ENDIF
res = file_info(dir_splitlump)
IF res.directory EQ 0b THEN BEGIN
  print, "Pathname of splitlump is not a directory: " + dir_splitlump
  print, "Exiting..."
  GOTO, fin
ENDIF
;; check if empty
pushd, dir_splitlump
list = file_search()
IF list[0] NE '' THEN BEGIN
  print, "Please empty the splitlump directory: " + dir_splitlump
  print, "Exiting..."
  popd
  GOTO, fin
ENDIF
popd
;; dir_splitlump exists and is empty


;; 2) the large input image
input = strtrim(finp(q[1]), 2) & fbn = file_basename(input)
res = strpos(input,' ') ge 0
IF res EQ 1 THEN BEGIN
  print, "Empty space in pathname of large input image: " + fbn
  print, "Exiting..."
  GOTO, fin
ENDIF
;; first check that file path actually exists
res = file_info(input) & res = res.exists eq 1b
IF res eq 0b THEN BEGIN
  print, "The full path to the specified large input image: " 
  print, input
  print, "was not found. Verify the full pathname in: " 
  print, mod_params
  print, "Exiting..."
  GOTO, fin
ENDIF
res = query_tiff(input, inpinfo)
xdim0 = inpinfo.dimensions[0]
ydim0 = inpinfo.dimensions[1]
IF inpinfo.type NE 'TIFF' THEN BEGIN
  print, 'Invalid input (not a TIF image): ' + fbn
  print, "Exiting..."
  GOTO, fin
ENDIF
;; check for single image in file
IF inpinfo.num_images GT 1 THEN BEGIN
  print, 'Invalid input (more than 1 image in the TIF image): ' + fbn
  print, "Exiting..."
  GOTO, fin
ENDIF
;; check output of gdalinfo to ensure the image is of type byte and there is only 1 band in the tif
spawn, gdi + input + ' |grep Type=Byte |wc -l', log & log = log[0]
IF log NE '1' THEN BEGIN
  print, 'Invalid input (not of type Byte): ' + fbn
  print, "Exiting..."
  GOTO, fin
ENDIF
spawn, gdi + input + ' |grep "Band 2" |wc -l', log & log = log[0]
IF log NE '0' THEN BEGIN
  print, 'Invalid input (more than 1 band): ' + fbn
  print, "Exiting..."
  GOTO, fin
ENDIF
IF xdim0 LT 12000 THEN BEGIN
  print, 'Invalid input (X-dimension must have at least 12,000 pixels): ' + fbn
  print, "Exiting..."
  GOTO, fin
ENDIF
IF ydim0 LT 12000 THEN BEGIN
  print, 'Invalid input (Y-dimension must have at least 12,000 pixels): ' + fbn
  print, "Exiting..."
  GOTO, fin
ENDIF


;; 3) nr_stripes
a = strtrim(finp(q[2]), 2)
nr_stripes = uint(a) & cc = strtrim(nr_stripes,2)
IF cc NE a THEN BEGIN
  print, 'Number of stripes has a wonky value of: ' + a
  print, "Exiting..."
  GOTO, fin
ENDIF 
IF (nr_stripes LT 2) OR (nr_stripes GT 100) THEN BEGIN
  print, 'Number of stripes must be at least 2 and no more than 100'
  print, "Exiting..."
  GOTO, fin
ENDIF


;; 4) buffer width
a = strtrim(finp(q[3]), 2)
buffer = uint(a) & cc = strtrim(buffer,2)
IF cc NE a THEN BEGIN
  print, 'Buffer width has a wonky value of: ' + a
  print, "Exiting..."
  GOTO, fin
ENDIF
IF (buffer LT 5) OR (buffer GT 50000) THEN BEGIN
  print, 'Buffer width must be at least 5 pixels and no more than 50,000 pixels'
  print, "Exiting..."
  GOTO, fin
ENDIF


;; 5) orientation
orient = strlowcase(strtrim(finp(q[4]), 2))
true = (orient EQ 'horizontal') + (orient EQ 'vertical')
IF true EQ 0 THEN BEGIN
  print, "The file: " + mod_params + " is in a wrong format."
  print, "orientation option is not 'horizontal' or 'vertical'."
  print, "Please copy the respective backup file into your input directory:"
  print,  dir_inputdef + "/input/backup/*parameters.txt, or"
  print, "restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
ENDIF

;; 6) dryrun
dryrun = strtrim(finp(q[5]), 2)
true = (dryrun EQ '0') + (dryrun EQ '1')
IF true EQ 0 THEN BEGIN
  print, "The file: " + mod_params + " is in a wrong format."
  print, "dryrun option is not '0' or '1'."
  print, "Please copy the respective backup file into your input directory:"
  print,  dir_inputdef + "/input/backup/*parameters.txt, or"
  print, "restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
ENDIF

;;==============================================================================
;;==============================================================================
;; test splitlump settings 
;;==============================================================================
;;==============================================================================
;; large image dimension in X and Y, image size
inpsizeGB = float(xdim0) * float(ydim0) / 1024.0^3

IF orient EQ 'horizontal' THEN BEGIN
  stripe = 'hstripe'
  ystep = ydim0/nr_stripes 
  ybuff = indgen(nr_stripes,/l64)*ystep
  ylast = ydim0 - ybuff[nr_stripes-1] + buffer
  ;; size of largest buffered stripe
  IF nr_stripes EQ 2 THEN buffsizeGB = float(xdim0) * float(ybuff[1]+buffer) / 1024.0^3 ELSE $
    buffsizeGB = float(xdim0) * float(ybuff[1] + 2.0*buffer) / 1024.0^3
    
  q = ystep + buffer GT ydim0
  IF q EQ 1 THEN BEGIN
    print, "First stripe + buffer width would go beyond the map extent"
    print, "Reduce the buffer width or increase the number of stripes"
    print, "Exiting..."
    goto,fin
  ENDIF
  q = (ystep + 2*buffer GT ydim0) OR (buffsizeGB GE inpsizeGB)
  IF q EQ 1 THEN BEGIN
    print, "Buffered stripe is larger than the actual map"
    print, "Reduce the buffer width or decrease the number of stripes"
    print, "Exiting..."
    goto,fin
  ENDIF
    
ENDIF ELSE BEGIN
  stripe = 'vstripe'
  xstep = xdim0/nr_stripes 
  xbuff = indgen(nr_stripes,/l64)*xstep
  xlast = xdim0 - xbuff[nr_stripes-1] + buffer
  ;; size of largest buffered stripe
  IF nr_stripes EQ 2 THEN buffsizeGB = float(ydim0) * float(xbuff[1]+buffer) / 1024.0^3 ELSE $
    buffsizeGB = float(ydim0) * float(xbuff[1] + 2.0*buffer) / 1024.0^3
  
  q = xstep + buffer GT xdim0
  IF q EQ 1 THEN BEGIN
    print, "First stripe + buffer width would go beyond the map extent"
    print, "Reduce the buffer width or increase the number of stripes"
    print, "Exiting..."
    goto,fin
  ENDIF
  q = (xstep + 2*buffer GT xdim0) OR (buffsizeGB GE inpsizeGB)
  IF q EQ 1 THEN BEGIN
    print, "Buffered stripe is larger than the actual map"
    print, "Reduce the buffer width or decrease the number of stripes"
    print, "Exiting..."
    goto,fin
  ENDIF

ENDELSE

;;==============================================================================
;;==============================================================================
;; apply splitlump settings
;;==============================================================================
;;==============================================================================

;;==============================================================================
;; A) write the script: splitter.sh 
;;==============================================================================
close, 1 & openw, 1, dir_splitlump + '/splitter.sh'
printf, 1, '#!/bin/bash'
printf, 1, '# splitter.sh: cut buffered stripes of a large input image for GWB-processing'
printf, 1, '#############################################################'
printf, 1, '# Settings used:'
printf, 1, '# ' + fbn + ' : large image'
printf, 1, '# ' + dir_splitlump + ' : splitlump working directory'
printf, 1, '# ' + strtrim(nr_stripes,2) + ' : number of buffered stripes'
printf, 1, '# ' + strtrim(buffer,2) + ' : buffer width in pixels, to be added on both sides of the stripes'
printf, 1, '# ' + orient + ' : orientation of buffered stripes'
printf, 1, '#############################################################'
printf, 1, '# ' + strtrim(inpsizeGB, 2) + ' : uncompressed large image size [GB]'
printf, 1, '# ' + strtrim(buffsizeGB, 2)  + ' : uncompressed buffered stripe size [GB]' 
printf, 1, '#############################################################'
printf, 1, '# cut the ' + orient + ' buffered stripes according to the settings above:'
printf, 1, 'cd ' + dir_splitlump
IF orient EQ 'horizontal' THEN BEGIN
  printf, 1, 'f_inp='+input
  ;; first horizontal stripe
  printf,1, gtrans + '0 0 ' + strtrim(xdim0,2) + ' ' + strtrim(ybuff[1]+buffer,2) + ' $f_inp ' + stripe + '1.tif'
  ;; the image internal horizontal stripes
  for idx = 2, nr_stripes-1 do $
    printf,1, gtrans + '0 ' + strtrim(ybuff[idx-1]-buffer,2) + ' ' + strtrim(xdim0,2) + ' ' + strtrim(ystep+2*buffer,2) + ' $f_inp ' + stripe + strtrim(idx,2)+'.tif'
  ;; the last horizontal stripe
  printf,1, gtrans + '0 ' + strtrim(ybuff[nr_stripes-1]-buffer,2)+ ' ' + strtrim(xdim0,2) + ' ' + strtrim(ylast,2) + ' $f_inp ' + stripe + strtrim(nr_stripes,2)+'.tif'
ENDIF ELSE BEGIN
  printf, 1, 'f_inp='+input
  ;; first vertical stripe
  printf,1, gtrans + '0 0 ' + strtrim(xbuff[1]+buffer,2) + ' ' + strtrim(ydim0,2)  + ' $f_inp ' + stripe + '1.tif'
  ;; the image internal vertical stripes
  for idx = 2, nr_stripes-1 do $
    printf,1, gtrans + strtrim(xbuff[idx-1]-buffer,2)  + ' 0 '  + strtrim(xstep+2*buffer,2) + ' ' + strtrim(ydim0,2) + ' $f_inp ' + stripe + strtrim(idx,2)+'.tif'
  ;; the last vertical stripe
  printf,1, gtrans + strtrim(xbuff[nr_stripes-1]-buffer,2) + ' 0 ' + strtrim(xlast,2) + ' ' + strtrim(ydim0,2) + ' $f_inp ' + stripe + strtrim(nr_stripes,2)+'.tif'
ENDELSE

printf, 1, '#############################################################'
printf, 1, '# Next steps:'
printf, 1, '# Before you continue, first ensure that the file size of the buffered stripes is appropriate:'
printf, 1, '# - run the command "GWB" to find out GWB_XXX-specific peak RAM requirements.'
printf, 1, '#   Note that the GWB_XXX peak RAM factors are indicative only.'
printf, 1, '#   They may be lower depending on your settings, like less complex image or no statistics wanted.
printf, 1, '# - copy/paste the following command in a terminal to find out the amount of currently available system RAM:'
printf, 1, '#     echo $(awk "BEGIN {print $(free -m|awk ' + "'FNR == 2 {print $7}')/1024}" + '") GB system RAM currently available'
printf, 1, '# '
printf, 1, '# Only if the buffered file size of ' + strtrim(buffsizeGB, 2)  + ' [GB] is available for you, '
printf, 1, '# meaning: ' + strtrim(buffsizeGB, 2) + ' * GWB_XXX peak RAM factor < currently available system RAM, then'
printf, 1, '# 1) open a terminal in the directory: '  + dir_splitlump + '  and run the script "splitter.sh": ./splitter.sh'
printf, 1, '# 2) copy the respective GWB parameter file into the directory ' + dir_splitlump
printf, 1, '# 3) use GWB_XXX -i=' + dir_splitlump + ' -o =<your output directory>'
printf, 1, '#    to process all buffered stripes with the GWB module of your choice'
printf, 1, '# 4) move all resulting tif-images from the previous step into: ' + dir_splitlump
printf, 1, '# 5) run "./lumper.sh" to reassemble all processed tif-images into the final large processed image'
printf, 1, '#############################################################'
printf, 1, "echo The script \'./splitter.sh\' has finished."
printf, 1, 'exit'
close, 1
file_chmod, dir_splitlump + '/splitter.sh', /A_EXECUTE

;;==============================================================================
;; B) write the script: lumper.sh
;;==============================================================================
close, 1 & openw, 1, dir_splitlump + '/lumper.sh'
printf, 1, '#!/bin/bash'
printf, 1, '# lumper.sh: cut GWB-processed buffered stripes and merge into final result'
printf, 1, '#############################################################'
printf, 1, '# Settings used:'
printf, 1, '# ' + fbn + ' : large image'
printf, 1, '# ' + dir_splitlump + ' : splitlump working directory'
printf, 1, '# ' + strtrim(nr_stripes,2) + ' : number of buffered stripes'
printf, 1, '# ' + strtrim(buffer,2) + ' : buffer width in pixels on both sides of the stripes'
printf, 1, '# ' + orient + ' : orientation of buffered stripes'
printf, 1, '#############################################################'
printf, 1, '# ' + strtrim(inpsizeGB, 2) + ' : uncompressed large image size [GB]'
printf, 1, '# ' + strtrim(buffsizeGB, 2)  + ' : uncompressed buffered stripe size [GB]'
printf, 1, '#############################################################'
printf, 1, '# first test if the required files are here:' 
printf, 1, 'cd ' + dir_splitlump
cmd = 'ct=$(ls ' + stripe + '* 2>/dev/null|wc -l)'
printf, 1, cmd
printf, 1, 'if [ $ct != ' + strtrim(nr_stripes,2) + ' ];then 
printf, 1, '  echo incorrect number of ' + orient + ' stripes.'
printf, 1, "  echo Did you run \'./splitter.sh\' first?"
printf, 1, '  echo Exiting'
printf, 1, '  exit 1'
printf, 1, 'fi'
IF dryrun EQ '1' THEN BEGIN
  printf, 1, '# dryrun option enabled: rename output of splitter.sh to quickly test with lumper.sh'
  printf, 1, 'for f in ' + stripe + '*.tif; do mv "$f" "${f/%.tif/_dryrun.tif}"; done' 
ENDIF   
;; setup the final outputname = fbn + GWB module
printf, 1, 'resname=$(ls ' + stripe + '1_*.tif);resname=${resname#*_}'
p = strpos(fbn,'.',/reverse_search)
fn_out = strmid(fbn,0,p) + '_$resname'
printf, 1, '# cut and merge the buffered stripes according to the settings above:'
IF orient EQ 'horizontal' THEN BEGIN
  printf,1, gtrans + '0 0 ' + strtrim(xdim0,2) + ' ' + strtrim(ystep,2) + ' ' + stripe + '1_*.tif lumper1.tif'
  for idx = 2, nr_stripes-1 do $
    printf,1, gtrans + '0 ' + strtrim(buffer,2) + ' ' + strtrim(xdim0,2) + ' ' + strtrim(ystep,2) + ' ' + stripe + strtrim(idx,2)+'_*.tif ' + 'lumper' + strtrim(idx,2) +'.tif'
  printf,1, gtrans + '0 ' + strtrim(buffer,2) + ' ' + strtrim(xdim0,2) + ' ' + strtrim(ylast-buffer,2) + ' ' + stripe + strtrim(nr_stripes,2)+'_*.tif ' + 'lumper' + strtrim(nr_stripes,2) +'.tif'  
ENDIF ELSE BEGIN ;; vertical stripes
  printf,1, gtrans + '0 0 ' + strtrim(xstep,2) + ' ' + strtrim(ydim0,2) + ' ' + stripe + '1_*.tif lumper1.tif'
  for idx = 2, nr_stripes-1 do $
    printf,1, gtrans + strtrim(buffer,2) + ' 0 ' + strtrim(xstep,2) + ' ' + strtrim(ydim0,2) + ' ' + stripe + strtrim(idx,2)+'_*.tif ' + 'lumper' + strtrim(idx,2) +'.tif'
  printf,1, gtrans + strtrim(buffer,2) + ' 0 ' + strtrim(xlast-buffer,2) + ' ' + strtrim(ydim0,2) + ' ' + stripe + strtrim(nr_stripes,2)+'_*.tif ' + 'lumper' + strtrim(nr_stripes,2) +'.tif'  
ENDELSE
printf, 1, gbuildvrt + 'tmp.vrt lumper*.tif'
printf, 1, 'gdal_translate -co BIGTIFF=YES -co COMPRESS=LZW tmp.vrt ' + fn_out
printf, 1, gedit + '-mo TIFFTAG_SOFTWARE='+'"'+"GWB, https://forest.jrc.ec.europa.eu/en/activities/lpa/gwb/" +'" ' + fn_out
printf, 1, '#############################################################'
printf, 1, 'echo The script "lumper.sh" has finished, please verify your output file:'
printf, 1, 'echo ' + dir_splitlump + '/' + fn_out
printf, 1, 'exit'
close, 1
file_chmod, dir_splitlump + '/lumper.sh', /A_EXECUTE

;; Tell the user what to do next
print, ' '
print, 'Next, please follow the instructions at the end of: ' + dir_splitlump + '/splitter.sh'

fin:
END
