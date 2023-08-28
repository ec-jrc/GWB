;;==============================================================================
PRO simplestats, image0, fconn, ttrans, tintext, cg, st
  ;; Purpose: calculate simple statistics of a given fullres image
  ;; INPUT:
  ;; - image0: the fullres MSPA-image
  ;; - fconn: foreground connectivity
  ;; - ttrans: transition value
  ;; - tintext: Intext value
  ;; - cg: distinguish core groups
  ;;
  ;; OUTPUT
  ;; - st: strarr percentages wrt fg/data and count/BGarea
  ;;
  ;;==============================================================
  ;; 7-class: possible values are
  ;;==============================================================
  ;;      CLASS              COLOR           RGB         int   ext
  ;; 1a) Core (small)        green       000/130/000     116   16
  ;; 1b) Core (medium/normal green       000/200/000     117   17
  ;; 1c) Core (large)        green       000/255/000     118   18
  ;; 2)  Islet               brown       160/060/000     109   9
  ;; 3)  Perforation         blue        000/000/255     105   5
  ;; 4)  Edge                black       000/000/000     103   3
  ;; 5a) Loop                yellow      255/255/000     165   65
  ;; 5b)  in Edge            yellow      255/255/000     167   67
  ;; 5c)  in Perforation     yellow      255/255/000     169   69
  ;; 6a) Bridge              red         255/000/000     133   33
  ;; 6b)  in Edge            red         255/000/000     135   35
  ;; 6c)  in Perforation     red         255/000/000     137   37
  ;; 7)  Branch              orange      255/140/000     101   1
  ;;
  ;; Background              gray        220/220/220     100   0
  ;; Opening                 gray        220/220/220     0   (if intext=0)
  ;; CoreOpening           darkgrey      136/136/136     100 (if intext=1)
  ;; BorderOpening           gray        194/194/194     220 (if intext=1)
  ;;
  ;; Missing                 white       255/255/255     129   129
  ;;
  ;;
  ;; 1) the above color table is valid for transition = 1. If
  ;;    transition = 0 then 5b an 6b will be displayed in black
  ;;    and 5c and 6c will be displayed in blue.
  ;;    TRANSITION only changes the display
  ;;    color BUT NOT the image byte values!
  ;; 2) If INTERNAL = 1 then you will get a dual layer of
  ;;    class values where an offset of 100b is assigned to internal
  ;;    foreground pixels. Internal means that there is no access to
  ;;    any image borderline, or an object of connected background
  ;;    pixels completely enclosed by foreground pixels. If internal
  ;;    is on you can get byte values from both columns above beside
  ;;    for Perforation which by definition is an internal feature,
  ;;    so you can only have 105b and not 5b if internal = 1

  sz = size(image0) & tt2 = bytarr(sz(1) + 6, sz(2) + 6)
  ;; initialize to set all frequencies to 0
  freq_missing = 0 & freq_backg = 0 & freq_core = 0 & freq_islet = 0
  freq_perforated = 0 & freq_edge = 0 & freq_loop = 0 & freq_bridge = 0
  freq_branch = 0 & freq_core_small = 0 & freq_core_large = 0 & freq_opening = 0
  freq_coreopen = 0 & freq_borderopen = 0

  opening = 0 & core_opening = 0 & border_opening = 0 ;; areas of openings
  fconn2 = 1-fconn ;; complement to the current FG-conncetivity rule

  ;; calculate the class percentages by data area (d_area) and
  ;; by foreground area (f_<class>)

  ;; data area
  p = where(image0 NE 129b, d_area, /l64)
  allmissing = sz[4] - d_area
  tt = image0 * 0b + 1b & tt(p) = 0b
  tt2(3:sz(1)+2, 3:sz(2)+2) = temporary(tt)
  freq_missing = max(label_region(tt2, / ulong, all_neighbors = 1))

  ;; background area; use fconn2 neighborhood rule
  p = where(image0 EQ 0b OR image0 EQ 100b OR image0 EQ 220b, allbackg, /l64)
  tt = image0 * 0b & tt(p) = 1b
  tt2 = tt2*0b & tt2(3:sz(1)+2, 3:sz(2)+2) = temporary(tt)
  freq_backg = max(label_region(tt2, / ulong, all_neighbors = fconn2))

  ;; foreground area
  foreg = d_area - allbackg ;; foreground pixels
  ;; conversion factor backg2foreg
  byforeg = float(d_area) / foreg

  ;; openings
  ;;==================================================
  ;; do stats for core and border openings
  d_core_opening = '--' & d_border_opening = '--'
  freq_core_opening = 0 & freq_border_opening = 0
  if tintext eq 1 then begin
    ;; border opening
    p = where(image0 EQ 220b, d_border_opening, /l64)
    IF d_border_opening NE 0 THEN BEGIN
      tt = image0 * 0b & tt(p) = 1b
      tt2 = tt2*0b & tt2(3:sz(1)+2, 3:sz(2)+2) = temporary(tt)
      freq_border_opening = max(label_region(tt2, / ulong, all_neighbors = fconn2)) ;;fconn2 because BG
    ENDIF
    d_border_opening = 100.0 / d_area * d_border_opening ;; % of data area
    d_border_opening = strtrim((round(d_border_opening * 100.0) / 100.0), 1)
    pos = strpos(d_border_opening, '.') & d_border_opening = strmid(d_border_opening, 0, pos + 3)
    IF strlen(d_border_opening) EQ 4 THEN d_border_opening = ' ' + d_border_opening

    ;; core opening
    p = where(image0 EQ 100b, d_core_opening, /l64)
    IF d_core_opening NE 0 THEN BEGIN
      tt = image0 * 0b & tt(p) = 1b
      tt2 = tt2*0b & tt2(3:sz(1)+2, 3:sz(2)+2) = temporary(tt)
      freq_core_opening = max(label_region(tt2, / ulong, all_neighbors = fconn2)) ;;fconn2 because BG
    ENDIF
    d_core_opening = 100.0 / d_area * d_core_opening ;; % of data area
    d_core_opening = strtrim((round(d_core_opening * 100.0) / 100.0), 1)
    pos = strpos(d_core_opening, '.') & d_core_opening = strmid(d_core_opening, 0, pos + 3)
    IF strlen(d_core_opening) EQ 4 THEN d_core_opening = ' ' + d_core_opening

  endif

  ;; count of all openings
  freq_opening = freq_core_opening + freq_border_opening

  ;; area of all openings
  border_opening = ulong64(total(image0 EQ 220b))
  core_opening = ulong64(total(image0 EQ 100b))
  opening = border_opening + core_opening
  ;; FG-integrity: 100 if no openings else less)
  d_opening = 100.0 - (100.0 / (foreg + opening) * opening)


  ;; 1. core - green : data/foreground/frequency
  p = where(image0 EQ 17b OR image0 EQ 117b, d_core, /l64) & core_pix = d_core
  IF d_core NE 0 THEN BEGIN
    tt = image0 * 0b & tt(p) = 1b
    tt2 = tt2*0b & tt2(3:sz(1)+2, 3:sz(2)+2) = temporary(tt)
    freq_core = max(label_region(tt2, / ulong, all_neighbors = fconn))
  ENDIF
  d_core = 100.0 / d_area * d_core
  f_core = d_core * byforeg

  if cg eq 1 then begin
    ;;===============================================
    ;; additional stats for small and large cores
    p = where(image0 EQ 16b OR image0 EQ 116b, d_core_small, /l64) & core_pix = core_pix + d_core_small
    IF d_core_small NE 0 THEN BEGIN
      tt = image0 * 0b & tt(p) = 1b
      tt2 = tt2*0b & tt2(3:sz(1)+2, 3:sz(2)+2) = temporary(tt)
      freq_core_small = max(label_region(tt2, / ulong, all_neighbors = fconn))
    ENDIF
    d_core_small = 100.0 / d_area * d_core_small
    f_core_small = d_core_small * byforeg

    p = where(image0 EQ 18b OR image0 EQ 118b, d_core_large, /l64) & core_pix = core_pix + d_core_large
    IF d_core_large NE 0 THEN BEGIN
      tt = image0 * 0b & tt(p) = 1b
      tt2 = tt2*0b & tt2(3:sz(1)+2, 3:sz(2)+2) = temporary(tt)
      freq_core_large = max(label_region(tt2, / ulong, all_neighbors = fconn))
    ENDIF
    d_core_large = 100.0 / d_area * d_core_large
    f_core_large = d_core_large * byforeg

  endif


  ;; 2. islet - brown
  p = where(image0 EQ 9b OR image0 EQ 109b, d_islet, /l64)
  IF d_islet NE 0 THEN BEGIN
    tt = image0 * 0b & tt(p) = 1b
    tt2 = tt2*0b & tt2(3:sz(1)+2, 3:sz(2)+2) = temporary(tt)
    freq_islet = max(label_region(tt2, / ulong, all_neighbors = fconn))
  ENDIF
  d_islet = 100.0 / d_area * d_islet
  f_islet = d_islet * byforeg


  ;; 3. perforation - blue
  p = where(image0 EQ 5b OR image0 EQ 105b, d_perforated, /l64)
  p1 = where(image0 EQ 69b OR image0 EQ 169b, d_p1, /l64)
  p2 = where(image0 EQ 37b OR image0 EQ 137b, d_p2, /l64)
  d_perforated = d_perforated + d_p1 + d_p2 & perf_pix = d_perforated
  IF d_perforated NE 0 THEN BEGIN ;; we have perforations
    tt = image0 * 0b & tt(p) = 1b
    IF d_p1 GT 0 THEN tt(p1) = 1b
    IF d_p2 GT 0 THEN tt(p2) = 1b
    tt2 = tt2*0b & tt2(3:sz(1)+2, 3:sz(2)+2) = temporary(tt)
    freq_perforated = max(label_region(tt2, / ulong, all_neighbors = fconn))
  ENDIF
  d_perforated = 100.0 / d_area * d_perforated
  f_perforated = d_perforated * byforeg

  ;; 4. edge - black
  p = where(image0 EQ 3b OR image0 EQ 103b, d_edge, /l64)
  p1 = where(image0 EQ 67b OR image0 EQ 167b, d_e1, /l64)
  p2 = where(image0 EQ 35b OR image0 EQ 135b, d_e2, /l64)
  d_edge = d_edge + d_e1 + d_e2 & edge_pix = d_edge
  IF d_edge NE 0 THEN BEGIN
    tt = image0 * 0b & tt(p) = 1b
    IF d_e1 GT 0 THEN tt(p1) = 1b
    IF d_e2 GT 0 THEN tt(p2) = 1b
    tt2 = tt2*0b & tt2(3:sz(1)+2, 3:sz(2)+2) = temporary(tt)
    freq_edge = max(label_region(tt2, / ulong, all_neighbors = fconn))
  ENDIF
  d_edge = 100.0 / d_area * d_edge
  f_edge = d_edge * byforeg


  ;; 5. loop - yellow
  p1 =  where(image0 EQ 65b OR image0 EQ 165b, d_loop, /l64)
  d_loop = 100.0 / d_area * d_loop
  f_loop = d_loop * byforeg
  IF d_loop GT 0 THEN BEGIN
    tt = image0 * 0b
    tt(p1) = 1b
    tt2 = tt2*0b & tt2(3:sz(1)+2, 3:sz(2)+2) = temporary(tt)
    freq_loop = max(label_region(tt2, / ulong, all_neighbors = fconn))
  ENDIF


  ;; 6. bridge - red
  p1 =  where(image0 EQ 33b OR image0 EQ 133b, d_bridge, /l64)
  d_bridge = 100.0 / d_area * d_bridge
  f_bridge = d_bridge * byforeg
  IF d_bridge GT 0 THEN BEGIN
    tt = image0 * 0b
    tt(p1) = 1b
    tt2 = tt2*0b & tt2(3:sz(1)+2, 3:sz(2)+2) = temporary(tt)
    freq_bridge = max(label_region(tt2, / ulong, all_neighbors = fconn))
  ENDIF


  ;; 7. branch - orange
  p = where(image0 EQ 1b OR image0 EQ 101b, d_branch, /l64)
  IF d_branch NE 0 THEN BEGIN
    tt = image0 * 0b & tt(p) = 1b
    tt2 = tt2*0b & tt2(3:sz(1)+2, 3:sz(2)+2) = temporary(tt)
    freq_branch = max(label_region(tt2, / ulong, all_neighbors = fconn))
  ENDIF
  tt2 = 0
  d_branch = 100.0 / d_area * d_branch
  f_branch = d_branch * byforeg

  ;; background - grey
  d_bg = 100.0 / d_area * allbackg

  ;; missing - white
  missing = 100.0 / sz(4) * (sz(4) - d_area)

  ;; Porosity
  area_contiguous = core_pix + edge_pix + perf_pix
  area_internal = area_contiguous + core_opening
  porosity = 100.0 - (double(area_contiguous) / area_internal * 100.0)

  ;; convert the numbers into suitable strings for the GUI
  ;;=======================================================
  d_core = strtrim((round(d_core * 100.0) / 100.0), 1)
  pos = strpos(d_core, '.') & d_core = strmid(d_core, 0, pos + 3)
  IF strlen(d_core) EQ 4 THEN d_core = ' ' + d_core
  f_core = strtrim((round(f_core * 100.0) / 100.0), 1)
  pos = strpos(f_core, '.') & f_core = strmid(f_core, 0, pos + 3)
  IF strlen(f_core) EQ 4 THEN f_core = ' ' + f_core

  if cg eq 1 then begin
    d_core_small = strtrim((round(d_core_small * 100.0) / 100.0), 1)
    pos = strpos(d_core_small, '.') & d_core_small = strmid(d_core_small, 0, pos + 3)
    IF strlen(d_core_small) EQ 4 THEN d_core_small = ' ' + d_core_small
    f_core_small = strtrim((round(f_core_small * 100.0) / 100.0), 1)
    pos = strpos(f_core_small, '.') & f_core_small = strmid(f_core_small, 0, pos + 3)
    IF strlen(f_core_small) EQ 4 THEN f_core_small = ' ' + f_core_small

    d_core_large = strtrim((round(d_core_large * 100.0) / 100.0), 1)
    pos = strpos(d_core_large, '.') & d_core_large = strmid(d_core_large, 0, pos + 3)
    IF strlen(d_core_large) EQ 4 THEN d_core_large = ' ' + d_core_large
    f_core_large = strtrim((round(f_core_large * 100.0) / 100.0), 1)
    pos = strpos(f_core_large, '.') & f_core_large = strmid(f_core_large, 0, pos + 3)
    IF strlen(f_core_large) EQ 4 THEN f_core_large = ' ' + f_core_large
  endif

  d_islet = strtrim((round(d_islet * 100.0) / 100.0), 1)
  pos = strpos(d_islet, '.') & d_islet = strmid(d_islet, 0, pos + 3)
  IF strlen(d_islet) EQ 4 THEN d_islet = ' ' + d_islet
  f_islet = strtrim((round(f_islet * 100.0) / 100.0), 1)
  pos = strpos(f_islet, '.') & f_islet = strmid(f_islet, 0, pos + 3)
  IF strlen(f_islet) EQ 4 THEN f_islet = ' ' + f_islet

  d_perforated = strtrim((round(d_perforated * 100.0) / 100.0), 1)
  pos = strpos(d_perforated, '.')
  d_perforated = strmid(d_perforated, 0, pos + 3)
  IF strlen(d_perforated) EQ 4 THEN d_perforated = ' ' + d_perforated
  f_perforated = strtrim((round(f_perforated * 100.0) / 100.0), 1)
  pos = strpos(f_perforated, '.')
  f_perforated = strmid(f_perforated, 0, pos + 3)
  IF strlen(f_perforated) EQ 4 THEN f_perforated = ' ' + f_perforated

  d_edge = strtrim((round(d_edge * 100.0) / 100.0), 1)
  pos = strpos(d_edge, '.') & d_edge = strmid(d_edge, 0, pos + 3)
  IF strlen(d_edge) EQ 4 THEN d_edge = ' ' + d_edge
  f_edge = strtrim((round(f_edge * 100.0) / 100.0), 1)
  pos = strpos(f_edge, '.') & f_edge = strmid(f_edge, 0, pos + 3)
  IF strlen(f_edge) EQ 4 THEN f_edge = ' ' + f_edge

  d_loop = strtrim((round(d_loop * 100.0) / 100.0), 1)
  pos = strpos(d_loop, '.') & d_loop = strmid(d_loop, 0, pos + 3)
  IF strlen(d_loop) EQ 4 THEN d_loop = ' ' + d_loop
  f_loop = strtrim((round(f_loop * 100.0) / 100.0), 1)
  pos = strpos(f_loop, '.') & f_loop = strmid(f_loop, 0, pos + 3)
  IF strlen(f_loop) EQ 4 THEN f_loop = ' ' + f_loop

  d_bridge = strtrim((round(d_bridge * 100.0) / 100.0), 1)
  pos = strpos(d_bridge, '.') & d_bridge = strmid(d_bridge, 0, pos + 3)
  IF strlen(d_bridge) EQ 4 THEN d_bridge = ' ' + d_bridge
  f_bridge = strtrim((round(f_bridge * 100.0) / 100.0), 1)
  pos = strpos(f_bridge, '.') & f_bridge = strmid(f_bridge, 0, pos + 3)
  IF strlen(f_bridge) EQ 4 THEN f_bridge = ' ' + f_bridge

  d_branch = strtrim((round(d_branch * 100.0) / 100.0), 1)
  pos = strpos(d_branch, '.') & d_branch = strmid(d_branch, 0, pos + 3)
  IF strlen(d_branch) EQ 4 THEN d_branch = ' ' + d_branch
  f_branch = strtrim((round(f_branch * 100.0) / 100.0), 1)
  pos = strpos(f_branch, '.') & f_branch = strmid(f_branch, 0, pos + 3)
  IF strlen(f_branch) EQ 4 THEN f_branch = ' ' + f_branch

  d_bg = strtrim((round(d_bg * 100.0) / 100.0), 1)
  pos = strpos(d_bg, '.') & d_bg = strmid(d_bg, 0, pos + 3)
  IF strlen(d_bg) EQ 4 THEN d_bg = ' ' + d_bg

  missing = strtrim((round(missing * 100.0) / 100.0), 1)
  pos = strpos(missing, '.') & missing = strmid(missing, 0, pos + 3)
  IF strlen(missing) EQ 4 THEN missing = ' ' + missing

  porosity = strtrim((round(porosity * 100.0) / 100.0), 1)
  pos = strpos(porosity, '.') & porosity = strmid(porosity, 0, pos + 3)
  IF strlen(porosity) EQ 4 THEN porosity = ' ' + porosity

  st = strarr(2, 14)
  ;; first data column: % FG / % Data area
  ;; z = the second column showing frequency/BG area where applicable
  if cg eq 0 then begin
    st(0, * ) = ['--/--', f_core + '/' + d_core, '--/--', f_islet + '/' + d_islet, $
      f_perforated + '/' + d_perforated, f_edge + '/' + d_edge, $
      f_loop + '/' + d_loop, f_bridge + '/' + d_bridge, $
      f_branch + '/' + d_branch, ' --/' + d_bg, ' ' + missing + ' ', porosity + ' Porosity', $
      ' --/' + d_core_opening, ' --/' + d_border_opening]
    z = strtrim([0, freq_core, 0, freq_islet, freq_perforated, freq_edge, freq_loop, freq_bridge, freq_branch, $
      freq_backg, freq_missing, freq_opening, freq_core_opening, freq_border_opening],2)
  endif else begin
    st(0, * ) = [f_core_small + '/' + d_core_small, f_core + '/' + d_core, $
      f_core_large + '/' + d_core_large, f_islet + '/' + d_islet, $
      f_perforated + '/' + d_perforated, f_edge + '/' + d_edge, $
      f_loop + '/' + d_loop, f_bridge + '/' + d_bridge, $
      f_branch + '/' + d_branch, ' --/' + d_bg, ' ' + missing + ' ', porosity + ' Porosity', $
      ' --/' + d_core_opening, ' --/' + d_border_opening]
    z = strtrim([freq_core_small, freq_core, freq_core_large, freq_islet, freq_perforated, freq_edge, $
      freq_loop, freq_bridge, freq_branch, freq_backg, freq_missing, $
      freq_opening, freq_core_opening, freq_border_opening],2)
  endelse

  IF tintext EQ 1 THEN BEGIN
    z[11] = z[11] + '/' + strtrim(opening, 2)
    z[12] = z[12] + '/' + strtrim(core_opening, 2)
    z[13] = z[13] + '/' + strtrim(border_opening, 2)
  ENDIF ELSE BEGIN
    z[11] = '--/--'
    z[12] = '--/--'
    z[13] = '--/--'
    st[0,11] = z[11]
    st[0,12] = z[12]
    st[0,13] = z[13]
  ENDELSE
  z[9] = z[9] + '/' + strtrim(allbackg, 2) ;; add info on BG area
  ;; add info on missing
  z[10] = z[10] + '/' + strtrim(allmissing, 2)
  st(1, * ) = z

