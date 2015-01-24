
;
;
; Author: Daisy Leung
;
; Last edit : Jan 24 2015
;
;
; Purpose: SMA calibration with MIR, personalized to what I prefer
;
; Note: checked command working with MIR version 150108
;
; ref: https://www.cfa.harvard.edu/~cqi/mircook.html
; ref: http://www.cfa.harvard.edu/sma/mir/
;
;

device, decomposed=0, retain=2
readdata, dir='SMA_DATA'     ; Read in SMA data

;Data inspection & editing:
select,/reset,/pos_wt,/display     ; select all good data with positive weights; /reset will reset the filter and ignore all the previous selection results, /display to print obs. info


; first identify the calibrators in plot_continuum
plot_continuum     ; ,x_var='hours', y_vars='amp,pha', frame_vars='blcd,rec,sb,band', color_vars='source', symbol_vars=0, frames_per_page=4     ; for continuum data (default to plot amp,pha vs hours for each integration w/ separate panels for combinations of baseline, receiver, sideband and continuum band, and a maximum of 4 plots per page. 

select, /p, /re, source=['+','3C220.3']
plot_var, x_var='rar', y_var='decr'          ; to help identify calibrators (near the science target)
;===== e.g. ======
;
;     ganymede = flux
;     quasar 0721+713 = phase and amp gain calibrator1
;     0102+584 = pointing, should be flagged using result=dat_filter(s_f, ' "integ" lt "9" ', /reset)
;    1048+717 = phase and gain calibrator2
;     Blazar 3c84 = passband 
;     1044+809 to check for the phase-gain solution (To be used as a check: one should apply the derived solution based on other calibrators to this object, image this object and make sure it is a point source, as well as checking consistency with the flux)
;=============== 

result=dat_filter(s_f, ' "integ" lt "10" ', /reset)      ; flag pointing

plot_continuum    ; Look at what is being flagged 
flag, /flag

select, /p, /re
plot_continuum

;Optional: 
;
;   * plot_var,x='u',y='v',frame_vars='sb'     ; inspect the uv-coverage 


select,/reset,/pos_wt      
plot_var,x='ha',y='tssb',frames_per_page='15'     ; T_sys versus hour angle; visibility weights which scale as 1/Tsys2
plot_var, x='int', frames=9          ; to check t_sys versus time..

;===== T_sys flagging ====
select, /p, /re, ant=5, int=[blah, blah]     ; Apply more flagging here before applying T_sys calibration
flag, /flag

;The SMA does not automatically scale the data by Tsys as would be done at most other radio telescopes. The amplitude out from correlator is not corrected by the attenuation of the Earth atmosphere. Thus, the visibility amplitude needs to be multiplied by system temperatures. After you make sure the tsys values look fine, you can weight the data by Tsys:

select,/reset,/pos_wt
apply_tsys     ; Apply T_sys calibration, corrects for atmospheric opacity
uti_avgband     ; average the data to recalculate the continuum
select,/reset,/pos_wt
mir_save,'data_tsys', /nowait     ; save the T_sys-corrected data to a new file
plot_spectra, ntrim=3, /norm, frames_per_page='16'     ; plot amp, ph as a function of channel numbers



;======================
;Bandpass calibration:

;If you are satisfied with the calibration solution, apply it once only. Applying it more than once will add noise to the data. 

;======================
;Examine the spectrum before passband calibration:
plot_spectra, /norm, source=['passband_calibrator'], frames_per_page='16'
;Do phase and amplitude passband calibration separately:
select, /p, /re
pass_cal, smoothing=3, frames_per_page=16, ntrim=3, cal_type='pha', refant=8     
    ;>> type "BP_calibrator yes"     If you are satisfied with the solutions, you can apply the solutions.
    ;>> yes

; Inspect calibrated phase 
BPpass_cal, smoothing=3, frames_per_page=16, ntrim=3, cal_type='pha', refant=8
    ;>> no
select, /p, /re
uti_avgband
pass_cal, smoothing=3, frames_per_page=16, ntrim=3, cal_type='amp', refant=8
    ;>> "BP_calibrator yes"
    ;>> yes if satisfy

; Inspect calibrated amp BP
pass_cal, smoothing=3, frames_per_page=16, ntrim=3, cal_type='amp', refant=8
    ;>> no

;Recalculate the continuum with the corrected phases:
select, /p, /re
uti_avgband
plot_spectra, source=['BP_calibrator'], /norm, frames_per_page=16, ntrim=3

; Optional:
    ; select, /p,/re , source=['BP_calibrator']
    ; result=plo_var('prbl', 'ampave', frames_per_page=16)     # amp versu project baseline


; save the bandpass-calibrated data to a new file.
select,/reset,/pos_wt
mir_save,'data_bp',/nowait




;==================== 

;Gain calibration: 
; (Take the "bandpass-calibrated" dataset)the source 0530+135 in this observation run is in fact to be used as a "gain calibrator" source, because we actually "know" how its visibisities should look like, given we know the source structure. Therefore, any deviation in the measured data from the ideal case can be attributed to the "gain" function. Again, by differencing the observed and "theoretical" measurements, we can derive the gain solutions as a function of time. 

;==================== 
select,/reset,/p
flux_measure_new, /scalar          ; use scalar average if phase calibration is not done with the gain calibrators; to measure the flux density of the gain calibrator based on flux calibrator, "flux_measure" averages all amplitudes and stores them in the integration headers where gain_cal can find      

    ;then you can see the flux of the gain calibrator 0530+135

select,/reset,/pos_wt,source=['0721+713', '1048+717', '3C220.3', '1044+809']          ; ['gain_calibrator', 'target source', 'consistency_gain_check']
gain_cal,cal_type='pha', x_var='hours', tel_bsl='telescope', refant=8, frames_per_page=16, smoothing=0.5      ; first calibrate the phase, apply gain_cal solution, 'telescope' meaning antenna-based       
    ;Enter source, cal code, and if cal, flux in Jy, eg: 3C273 YES 3.1 or hit Return if all the sources are correctly specified
    ;>> 0530+135 yes      
    ; Look at any phase jumps (maybe due to pointing), if so DO NOT APPLY SOLUTION      
    result=dat_filter(s_f, ' "inter" lt "10" ')     ; Flag unwanted data by integration time, usually posing scans are less than 10 seconds, selecting these and flag     
    result=dat_filter(s_f, ' "dhrs" gt "5.7" and "dhrs" lt "8.0" and "blcd" like "7" ')      ; flag data from blah hours to blah hours
    flag, /flag     
    ; then re-run gain_cal with a shorter smooth time after flagging (0.5)     
    select, /p, .re, source=['gain_calibrator', 'target source', 'gain_check2']     ; re-select     
    gain_cal, cal_type='pha', x_var='hours', tel_bsl='telescope', refant=8, frames_per_page='16', smooth=0.5                
    ; Apply gain solution? [NO <YES>]: yes   <- enter "yes" here if satisfy with the solution
flux_measure_new, /scalar      ; look and compare with /vector fluxes
flux_measure_new, /vector      ; for amplitude gain_calibration
gain_cal, cal_type='amp', x_var='hours', tel_bsl='baseline', refant=8, frames_per_page='16', smooth=0.5     ; amplitude gain calibration..
    ; >> "gain_calibrator yes flux"   << flux from /vector      
    ; >> apply "no" if smoothed fit is not good at pointing     
    result=dat_filter(s_f, ' "dhrs" gt 5.7" and "dhrs" lt "7.5" and "blcd" like "7" ')      ; flag data from blah hours to blah hours     
    flag, /flag    
    ; Re-run gain_cal for amplitude     
    select, /p, /re, source=['gain_calibrator', 'targetsource']     
    gain_cal, cal_type='amp', x_var='hours', tel_bsl='baseline', refant=4, frames_per_page='16', smooth=0.5     
    ;>>> apply: "yes" if it looks better after the flagging

  ;Inspect amplitude and phase calibrated:
  gain_cal, type='amp,pha', tele_bsl='telescope', frames_per_page=16     
    ;>>> Apply: "no"      ; do not apply calibration second time

  ;if Needed: Run the same gain calibration for another pair ['gain_calibrator2', 'targetsouce2']

select,/reset,/pos_wt     ; unset before saving
mir_save,'data_gain',/nowait     ; save


; ==================
; Flux Calibration:
; ===================
select, /p, /re, source='flux_calibrator'     ; Self calibrate the flux calibrator, phase only. 
gain_cal, cal_type='pha', x_var='int', tel_bsl='telescope', refant=8, frames_per_page='8', /connect, /non_point     
    ;>> "flux_calibrator yes"     
    ;>> Apply: "yes"
select,/reset,/pos_wt, source=['ganymede', '0721+713', '1048+717', '3C220.3', '1044+809'] ; ['flux', 'gain', 'gain', 'science_target', 'gaincheck']     
sma_flux_cal     ; determine the absolute flux scale     
    ; Enter flux calibrator source, and if needed, flux in Jy, eg: 3c279 18.1          ; Primary
    ; >> urnaus 65.18           

    ; select which scale factors to scale data:      1. sidebands; 2. baselines; other. single(all)      
    ;[for 2: i.e., using different scaling factor for different baselines]

    ;Apply Flux Calibration? [NO <YES>]:      

flux_measure     
    ;>> v


; ==============
; Doppler:
; ==============
select, /p, /re
uti_doppler_fix, reference = 'trackedsource', source='to be corrected source'


; ============================
; FINALLY inspection:
; ============================
select, /p, /re, source=['gain_calibrator']
plot_var, x='prbl', y='ampave', frame_var='sb', color='blcd'     ; should look constant amplitude with baseline (of the gain_calibrator (point source))
select, /p, /re, source=['2nd gain_calibrator']
plot_var, x='prbl', y='ampave', frame_var='sb', color='blcd'
select, /p, /re, source=['consistency_gain_check']
plot_var, x='prbl', y='ampave', frame_var='sb', color='blcd'   
select, /p, /re, source=['first_target']
plot_spectra, x_var='fsky', frame_var='sb', color='band', ntrim=8     ; continuum band

; ==============
;FINAL save:
; ==============
select,/reset,/pos_wt     ; unset before saving
mir_save,filename='data_final',/nowait     ; save

; We need transfer the data from MIR format to Miriad format:
select,/reset,/pos_wt
idl2miriad,source='0530+135',sideband='l', dir='0530+135_lsb'
idl2miriad,source='HH212_N',sideband='l', dir='HH212N_lsb'
idl2miriad,source='HH212_S',sideband='l', dir='HH212S_lsb'
