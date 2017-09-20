pro kj_stix_current, overPlotSolution = _overPlotSolution, useRS=_useRS, hot=_hot, $
        jr = jr, jt = jt, jz = jz, kjDeltaFileName = _kjDeltaFileName, $
        referenceSolutionDir = _referenceSolutionDir, rgrid = rgrid, $
        previousDelta_r = _previousDelta_r, $
        previousDelta_t = _previousDelta_t, $
        previousDelta_z = _previousDelta_z

if keyword_set(_overPlotSolution) then overPlotSolution = 1 else overPlotSolution = 0
if keyword_set(_useRS) then useRS = _useRS else useRS = 0
if keyword_set(_hot) then hot = _hot else hot = 0
if keyword_set(_kjDeltaFileName) then kjDeltaFileName = _kjDeltaFileName else kjDeltaFileName = 'kj-stix.nc'
if keyword_set(_referenceSolutionDir) then referenceSolutionDir = _referenceSolutionDir else referenceSolutionDir = './'

useAR = 1
if useRS then useAR = 0 


@constants

; Get the plasma parameters

arP = ar2_read_runData('./',1)

f = arP.freq
w = 2 * !pi * f
B = sqrt( arP.br^2 + arP.bt^2 + arP.bz^2 )
r = arP.r
nPhi = arP.nPhi
nX = n_elements(arP.br)
density = arP.densitySpec
temp = arP.tempSpec
nuOmg = arP.nuOmg
kz = 0

if keyword_set(_previousDelta_r) then previousDelta_r = _previousDelta_r else previousDelta_r = complexArr(nX)
if keyword_set(_previousDelta_t) then previousDelta_t = _previousDelta_t else previousDelta_t = complexArr(nX)
if keyword_set(_previousDelta_z) then previousDelta_z = _previousDelta_z else previousDelta_z = complexArr(nX)

ar2 = ar2_read_ar2input('./')

amu = ar2.amu
atomicZ = ar2.atomicZ

nS = n_elements(amu)

; Get the E field

if useAR then begin
    print, 'Reading AR Solution'
    solution = ar2_read_solution('./',1)
    solution_ref = ar2_read_solution(referenceSolutionDir,1)
endif

if useRS then begin
    print, 'Reading RS Solution'
    solution = rsfwc_read_solution('./')
    solution_ref = rsfwc_read_solution(referenceSolutionDir)
endif

if hot then begin
    print, 'Using HOT dielectric'
endif else begin
    print, 'Using COLD dielectric'
endelse

; For each species

kPar = nPhi / r
harmonicNumber = 10 

windowWidth = 400

jr = complexArr(nX,nS)
jt = complexArr(nX,nS)
jz = complexArr(nX,nS)

run = 1
savFileName = 'kj-stix.sav'

if run then begin

kxArr = fltArr(nX,windowWidth+1)
ekrArr = complexArr(nX,windowWidth+1)
ektArr = complexArr(nX,windowWidth+1)
ekzArr = complexArr(nX,windowWidth+1)
sig2 = complexArr(3,3,nX,windowWidth+1,nS)
sigc = complexArr(3,3,nX,windowWidth+1,nS)


; Move the rotation matrix outside of the loop 

R_abp_to_rtz = fltArr(3,3,nX) 
for i=1,nX-2 do begin
    thisBUnitVec = [arp.br[i],arp.bt[i],arp.bz[i]]/B[i]
    R_abp_to_rtz[*,*,i] = get_rotmat_abp_to_rtz(thisBUnitVec)
endfor

; Main loop