END
;;==============================================================================

;;==============================================================================
;;==============================================================================
PRO GWB_MSPA
;;==============================================================================
;;          GWB APP for Morphological Spatial Pattern Analysis (MSPA)
;;==============================================================================
;; 
;; Purpose: 
;;==============================================================================
;; IDL cmd-line app to conduct MSPA as implemented in GuidosToolbox (GTB)
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
GWB_mv = 'GWB_MSPA (version 1.9.3)'
;;
;; Module changelog:
;; 1.9.2: IDL 8.9.0
;; 1.9.1: added image size info, SW tag
;; 1.9.0: added note to restore files, fixed metadata description on loop, IDL 8.8.3
;; 1.8.8: flexible input reading
;; 1.8.7: IDL 8.8.2
;; 1.8.6: added mod_params check
;; 1.8.5: mspa v2.3, added porosity, switch for disk and statistics
;; 1.8.2: remove file size calculation, add memory check
;; 1.6  : nocheck, added output directory extension
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
;; b) mspa-parameters.txt: (see header info in input/mspa-parameters.txt)
;;  - FGconn: 8 (default) or 4
;;  - EdgeWidth: 1 (default) or larger integer values
;;  - Transition: 1 (default) or 0
;;  - IntExt: 1 (default) or 0
;;  - disk: 0 (default - faster) or 1 (20% less RAM but 40% slower)
;;  - statistics: 0 (default -  no stats) or 1 (add summary stats)
;;
;;==============================================================================
;; Output: in the subfolder "output"
;;==============================================================================
;; a) Summary statistics 
;; b) geotiff images showing MSPA
;;
;; Processing steps:
;; 1) verify parameter file and MSPA-compatibility of input image
;; 2) process for MSPA
;; 3) post-process (write out and dostats if wished for)
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
print,'GWB_MSPA using:'
if standalone eq 1 then dir_input = dir_inputdef + "/input"
if standalone eq 1 then dir_output = dir_inputdef + "/output"
print, 'dir_input= ', dir_input 
print, 'dir_output= ', dir_output

