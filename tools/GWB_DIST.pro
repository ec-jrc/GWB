PRO GWB_DIST
;;==============================================================================
;;    GWB APP for Euclidean Distance Analysis (DIST)
;;==============================================================================
;; 
;; Purpose: 
;;==============================================================================
;; IDL cmd-line app to conduct EuclDist + HMC as implemented in GuidosToolbox (GTB)
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
;;
;;       Phone : +39 0332 78-5002
;;       E-mail: Peter.Vogt@ec.europa.eu

;;==============================================================================
GWB_mv = 'GWB_DIST (version 1.8.7)'
;;
;; Module changelog:
;; 1.8.7: IDL 8.8.2
;; 1.8.6: added mod_params check
;; 1.6  : nocheck, added output directory extension
;; 1.3  : added option for user-selectable input/output directories
;; 1.2  : initial internal release
;;
;;==============================================================================
;; Input: at least 1 file(s) in the subfolder "input"
;;==============================================================================
;; a) input image(s) (geotiff):
;; at least 1 or more geotiff images in the subfolder "input"
;; the input image must be MSPA-compliant having the assignment:
;; 0 byte: missing or no-data (optional)
;; 1 byte: background pixels (mandatory)
;; 2 byte: foreground pixels (mandatory)
;;
;;==============================================================================
;; Output: in the subfolder "output"
;;==============================================================================
;; a) Summary statistics 
;; b) geotiff images showing Euclidean Distance, HMC
;;
;; Processing steps:
;; 1) verify compatibility of input image
;; 2) process for DIST
;; 3) post-process (write out and dostats)
;;
;;==============================================================================
;;==============================================================================
device, decomposed = 0
;; initial system checks
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
print,'GWB_DIST using:'
if standalone eq 0 then print, 'dir_input= ', dir_input else print, dir_inputdef + "/input"
if standalone eq 0 then print, 'dir_output= ', dir_output else print, dir_inputdef + "/output"

;; restore colortable
IF (file_info('idl/distcolors.sav')).exists EQ 0b THEN BEGIN
  print, "The file 'tools/idl/distcolors.sav' was not found."
  print, "Exiting..."
  goto,fin
ENDIF
restore, 'idl/distcolors.sav' & tvlct, r, g, b

;; verify to have tif image(s) (should be a geotiff)
pushd, dir_input & list = file_search('*.tif', count=ct_tifs) & popd
IF ct_tifs EQ 0 THEN BEGIN
  print, "The input directory does not contain an image with the extension '.tif'"
  print, 'Please copy your geotiff image here.'
  print, "Exiting..."
  goto,fin
ENDIF
mod_params = dir_input + '/dist-parameters.txt'
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
;; read dist settings: 
tt = strarr(19) & close,1
IF file_lines(mod_params) LT n_elements(tt) THEN BEGIN
  print, "The file: " + mod_params + " is in a wrong format."
  print, "Please copy the respective backup file into your input directory:"
  print, dir_inputdef + "/input/backup/*parameters.txt"
  print, "Exiting..."
  goto,fin
ENDIF
;; check for correct input section lines
openr, 1, mod_params & readf,1,tt & close,1
if strmid(tt[15],0,6) ne '******' OR strmid(tt[18],0,6) ne '******' then begin
  print, "The file: " + mod_params + " is in a wrong format."
  print, "Please copy the respective backup file into your input directory:"
  print, dir_inputdef + "/input/backup/*parameters.txt"
  print, "Exiting..."
  goto,fin
endif

c_FGconn = strtrim(tt[16],2)
if c_FGconn eq '8' then begin
  conn_str = '8-conn FG'
endif else if c_FGconn eq '4' then begin
  conn_str = '4-conn FG'
endif else begin
  print, "Foreground connectivity is not 8 or 4."
  print, "Exiting..."
  goto,fin
endelse

addhmc = strtrim(tt[17],2)
true = (addhmc eq '1') + (addhmc eq '2')
IF true EQ 0 THEN BEGIN
  print, "EuclDist-HMC switch must be 1 or 2."
  print, "Exiting..."
  goto,fin
ENDIF

;;==============================================================================
;; run DIST in a loop over all tif images 
;;==============================================================================
;;==============================================================================
fn_logfile = dir_output + '/dist.log'
nr_im_files = ct_tifs & time00 = systime( / sec) & okfile = 0l
nocheck = file_info(dir_input + '/nocheck.txt') & nocheck = nocheck.exists