for s=0,nS-1 do begin

    for i=1,nX-2 do begin
    
        iL = (i-windowWidth/2)>0
        iR = (i+windowWidth/2)<(nX-1)
    
        thisWindowWidth = min([i-iL,iR-i])*2+1
    
        if thisWindowWidth gt windowWidth+1 then stop
    
        iL = i - (thisWindowWidth-1)/2
        iR = i + (thisWindowWidth-1)/2
    
        _iL = 0 
        _iR = thisWindowWidth - 1
    
        ; Extract and window the E field
        
        N = n_elements(solution.E_r[iL:iR])
    
        if useRS then begin
            er = +solution.e_r[iL:iR] * hanning(n)
            et = +solution.e_t[iL:iR] * hanning(n)
            ez = +solution.e_z[iL:iR] * hanning(n)
        endif else begin
            er = +solution.e_r[iL:iR] * hanning(n)
            et = -solution.e_t[iL:iR] * hanning(n)
            ez = +solution.e_z[iL:iR] * hanning(n)
        endelse
        
        ; forward fft
        
        ekr = fft(er,/center)
        ekt = fft(et,/center)
        ekz = fft(ez,/center)
       
        ekrArr[i,_iL:_iR] = ekr
        ektArr[i,_iL:_iR] = ekt
        ekzArr[i,_iL:_iR] = ekz
    
        dx = r[1]-r[0]
        kxaxis = findgen(n) / ( dx * n ) * 2*!pi 
        dk = kxaxis[1]-kxaxis[0]
        kxaxis = kxaxis - kxaxis[-1]/2 - dk/2
       
        kxArr[i,_iL:_iR] = kxAxis
    
        kPer = sqrt(kxAxis^2+kz^2)
    
        ; Get sigma for each k 
      
        jkr = complexArr(N)
        jkt = complexArr(N)
        jkz = complexArr(N)
    
        ;for k=0,N-1 do begin
    
            epsilon_bram = kj_epsilon_hot( f, amu[s], atomicZ[s], B[i], $
                    density[i,0,s], harmonicNumber, kPar[i], kPer, temp[i,0,s], $
                    kx = 0, nuOmg = nuOmg[i,0,s], epsilon_cold = epsilon_cold, $
                    epsilon_swan_ND = epsilon_swan );
    
            epsilon_cold = complex(rebin(real_part(epsilon_cold),3,3,N),rebin(imaginary(epsilon_cold),3,3,N))
    
            sigma_bram =  ( epsilon_bram - rebin(identity(3),3,3,N) ) * w * _e0 / _ii
            sigma_swan =  ( epsilon_swan - rebin(identity(3),3,3,N) ) * w * _e0 / _ii
            sigma_cold =  ( epsilon_cold - rebin(identity(3),3,3,N) ) * w * _e0 / _ii
    
            ; Rotate sigma from ABP to RTZ
    
            ;thisBUnitVec = [arp.br[i],arp.bt[i],arp.bz[i]]/B[i]
    
            for k=0,N-1 do begin
    	        sigma_bram[*,*,k] = rotateEpsilon ( sigma_bram[*,*,k], thisBUnitVec, R = R_abp_to_rtz[*,*,i] )
    	        sigma_swan[*,*,k] = rotateEpsilon ( sigma_swan[*,*,k], thisBUnitVec, R = R_abp_to_rtz[*,*,i] )
    	        sigma_cold[*,*,k] = rotateEpsilon ( sigma_cold[*,*,k], thisBUnitVec, R = R_abp_to_rtz[*,*,i] )
            endfor
    
            ; Choose hot or cold sigma 
    
            _sigma = sigma_cold
            if hot then begin
                _sigma = sigma_swan
                ;_sigma = sigma_bram
            endif
    
            sig2[*,*,i,_iL:_iR,s] = _sigma
            sigc[*,*,i,_iL:_iR,s] = sigma_cold
    
            ; Calculate k-space plasma current
            ; This would have to be generalize for non magnetically aligned coordinates.
    
            ; Try flipping the indexing order also.
    
            if useRS then begin
                jkr = +(_sigma[0,0,*] * Ekr + _sigma[1,0,*] * Ekt + _sigma[2,0,*] * Ekz)[*]
                jkt = +(_sigma[0,1,*] * Ekr + _sigma[1,1,*] * Ekt + _sigma[2,1,*] * Ekz)[*]
                jkz = +(_sigma[0,2,*] * Ekr + _sigma[1,2,*] * Ekt + _sigma[2,2,*] * Ekz)[*]
            endif else begin
                jkr = +(_sigma[0,0,*] * Ekr + _sigma[1,0,*] * Ekz + _sigma[2,0,*] * Ekt)[*]
                jkz = +(_sigma[0,1,*] * Ekr + _sigma[1,1,*] * Ekz + _sigma[2,1,*] * Ekt)[*]
                jkt = -(_sigma[0,2,*] * Ekr + _sigma[1,2,*] * Ekz + _sigma[2,2,*] * Ekt)[*]
            endelse
        ;endfor
        
        ; Inverse FFT for configuration-space plasma current
        
        thisjr = fft(jkr,/center,/inverse)
        thisjt = fft(jkt,/center,/inverse)
        thisjz = fft(jkz,/center,/inverse)
    
        jr[i,s] = thisjr[N/2]
        jt[i,s] = thisjt[N/2]
        jz[i,s] = thisjz[N/2]
    
    endfor

endfor

    save, jr, jt, jz, sig2, fileName=savFileName, /variables

endif else begin

    restore, savFileName

endelse

Er = solution.E_r
Et = solution.E_t
Ez = solution.E_z