;; check for colortables
IF (file_info('idl/mspacolorston.sav')).exists EQ 0b THEN BEGIN
  print, "The file 'tools/idl/mspacolorston.sav' was not found."
  print, "Restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
ENDIF
IF (file_info('idl/mspacolorstoff.sav')).exists EQ 0b THEN BEGIN
  print, "The file 'tools/idl/mspacolorstoff.sav' was not found."
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
mod_params = dir_input + '/mspa-parameters.txt'
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
;; read MSPA settings, we need at least 6 valid lines
fl = file_lines(mod_params)
IF fl LT 6 THEN BEGIN
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
c_FGconn = strtrim(finp(q[0]), 2)
c_size = strtrim(finp(q[1]), 2)
c_trans = strtrim(finp(q[2]), 2)
c_intext = strtrim(finp(q[3]), 2)
c_disk = strtrim(finp(q[4]), 2)
c_stats = strtrim(finp(q[5]), 2)

;; MSPA-parameter 1: FGconn
if c_FGconn eq '8' then begin
  fconn = 1b
endif else if c_FGconn eq '4' then begin
  fconn = 0b
endif else begin
  print, "The file: " + mod_params + " is in a wrong format."
  print, "Foreground connectivity is not 8 or 4."
  print, "Please copy the respective backup file into your input directory:"
  print,  dir_inputdef + "/input/backup/*parameters.txt, or"
  print, "restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