openw, 9, fn_logfile
if nocheck eq 0 then printf,9,GWB_mv else printf,9, GWB_mv + ' - nocheck'
printf, 9, 'DIST batch processing logfile: ', systime()
printf, 9, 'Number of files to be processed: ', nr_im_files
printf, 9, '==============================================='
close, 9


FOR fidx = 0, nr_im_files - 1 DO BEGIN
  counter = strtrim(fidx + 1, 2) + '/' + strtrim(nr_im_files, 2)
  
  input = dir_input + '/' +list[fidx] & res = strpos(input,' ') ge 0
  IF res EQ 1 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, ' '
    printf, 9, '==============   ' + counter + '   =============='
    printf, 9, 'Skipping invalid input (empty space in directory path or input filename): ', input
    close, 9
    GOTO, skip_dist  ;; invalid input
  ENDIF
  
  type = '' & res = query_image(input, type=type)
  IF type NE 'TIFF' THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, ' '
    printf, 9, '==============   ' + counter + '   =============='
    printf, 9, 'Skipping invalid input (not a TIF image): ', input
    close, 9
    GOTO, skip_dist  ;; invalid input
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
    GOTO, skip_dist  ;; invalid input
  ENDIF

  ;; read it
  geotiff = 0
  im = read_tiff(input, geotiff=geotiff) & is_geotiff = (size(geotiff))[0]
  image0 = rotate(temporary(im),7)
  IF nocheck EQ 1b THEN goto, good2go


  ;; check for single channel image
  ;;===========================
  IF size(image0, / n_dim) NE 2 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, ' '
    printf, 9, '==============   ' + counter + '   =============='
    printf, 9, 'Skipping invalid input (more than 1 band in the TIF image): ', input
    close, 9
    GOTO, skip_dist  ;; invalid input
  ENDIF

  ;; check for byte array
  ;;===========================
  IF size(image0, / type) NE 1 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, ' '
    printf, 9, '==============   ' + counter + '   =============='
    printf, 9, 'Skipping invalid input (image is not of type BYTE): ', input
    close, 9
    GOTO, skip_dist  ;; invalid input
  ENDIF

  ;; check min/max value in image
  ;;===========================
  mxx = max(image0, min = mii)
  IF mxx GT 2b THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, ' '
    printf, 9, '==============   ' + counter + '   =============='
    printf, 9, 'Skipping invalid input (Image maximum is larger than 2 BYTE): ', input
    close, 9
    GOTO, skip_dist  ;; invalid input
  ENDIF ELSE IF mxx LT 2b THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, ' '
    printf, 9, '==============   ' + counter + '   =============='
    printf, 9, 'Skipping invalid input (Image has no foreground (2 BYTE)): ', input
    close, 9
    GOTO, skip_dist  ;; invalid input
  ENDIF
  IF mii GT 1b THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, ' '
    printf, 9, '==============   ' + counter + '   =============='
    printf, 9, 'Skipping invalid input (Image has no background (1 BYTE)): ', input
    close, 9
    GOTO, skip_dist  ;; invalid input
  ENDIF

  good2go:
  ;;==============================================================================
  ;; 2) process for Euclidean Distance
  ;;==============================================================================
  time0 = systime( / sec)
  
  ;; first extend the image to avoid border effects
  q = size(image0,/dim) & sim_x = q[0] & sim_y = q[1]
  sext_x = sim_x + 2 & sext_y = sim_y + 2
  ext = bytarr(sext_x, sext_y)
  ext[1:sim_x, 1:sim_y] = image0
  ext[0, 1:sim_y] = image0[0,*] ;left
  ext[1+sim_x:*, 1:sim_y] = image0[sim_x-1:*,*] ;right
  ext[1:sim_x, 0] = image0[*, 0] ;top
  ext[1:sim_x, 1+sim_y:*] = image0[*, sim_y-1:*] ;bottom

  ;; count FG, BG objects
  conn8 = 1 
  fgo = label_region(ext eq 2b,all_neighbors=conn8, /ulong) & fgo = max(fgo) ;; 8-conn FG
  bgo = label_region(ext eq 1b,all_neighbors=1-conn8, /ulong) & bgo = max(bgo)  ;; 4-conn BG 
  fg_pix = total(image0 eq 2b) & bg_pix = total(image0 eq 1b) & data = fg_pix + bg_pix
  pfg=fg_pix/data & pbg=bg_pix/data

  fo = morph_distance(ext EQ 1b, /background, neighbor = 3) & fo = fo[1:sim_x, 1:sim_y]
  distreal = temporary(fo) * (image0 eq 2b)
  ;; calculate the average distance to boundary for foreground
  q = where(distreal gt 0.0, /l64) & adf = mean(distreal(q)) & q = 0 & adfmax = max(distreal)
  ;; limit the distance to 120 x the pixel size, convert from
  ;; float to byte, and add the offset of 130b
  fo = byte(round(distreal) < 120) + 130b  ;;??
  ;; keep only the values above the threshold
  fo = fo * (fo gt 130b)  

  bo =  morph_distance(ext EQ 2b, / background, neighbor = 3) & bo = bo[1:sim_x, 1:sim_y]
  image0 = temporary(bo) * (temporary(image0) eq 1b)  & adbmax = - max(image0)
  morphdist = temporary(distreal) - image0
  ;; calculate the average distance to boundary for background
  q = where(image0 gt 0.0, /l64) & adb = mean(image0(q)) & q = 0
  image0 = 130b - byte(round(temporary(image0)) < 120)
  image0 = image0 * (image0 lt 130b)
  ;; combine the foreground and backg distance maps = the viewport image
  im = temporary(image0) + temporary(fo)
  
  ;; write the final result
  fbn = file_basename(list[fidx], '.tif')
  outdir = dir_output + '/' + fbn + '_dist' & file_mkdir, outdir
  fn_out = outdir + '/' + fbn + '_dist_viewport.tif'
  desc = 'GTB_EUCL, https://forest.jrc.ec.europa.eu/en/activities/lpa/gtb/'
  ;; add the geotiff info if available
  IF is_geotiff GT 0 THEN $
    write_tiff, fn_out, rotate(im,7), red = r, green = g, blue = b, geotiff = geotiff, description = desc, compression = 1 ELSE $
    write_tiff, fn_out, rotate(im,7), red = r, green = g, blue = b, description = desc, compression = 1
  im = 0 
  fn_out = outdir + '/' + fbn + '_dist.tif'
  desc = 'GTB, https://forest.jrc.ec.europa.eu/en/activities/lpa/gtb/'
  ;; add the geotiff info if available
  IF is_geotiff GT 0 THEN $
    write_tiff, fn_out, rotate(morphdist,7), geotiff = geotiff, description = desc, compression = 1, /float ELSE $
    write_tiff, fn_out, rotate(morphdist,7), description = desc, compression = 1, /float

  ;; add barplot of distance distribution
  image0 = round(temporary(morphdist))

  ; build distance histogram
  fghist = histogram((image0 gt 0)* image0) & fgmax=max(image0)
  bghist = histogram(-(image0 lt 0)* image0) & bgmax=-min(image0)
  bins = indgen(bgmax+fgmax+1)-bgmax & image0 = 0
  
  dhist = fltarr(n_elements(bins))
  dhist[0:bgmax-1] = -reverse(bghist[1:*]) & dhist[bgmax+1:*]=fghist[1:*]
  ;; print out Eucldist stats to a file 
  fn_out = outdir + '/' + fbn + '_dist.txt'
  openw,1,fn_out 
  printf, 1, 'Euclidean distance result using file: ', fbn
  printf, 1, 'Background: average distance, number of objects, maximum distance: '
  printf, 1, strtrim(-adb, 2), '  -', strtrim(bgo, 2), '  ', strtrim(adbmax, 2)
  printf, 1, 'Foreground: average distance, number of objects, maximum distance: '
  printf, 1, ' ', strtrim(adf, 2), '   ', strtrim(fgo, 2), '   ', strtrim(adfmax, 2)
  printf, 1, 'Distance histogram (rounded to nearest integer, negative values for background)
  printf, 1, '       bin ID     frequency'
  for idx=0l, n_elements(bins)-1 do printf,1, bins(idx),long64(dhist(idx))
  close, 1
  
  ;; print out Eucldist barplot to a file
  z = dhist & z[0:bgmax-1]=0
  ;; define xrange to be at least -40 to +40 and plot the thing
  x1 = 40 > bgmax*1.05 > fgmax/2 & x2 = 40 > fgmax*1.05 > bgmax/2
  xtit = 'Background          distance [pixels]          Foreground'
  bptit = 'Distance histogram (' + fbn + ')'
  px = -40 < (-bgmax)
  ;; highlight the average distance bin
  z2 = z*0 & bb = bgmax-round(adb) & z2[bb]=dhist[bb]
  if adf gt 1.0 then bb = bgmax+round(adf) else bb = bgmax & z2[bb]=dhist[bb]

  a = barplot(bins, dhist, fill_color='blue', xtitle=xtit, $
    ytitle = 'Frequency', title = bptit, xrange = [-x1,x2], histogram=1,/buffer)
  a = barplot(bins,z,fill_color='green',/overplot,histogram=1)
  a = text(2,-bghist[1]*0.2,'adf = ' + strtrim(adf, 2),/data,/current,color='green')
  a = text(2,-bghist[1]*0.2,'adf',/data,/current,color='gold')
  a = text(2,-bghist[1]*0.3,'fgo = ' + strtrim(fgo, 2),/data,/current,color='green')
  a = text(2,-bghist[1]*0.4,'d_max = ' + strtrim(adfmax, 2),/data,/current,color='green')
  a = text(px*0.8,fghist[1]*0.4,'adb = ' + strtrim(-adb, 2),/data,/current,color='blue')
  a = text(px*0.8,fghist[1]*0.4,'adb',/data,/current,color='gold')
  a = text(px*0.8,fghist[1]*0.3,'bgo = -' + strtrim(bgo, 2),/data,/current,color='blue')
  a = text(px*0.8,fghist[1]*0.2,'d_max = ' + strtrim(adbmax, 2),/data,/current,color='blue')
  ;; highlight the average distance bin
  a = barplot(bins,z2,fill_color='gold',/overplot,histogram=1)
  fn_out = outdir + '/' + fbn + '_dist_hist.png'
  a.save,fn_out, resolution=300
  a.close 
  
  if addhmc eq 1 then goto, skip_hmc
  ;;==============================================================================
  ;; add HMC analysis if requested
  ;;==============================================================================  
  x1 = 40 > bgmax*1.05 > fgmax/2 & x2 = 40 > fgmax*1.05 > bgmax/2
  xtit = 'Background          distance [pixels]          Foreground'

  ;; calculate hypsometric curve
  fghmc=total(fghist[1:*],/cum) & bghmc=total(bghist[1:*],/cum)
  fghmcx=fghmc/max(fghmc) & bghmcx=bghmc/max(bghmc)
  hmc = fltarr(n_elements(bins))
  hmc[0:bgmax-1] = -reverse(bghmcx) & hmc[bgmax+1:*]=fghmcx

  bartit = fbn
  bptit = 'Hypsometric curve (' + bartit + ')'
  a = barplot(bins,hmc,fill_color='blue',xtitle = xtit, /buffer,$
    ytitle='Normalized cumulative frequency',title=bptit,yrange=[-1.1,1.1],xrange=[-x1,x2],histogram=1)
  z = hmc & z[0:bgmax-1]=0
  a = barplot(bins,z,fill_color='green',/overplot,histogram=1)

  ;; highlight the average distance bin
  z = z*0 & bb = bgmax-round(adb) & z[bb]=hmc[bb]
  if adf gt 1.0 then bb = bgmax+round(adf) else bb = bgmax
  ; ensure it is not larger than the last entry of z which may happen in singular cases and rounding issues
  xx = n_elements(z)-1 & bb = bb < xx & z[bb]=hmc[bb]
  a = barplot(bins,z,fill_color='gold',/overplot,histogram=1)

  hi_fg = 0 & hi_bg = 0 & ha_fg = 0 & ha_bg = 0
  if adf gt 0 then begin
    hi_fg = adf/adfmax
    ha_fg = total(fghmcx)
    fg_arep = (!PI * (adf^2)) ; typical area
  endif
  if adb gt 0 then begin
    hi_bg = adb/adbmax
    ha_bg = -total(bghmcx)
    bg_arep = -(!PI * (adb^2)) ; typical area
  endif

  ;;Foreground
  hi_fg_str = 'HI = ' + strtrim(hi_fg,2)
  ha_fg_str = 'HA = ' + strtrim(ha_fg,2)
  a = text(5,-0.2,hi_fg_str,/data,/current,color='green')
  a = text(5,-0.3,ha_fg_str,/data,/current,color='green')
  a = text(5,-0.5,'adf = ' + strtrim(adf, 2),/data,/current,color='green')
  a = text(5,-0.5,'adf',/data,/current,color='gold')
  a = text(5,-0.6,'fg_dmax = ' + strtrim(adfmax, 2),/data,/current,color='green')
  a = text(5,-0.7,'fg_obj = ' + strtrim(fgo, 2),/data,/current,color='green')
  a = text(5,-0.8,'fg_area = ' + strtrim(pfg*100, 2)+'%',/data,/current,color='green')
  a = text(5,-0.9,'fg_Arep = ' + strtrim(fg_arep, 2),/data,/current,color='red')

  ;; Background
  hi_bg_str = 'HI = ' + strtrim(hi_bg,2)
  ha_bg_str = 'HA = ' + strtrim(ha_bg,2)
  a = text(-x1*0.9,0.9,hi_bg_str,/data,/current,color='blue')
  a = text(-x1*0.9,0.8,ha_bg_str,/data,/current,color='blue')
  a = text(-x1*0.9,0.6,'adb = ' + strtrim(-adb, 2),/data,/current,color='blue')
  a = text(-x1*0.9,0.6,'adb',/data,/current,color='gold')
  a = text(-x1*0.9,0.5,'bg_dmax = ' + strtrim(adbmax, 2),/data,/current,color='blue')
  a = text(-x1*0.9,0.4,'bg_obj = -' + strtrim(bgo, 2),/data,/current,color='blue')
  a = text(-x1*0.9,0.3,'bg_area = -' + strtrim(pbg*100, 2)+'%',/data,/current,color='blue')
  a = text(-x1*0.9,0.2,'bg_Arep = ' + strtrim(bg_arep, 2),/data,/current,color='red')

  fn_out = outdir + '/' + fbn + '_dist_hmc.png'
  a.save,fn_out, resolution=300
  a.close
  ;;===================================================================

  ;; print out HMC stats to a txt-file
  fn_out = outdir + '/' + fbn + '_dist_hmc.txt'
  openw,1,fn_out
  printf, 1, 'HI, HA, adb, bg_dmax, bg_obj, bg_area, bg_Arep (background indices)'
  printf, 1, 'HI, HA, adf, fg_dmax, fg_obj, fg_area, fg_Arep (foreground indices)'
  printf, 1, ' '
  printf, 1, 'File: ' + input 
  printf, 1, strtrim(abs(hi_bg),2),'  ',strtrim(abs(ha_bg),2), '  ',strtrim(adb,2),'  ', strtrim(abs(adbmax),2),$
    '  ', strtrim(bgo,2), '  ', strtrim(pbg*100, 2), '  ', strtrim(abs(bg_arep),2)
  printf, 1, strtrim(hi_fg,2), '  ', strtrim(ha_fg,2), '  ', strtrim(adf,2), '  ', strtrim(adfmax,2),'  ',$
    strtrim(fgo,2), '  ', strtrim(pfg*100, 2), '  ', strtrim(fg_arep,2)
  close, 1
  
  ;; print out HMC stats to a csv-file
  fn_out = outdir + '/' + fbn + '_dist_hmc.csv'
  openw,1,fn_out
  printf, 1, 'HI_bg, HA_bg, adb, bg_dmax, bg_obj, bg_area, bg_Arep, ,HI_fg, HA_fg, adf, fg_dmax, fg_obj, fg_area, fg_Arep'
  printf, 1, strtrim(abs(hi_bg),2) + ',' + strtrim(abs(ha_bg),2) + ',' + strtrim(adb,2) + ',' + strtrim(abs(adbmax),2) + ',' + $
    strtrim(bgo,2) + ',' + strtrim(pbg*100, 2) + ',' + strtrim(abs(bg_arep),2) + ', ,' + strtrim(hi_fg,2) + ',' + strtrim(ha_fg,2) + $
    ',' + strtrim(adf,2) + ',' + strtrim(adfmax,2) + ',' + strtrim(fgo,2) + ',' + strtrim(pfg*100, 2) + ',' + strtrim(fg_arep,2)
  close, 1

  
  skip_hmc:
  ;; update the log-file
  okfile = okfile + 1
  openw, 9, fn_logfile, /append
  printf, 9, ' '
  printf, 9, '==============   ' + counter + '   =============='
  printf, 9, 'File: ' + input
  printf, 9, 'DIST comp.time [sec]: ', systime( / sec) - time0
  close, 9

  skip_dist:
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
printf, 9, 'DIST Batch Processing total comp.time: ', proctstr
printf, 9, 'Successfully processed files: ',strtrim(okfile,2)+'/'+ strtrim(nr_im_files,2)
printf, 9, '==============================================='
close, 9

print, 'DIST finished sucessfully'

fin:
END