p=plot(r,Er,layout=[1,3,1])
p=plot(r,imaginary(Er),color='r',/over)

p=plot(r,Et,layout=[1,3,2],/current)
p=plot(r,imaginary(Et),color='r',/over)

p=plot(r,Ez,layout=[1,3,3],/current)
p=plot(r,imaginary(Ez),color='r',/over)

current=0
for s=0,nS-1 do begin

    p=plot(r,jr[*,s],layout=[nS,3,1+s],current=current)
    p=plot(r,imaginary(jr[*,s]),color='r',/over)
    if overPlotSolution then begin
        p=plot(solution_ref.r,solution.JP_r[*,0,s],thick=4,transparency=80,/over)            
        p=plot(solution_ref.r,imaginary(solution.JP_r[*,0,s]),color='r',thick=4,transparency=80,/over)            

        p=plot(solution_ref.r,solution.JP_r[*,0,s]-jr[*,s],thick=1,/over,lineStyle='--')            
        p=plot(solution_ref.r,imaginary(solution.JP_r[*,0,s]-jr[*,s]),color='r',/over,lineStyle='--')            
    endif

    current = (current + 1)<1
    p=plot(r,jt[*,s],layout=[nS,3,1+1*nS+s],current=current)
    p=plot(r,imaginary(jt[*,s]),color='r',/over)
    if overPlotSolution then begin
        p=plot(solution_ref.r,solution.JP_t[*,0,s],thick=4,transparency=80,/over)            
        p=plot(solution_ref.r,imaginary(solution.JP_t[*,0,s]),color='r',thick=4,transparency=80,/over)            
    endif

    p=plot(r,jz[*,s],layout=[nS,3,1+2*nS+s],current=current)
    p=plot(r,imaginary(jz[*,s]),color='r',/over)
    if overPlotSolution then begin
        p=plot(solution_ref.r,solution.JP_z[*,0,s],thick=4,transparency=80,/over)            
        p=plot(solution_ref.r,imaginary(solution.JP_z[*,0,s]),color='r',thick=4,transparency=80,/over)            
    endif

endfor