endelse

;; MSPA-parameter 2: EdgeWidth
ccs = abs(fix(c_size))
if ccs eq 0 or ccs gt 100 then begin
  print, "The file: " + mod_params + " is in a wrong format."
  print, "EdgeWidth is not an integer number in [1, 100]."
  print, "Please copy the respective backup file into your input directory:"
  print,  dir_inputdef + "/input/backup/*parameters.txt, or"
  print, "restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "or restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
endif
c_size = strtrim(ccs,2)

;; MSPA-parameter 3: Transition
if c_trans eq '1' then begin
  restore, 'idl/mspacolorston.sav' & ttrans = 1b
endif else if c_trans eq '0' then begin
  restore, 'idl/mspacolorstoff.sav' & ttrans = 0b
endif else begin
  print, "Transition is not 1 or 0."
  print, "Please copy the respective backup file into your input directory:"
  print,  dir_inputdef + "/input/backup/*parameters.txt, or"
  print, "restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
endelse
tvlct, r, g, b

;; MSPA-parameter 4: Intext
if c_intext eq '1' then begin
  tintext = 1b
endif else if c_intext eq '0' then begin
  tintext = 0b
endif else begin
  print, "The file: " + mod_params + " is in a wrong format."
  print, "IntExt is not 1 or 0."
  print, "Please copy the respective backup file into your input directory:"
  print,  dir_inputdef + "/input/backup/*parameters.txt, or"
  print, "restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
endelse

;; processing parameter: disk
if c_disk eq '1' then begin
  tdisk = ' -disk'
endif else if c_disk eq '0' then begin
  tdisk = ' '
endif else begin
  print, "The file: " + mod_params + " is in a wrong format."
  print, "Disk is not 0 or 1."
  print, "Please copy the respective backup file into your input directory:"
  print,  dir_inputdef + "/input/backup/*parameters.txt, or"
  print, "restore the default files using the command: cp -fr /opt/GWB/*put ~/"
  print, "Exiting..."
  goto,fin
endelse

;; processing parameter: Statistics
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

dir_proc = dir_output + '/.proc'
;; cleanup temporary proc directory
file_delete, dir_proc, /recursive, /quiet, /allow_nonexistent
file_mkdir, dir_proc

;;==============================================================================
;;==============================================================================
;; apply MSPA settings in a loop over all tif images 
;;==============================================================================
;;==============================================================================
descbase = 'GTB_MSPA, https://forest.jrc.ec.europa.eu/en/activities/lpa/gtb/'
tagsw = 'TIFFTAG_SOFTWARE='+'"'+"GWB, https://forest.jrc.ec.europa.eu/en/activities/lpa/gwb/" +'" '
gedit = 'unset LD_LIBRARY_PATH; gdal_edit.py -mo ' + tagsw