if not useRS then begin

    ; Compare the global spectrum and sigmas for that spectrum
    
    xrange = [-200,800]
    
    ekr = -fft(solution.e_r,/center)
    ekt = fft(solution.e_t,/center)
    ekz = fft(solution.e_z,/center)
    N = n_elements(solution.e_r)
    
    dx = r[1]-r[0]
    kxaxis = findgen(n) / ( dx * N ) * 2*!pi 
    dk = kxaxis[1]-kxaxis[0]
    kxaxis = kxaxis - kxaxis[-1]/2 - dk/2
    
    s = 2
    iX = nX/2
    
    p=plot(solution.kr,solution.ealpk,layout=[1,3,1],xrange=xrange)
    p=plot(solution.kr,imaginary(solution.ealpk),color='r',/over)
    p=plot(kxaxis,ekr,/over,thick=3,transparency=50)
    p=plot(kxaxis,imaginary(ekr),color='r',/over,thick=3,transparency=50)
    p=plot(kxArr[iX,*],ekrArr[iX,*],/over,color='b',thick=4,trans=50)
    p=plot(kxArr[iX,*],imaginary(ekrArr[iX,*]),/over,color='magenta',thick=4,trans=50)
    
    p=plot(solution.kr,solution.ebetk,layout=[1,3,2],/current,xrange=xrange)
    p=plot(solution.kr,imaginary(solution.ebetk),color='r',/over)
    p=plot(kxaxis,ekz,/over,thick=3,transparency=50)
    p=plot(kxaxis,imaginary(ekz),color='r',/over,thick=3,transparency=50)
    p=plot(kxArr[iX,*],ekzArr[iX,*],/over,color='b',thick=4,trans=50)
    p=plot(kxArr[iX,*],imaginary(ekzArr[iX,*]),/over,color='magenta',thick=4,trans=50)
    
    p=plot(solution.kr,solution.eprlk,layout=[1,3,3],/current,xrange=xrange)
    p=plot(solution.kr,imaginary(solution.eprlk),color='r',/over)
    p=plot(kxaxis,ekt,thick=3,transparency=50,/over)
    p=plot(kxaxis,imaginary(ekt),color='r',/over,thick=3,transparency=50)
    p=plot(kxArr[iX,*],ektArr[iX,*],/over,color='b',thick=4,trans=50)
    p=plot(kxArr[iX,*],imaginary(ektArr[iX,*]),/over,color='magenta',thick=4,trans=50)
    
    
    
    p=plot(solution.kr,solution.sig[0,0,ix,*,s],layout=[3,3,1])
    p=plot(solution.kr,imaginary(solution.sig[0,0,ix,*,s]),color='r',/over)
    p=plot(kxArr[iX,*],sig2[0,0,ix,*,s],/over,thick=3,trans=50)
    p=plot(kxArr[iX,*],imaginary(sig2[0,0,ix,*,s]),color='r',/over,thick=3,trans=50)
    p=plot(kxArr[iX,*],sigc[0,0,ix,*,s],/over,thick=3,trans=50,color='b')
    p=plot(kxArr[iX,*],imaginary(sigc[0,0,ix,*,s]),color='m',/over,thick=3,trans=50)
    
    
    p=plot(solution.kr,solution.sig[0,1,ix,*,s],layout=[3,3,2],/current)
    p=plot(solution.kr,imaginary(solution.sig[0,1,ix,*,s]),color='r',/over)
    p=plot(kxArr[iX,*],sig2[0,1,ix,*,s],/over,thick=3,trans=50)
    p=plot(kxArr[iX,*],imaginary(sig2[0,1,ix,*,s]),color='r',/over,thick=3,trans=50)
    p=plot(kxArr[iX,*],sigc[0,1,ix,*,s],/over,thick=3,trans=50,color='b')
    p=plot(kxArr[iX,*],imaginary(sigc[0,1,ix,*,s]),color='b',/over,thick=3,trans=50)
    
    
    p=plot(solution.kr,solution.sig[0,2,ix,*,s],layout=[3,3,3],/current)
    p=plot(solution.kr,imaginary(solution.sig[0,2,ix,*,s]),color='r',/over)
    p=plot(kxArr[iX,*],sig2[0,2,ix,*,s],/over,thick=3,trans=50)
    p=plot(kxArr[iX,*],imaginary(sig2[0,2,ix,*,s]),color='r',/over,thick=3,trans=50)
    p=plot(kxArr[iX,*],sigc[0,2,ix,*,s],/over,thick=3,trans=50,color='b')
    p=plot(kxArr[iX,*],imaginary(sigc[0,2,ix,*,s]),color='m',/over,thick=3,trans=50)
    
    
    p=plot(solution.kr,solution.sig[1,0,ix,*,s],layout=[3,3,4],/current)
    p=plot(solution.kr,imaginary(solution.sig[1,0,ix,*,s]),color='r',/over)
    p=plot(kxArr[iX,*],sig2[1,0,ix,*,s],/over,thick=3,trans=50)
    p=plot(kxArr[iX,*],imaginary(sig2[1,0,ix,*,s]),color='r',/over,thick=3,trans=50)
    p=plot(kxArr[iX,*],sigc[1,0,ix,*,s],/over,thick=3,trans=50,color='b')
    p=plot(kxArr[iX,*],imaginary(sigc[1,0,ix,*,s]),color='m',/over,thick=3,trans=50)
    
    
    p=plot(solution.kr,solution.sig[1,1,ix,*,s],layout=[3,3,5],/current)
    p=plot(solution.kr,imaginary(solution.sig[1,1,ix,*,s]),color='r',/over)
    p=plot(kxArr[iX,*],sig2[1,1,ix,*,s],/over,thick=3,trans=50)
    p=plot(kxArr[iX,*],imaginary(sig2[1,1,ix,*,s]),color='r',/over,thick=3,trans=50)
    p=plot(kxArr[iX,*],sigc[1,1,ix,*,s],/over,thick=3,trans=50,color='b')
    p=plot(kxArr[iX,*],imaginary(sigc[1,1,ix,*,s]),color='m',/over,thick=3,trans=50)
    
    
    p=plot(solution.kr,solution.sig[1,2,ix,*,s],layout=[3,3,6],/current)
    p=plot(solution.kr,imaginary(solution.sig[1,2,ix,*,s]),color='r',/over)
    p=plot(kxArr[iX,*],sig2[1,2,ix,*,s],/over,thick=3,trans=50)
    p=plot(kxArr[iX,*],imaginary(sig2[1,2,ix,*,s]),color='r',/over,thick=3,trans=50)
    p=plot(kxArr[iX,*],sigc[1,2,ix,*,s],/over,thick=3,trans=50,color='b')
    p=plot(kxArr[iX,*],imaginary(sigc[1,2,ix,*,s]),color='m',/over,thick=3,trans=50)
    
    
    p=plot(solution.kr,solution.sig[2,0,ix,*,s],layout=[3,3,7],/current)
    p=plot(solution.kr,imaginary(solution.sig[2,0,ix,*,s]),color='r',/over)
    p=plot(kxArr[iX,*],sig2[2,0,ix,*,s],/over,thick=3,trans=50)
    p=plot(kxArr[iX,*],imaginary(sig2[2,0,ix,*,s]),color='r',/over,thick=3,trans=50)
    p=plot(kxArr[iX,*],sigc[2,0,ix,*,s],/over,thick=3,trans=50,color='b')
    p=plot(kxArr[iX,*],imaginary(sigc[2,0,ix,*,s]),color='m',/over,thick=3,trans=50)
    
    
    p=plot(solution.kr,solution.sig[2,1,ix,*,s],layout=[3,3,8],/current)
    p=plot(solution.kr,imaginary(solution.sig[2,1,ix,*,s]),color='r',/over)
    p=plot(kxArr[iX,*],sig2[2,1,ix,*,s],/over,thick=3,trans=50)
    p=plot(kxArr[iX,*],imaginary(sig2[2,1,ix,*,s]),color='r',/over,thick=3,trans=50)
    p=plot(kxArr[iX,*],sigc[2,1,ix,*,s],/over,thick=3,trans=50,color='b')
    p=plot(kxArr[iX,*],imaginary(sigc[2,1,ix,*,s]),color='m',/over,thick=3,trans=50)
    
    
    p=plot(solution.kr,solution.sig[2,2,ix,*,s],layout=[3,3,9],/current)
    p=plot(solution.kr,imaginary(solution.sig[2,2,ix,*,s]),color='r',/over)
    p=plot(kxArr[iX,*],sig2[2,2,ix,*,s],/over,thick=3,trans=50)
    p=plot(kxArr[iX,*],imaginary(sig2[2,2,ix,*,s]),color='r',/over,thick=3,trans=50)
    p=plot(kxArr[iX,*],sigc[2,2,ix,*,s],/over,thick=3,trans=50,color='b')
    p=plot(kxArr[iX,*],imaginary(sigc[2,2,ix,*,s]),color='m',/over,thick=3,trans=50)