fn_logfile = dir_output + '/mspa.log'
nr_im_files = ct_tifs & time00 = systime( / sec) & okfile = 0l
nocheck = file_info(dir_input + '/nocheck.txt') & nocheck = nocheck.exists

openw, 9, fn_logfile
if nocheck eq 0 then printf,9,GWB_mv else printf,9, GWB_mv + ' - nocheck'
printf, 9, 'MSPA batch processing logfile: ', systime()
printf, 9, 'Statistics: ' + dostats
printf, 9, 'Number of files to be processed: ', nr_im_files
printf, 9, '==============================================='
close, 9
;; write out the path to the logfile to append RAM usage later on
fn_dirs2 = strmid(fn_dirs,0,strlen(fn_dirs)-12) + 'gwb_mspa_log.txt'
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
    printf, 9, 'Skipping invalid input (empty space in directory path or input filename) '
    close, 9
    GOTO, skip_mspa  ;; invalid input
  ENDIF
  
  res = query_tiff(input, inpinfo)
  IF inpinfo.type NE 'TIFF' THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (not a TIF image): ', input
    close, 9
    GOTO, skip_mspa  ;; invalid input
  ENDIF

  ;; check for single image in file
  IF inpinfo.num_images GT 1 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (more than 1 image in the TIF image) '
    close, 9
    GOTO, skip_mspa  ;; invalid input
  ENDIF
  
  ss = inpinfo.dimensions & ssct = n_elements(ss)
  IF res EQ 0 or ssct ne 2 THEN BEGIN ;;invalid file , wrong dimensions
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (wrong dimensions) '
    close, 9
    GOTO, skip_mspa  ;; invalid input
  ENDIF
  
  ;; read it
  geotiff = 0
  im = read_tiff(input, geotiff=geotiff) & is_geotiff = (size(geotiff))[0]
  IF nocheck EQ 1b THEN goto, good2go

  ;; check for single channel image
  ;;===========================
  IF size(im, / n_dim) NE 2 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (more than 1 band in the TIF image) '
    close, 9
    GOTO, skip_mspa  ;; invalid input
  ENDIF

  ;; check for byte array
  ;;===========================
  IF size(im, / type) NE 1 THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (image is not of type BYTE) '
    close, 9
    GOTO, skip_mspa  ;; invalid input
  ENDIF

  ;; check min/max value in image
  ;;===========================
  mxx = max(im, min = mii)
  IF mxx GT 2b THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (Image maximum is larger than 2 BYTE) '
    close, 9
    GOTO, skip_mspa  ;; invalid input
  ENDIF ELSE IF mxx LT 2b THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (Image has no foreground (2 BYTE)) '
    close, 9
    GOTO, skip_mspa  ;; invalid input
  ENDIF
  IF mii GT 1b THEN BEGIN
    openw, 9, fn_logfile, /append
    printf, 9, 'Skipping invalid input (Image has no background (1 BYTE)) '
    close, 9
    GOTO, skip_mspa  ;; invalid input
  ENDIF

  good2go:
  ;;==============================================================================
  ;; 2) process for MSPA
  ;;==============================================================================
  time0 = systime( / sec)
  
  pushd, dir_proc
  tmp_in = 'inputmorph.tif'
  tmp_out = 'outputmorph.tif'
  write_tiff, tmp_in, temporary(im), compression = 1, /BIGTIFF
  file_copy, dir_gwb + '/mspa_lin64', 'mspa', /overwrite
  
  ;; execute the segmentation
;  cmd = './mspa -graphfg ' + c_FGconn + ' -eew ' + c_size + ' -internal ' + c_intext + $
;    ' -transition ' + c_trans + tdisk + ' -i inputmorph.tif -o outputmorph.tif -odir ./'
;  spawn, cmd, log
;
; a little bit faster...
  cmdarr = ['./mspa', '-graphfg', c_FGconn, '-eew', c_size, '-internal', c_intext, '-transition', c_trans]  
  if c_disk eq '1' then begin
    cmdarr = [[cmdarr], '-disk', '-i', 'inputmorph.tif', '-o', 'outputmorph.tif', '-odir', './']
  endif else begin
    cmdarr = [[cmdarr], '-i', 'inputmorph.tif', '-o', 'outputmorph.tif', '-odir', './']
  endelse  
  spawn, cmdarr, log, /noshell   
    
  im = read_tiff(tmp_out)
  ;; fix large size MSPA bug
  IF c_size EQ '1' THEN BEGIN
    q = where(im EQ 2b, ct, /l64) & IF ct GT 0 THEN im[q] = 0b 
  ENDIF  
  file_delete, tmp_in, tmp_out, /allow_nonexistent, /quiet
  popd
  
  ;;=======================================
  ;; write the final result
  fbn = file_basename(list[fidx], '.tif')
  outdir = dir_output + '/' + fbn + '_mspa' & file_mkdir, outdir
  fn_out = outdir + '/' + fbn + '_' + c_FGconn + '_' + c_size + '_' + c_trans + '_' + c_intext + '.tif'
  ;; add MSPA settings
  desc = descbase + ' ' + c_FGconn + '_' + c_size + '_' + c_trans + '_' + c_intext 
  
  ;; add the geotiff info if available
  IF is_geotiff gt 0 THEN $
    write_tiff, fn_out, im, red = r, green = g, blue = b, geotiff = geotiff, compression = 1 ELSE $
    write_tiff, fn_out, im, red = r, green = g, blue = b, compression = 1
  gedit = gedit + '-mo TIFFTAG_IMAGEDESCRIPTION="'+desc + '" '
  spawn, gedit + fn_out + ' > /dev/null 2>&1'
  
  if tstats eq 0b then goto, skip_stats ;; statistical summary not wanted
  
  ;; do and write out statistics
  simplestats, im, fconn, ttrans, tintext, 0, st
  fn_out_stats = outdir + '/' + fbn + '_' + c_FGconn + '_' + c_size + '_' + c_trans + '_' + c_intext + '.txt'
  row_lab = $
    ['CORE(s) [green]', 'CORE(m) [green]', 'CORE(l) [green]', 'ISLET [brown]', 'PERFORATION [blue]', $
    'EDGE [black]', 'LOOP [yellow]', 'BRIDGE [red]', 'BRANCH [orange]', 'Background [grey]', $
    'Missing [white]', 'Opening [grey]', 'Core-Opening [darkgrey]', 'Border-Opening [grey]']

  ;; calculate FG and iFG for output statistics
  ;; fg_area = image area - BG - missing
  fg_area = ulong64(ss[0])*ss[1] - ulong64((strsplit(st(1,9),'/',/extract))[1]) - ulong64((strsplit(st(1,10),'/',/extract))[1])
  if tintext eq 0b then xx = 0 else xx = ulong64((strsplit(st(1,11),'/',/extract))[1])
  iFG_area = fg_area + xx
  ;; convert to string
  fg_area = strtrim(fg_area,2) & iFG_area = strtrim(iFG_area,2)
  
  openw, 1, fn_out_stats
  printf, 1, 'MSPA results using: '
  printf, 1, fbn + ' (MSPA: ' + c_FGconn + '_' + c_size + '_' + c_trans + '_' + $
    c_intext + ', FG_area: ' + fg_area + ', iFG_area: ' + iFG_area + ')'
  printf, 1, ' '
  ;; write a title line
  printf, 1, '   MSPA-class [color]:  FG/data pixels [%]  #/BGarea'
  printf, 1, '============================================================'
  ;; write the statistics
  FOR is = 0, n_elements(row_lab) - 1 DO $
    printf, 1, format = '(a24,a15,a5,a)', row_lab(is) + ':  ', st(0, is), '', st(1, is)
  close, 1
  
  skip_stats:
  ;; update the log-file
  okfile = okfile + 1
  openw, 9, fn_logfile, /append
  printf, 9, 'MSPA comp.time [sec]: ', systime( / sec) - time0
  close, 9

  skip_mspa:
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
printf, 9, 'MSPA Batch Processing total comp.time: ', proctstr
printf, 9, 'Successfully processed files: ',strtrim(okfile,2)+'/'+ strtrim(nr_im_files,2)
printf, 9, '==============================================='
close, 9

print, 'MSPA processing finished sucessfully'

fin:
END