endif

; Write the kinetic-j update / delta to a file

nc_id = nCdf_create (kjDeltaFileName, /clobber )

	nCdf_control, nc_id, /fill
	
	nr_id = nCdf_dimDef ( nc_id, 'nR', n_elements(r) )
	scalar_id = nCdf_dimDef ( nc_id, 'scalar', 1 )

	freq_id = nCdf_varDef ( nc_id, 'freq', scalar_id, /float )
	r_id = nCdf_varDef ( nc_id, 'r', nr_id, /float )

	jr_re_id = nCdf_varDef ( nc_id, 'jP_r_re', nr_id, /float )
	jr_im_id = nCdf_varDef ( nc_id, 'jP_r_im', nr_id, /float )
	jt_re_id = nCdf_varDef ( nc_id, 'jP_t_re', nr_id, /float )
	jt_im_id = nCdf_varDef ( nc_id, 'jP_t_im', nr_id, /float )
	jz_re_id = nCdf_varDef ( nc_id, 'jP_z_re', nr_id, /float )
	jz_im_id = nCdf_varDef ( nc_id, 'jP_z_im', nr_id, /float )

    nCdf_control, nc_id, /enDef

	nCdf_varPut, nc_id, freq_id, f

	nCdf_varPut, nc_id, r_id, r 
   
    sign = +1
    relaxTo = 1

    delta_r = sign * (total(reform(solution_ref.jp_r) - jr,2))
    delta_t = sign * (total(reform(solution_ref.jp_t) - jt,2))
    delta_z = sign * (total(reform(solution_ref.jp_z) - jz,2))

    deltaUR_r = (relaxTo)*delta_r + (1-relaxTo) * previousDelta_r 
    deltaUR_t = (relaxTo)*delta_t + (1-relaxTo) * previousDelta_t 
    deltaUR_z = (relaxTo)*delta_z + (1-relaxTo) * previousDelta_z 

	nCdf_varPut, nc_id, jr_re_id, real_part( deltaUR_r )
	nCdf_varPut, nc_id, jr_im_id, imaginary( deltaUR_r )
	nCdf_varPut, nc_id, jt_re_id, real_part( deltaUR_t )
	nCdf_varPut, nc_id, jt_im_id, imaginary( deltaUR_t )
	nCdf_varPut, nc_id, jz_re_id, real_part( deltaUR_z )
	nCdf_varPut, nc_id, jz_im_id, imaginary( deltaUR_z )

nCdf_close, nc_id

rgrid = r

end
