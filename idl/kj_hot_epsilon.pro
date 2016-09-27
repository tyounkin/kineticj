function kj_dn, n

    d = dblArr(n+1)
    d[0] = 1

    if n eq 0 then begin
        return, d[0]
    endif else begin
       
        for _n=1,n do begin
            d[_n] = (2d0*_n+1d0)/2d0 * d[_n-1]
        endfor

    endelse
    return, d[n]

end

function kj_IPrime, zeta, n

    return, beselI(zeta,n-1) - n/zeta * beselI(zeta,n)

end

function kj_zFun, x

    @constants

    Z = dComplexArr(n_elements(x))

    ; Plasma dispersion function Z(x) is a scaled Faddeeva function w(x)
    ;
    ; Z(x) = i*sqrt(pi)*w(x)
    ;
    ; see Faddeeva_function on wikipedia
    ;
    ; w(x) = exp(-x^2) * erfc(-i*x)
    ;
    ; and for the special case of im(x) < 0 we have to use ...
    ;
    ; w(-z) = w(z*)*

    nMax = 10

    for i=0,n_elements(x)-1 do begin

        if abs(x[i]) gt 5.5 then begin

                ;sum = 0
                ;for n=0,nMax do begin
                ;    sum += x[i]^(2*n) / ( factorial(n) * (2*n+1) )
                ;endfor
                ;Z[i] = exp(-x[i]^2) * (_ii * sqrt(!dpi) - x[i] * sum  ) 

                sum = 0
                for n=0,nMax do begin
                    sum += kj_dn(n) / (x[i]^(2*n))
                endfor
                sig = 1
                if imaginary(x[i]) gt 0 then sig = 0
                if imaginary(x[i]) lt 0 then sig = 2

                Z[i] = _ii * sig * sqrt(!dpi) * exp(-x[i]^2) - sum / x[i]

        endif else begin

            if imaginary(x[i]) lt 0 then begin

                print, 'Z function problem'
                print, 'NOT tested or really even implemented'
                stop
                Z[i] = conj(kj_zFun(conj(-x[i]))) 

            endif else begin

                if real_part(x[i]) lt 0 then begin
                    Z[i] = -conj(kj_zFun(-x[i]))
                endif else begin
                    ;Z[i] =  _ii * sqrt(!pi) * exp(-x[i]*x[i]) * erfc ( -_ii * x[i] )
                    Z[i] =  _ii * sqrt(!dpi) * exp(-x[i]^2d0) * (1d0 + erf ( _ii * x[i] ) )

                    ;; Power series for x<<1

                    ;sum = 0
                    ;for n=0,nMax do begin
                    ;    sum += x[i]^(2*n) / ( factorial(n) * (2*n+1) )
                    ;endfor
                    ;_z = exp(-x[i]^2) * (_ii * sqrt(!dpi) - x[i] * sum  ) 
                    ;_z = dcomplex(2*real_part(_z),imaginary(_z)) ; Not sure where this factor of 2 comes from.

                    ;; Asymptotic series for x >> 1

                    ;sum = 0
                    ;for n=0,nMax do begin
                    ;    sum += kj_dn(n) / (x[i]^(2*n))
                    ;endfor
                    ;sig = 1
                    ;if imaginary(x[i]) gt 0 then sig = 0
                    ;if imaginary(x[i]) lt 0 then sig = 2

                    ;__z = _ii * sig * sqrt(!dpi) * exp(-x[i]^2) - sum / x[i]

                    ;print, x[i], _z, __z, Z[i]

                endelse

            endelse

        endelse

    endfor

    return, Z

end

function kj_zFunPrime, zeta

    return, -2d0 * ( 1d0 + zeta * kj_zFun(zeta) )

end

pro kj_hot_epsilon, f, amu, Z, B, density, harmonicNumber, kPar, kPer, T_eV

;n = 200
;x = (dIndGen(n)/(n-1)-0.5)*2*15
;z = kj_zFun(x)
;zP = kj_zFunPrime(x)
;p=plot(x,z)
;p=plot(x,imaginary(z),/over)
;p=plot(x,zP)
;p=plot(x,imaginary(zP),/over)
;
;stop

@constants

w = 2 * !Pi * f
m = amu * _amu
q = Z * _e
nPar = _c * kPar / w
nPer = _c * kPer / w

nS = n_elements(amu)

Shat = complex(1,0)
Dhat = complex(0,0)
Phat = complex(1,0)

etahat = complex(0,0)
tauhat = complex(0,0)
epshat = complex(0,0)

for alp = 0,nS-1 do begin

    wc = q[alp] * B / m[alp]
    wp = sqrt( density[alp] * q[alp]^2 / (m[alp] * _e0) ) 
    vTh = sqrt(2*T_eV[alp]*_e/m[alp])

    lambda = kPer^2 * vTh^2 / (2*wc^2)

    Ssum = complex(0,0)
    Dsum = complex(0,0)
    Psum = complex(0,0)

    eta_sum = complex(0,0)
    tau_sum = complex(0,0)
    eps_sum = complex(0,0)

    for n = -harmonicNumber,harmonicNumber do begin

        x = (w - n*wc) / (kPar * vTh)
        print, w-n*wc
        print, x
        x0 = w / (kPar * vTh)

        Ssum += n^2 / lambda * beselI(lambda, n, /double) * exp( -lambda ) * (-x0 * kj_Zfun(x) )
        Dsum += n * ( kj_IPrime(lambda, n) - beselI(lambda,n) ) * exp(-lambda) * (-x0 * kj_Zfun(x) )
        Psum += beselI(lambda,n) * exp(-lambda) * (-x0 * x * kj_zFunPrime(x) )

        eta_sum += n/lambda * beselI(lambda,n,/double) * exp(-lambda) * (x0^2 * kj_ZfunPrime(x) )
        tau_sum += ( kj_IPrime(lambda, n) - beselI(lambda,n,/double) ) * exp(-lambda) * (-x0 * kj_Zfun(x) )
        eps_sum += ( kj_IPrime(lambda, n) - beselI(lambda,n,/double) ) * exp(-lambda) * (x0^2 * kj_ZfunPrime(x) )

    endfor 

    Shat -= wp^2/w^2 * Ssum
    Dhat += wp^2/w^2 * Dsum
    Phat -= wp^2/w^2 * Psum

    etaHat += wp^2/(w*wc) * vth^2/_c^2 * eta_sum
    tauHat += wp^2/wc^2 * vth^2/_c^2 * tau_sum
    epsHat += wp^2/(w*wc) * vTh^2/_c^2 * eps_sum

endfor

etaHat = -etaHat/2.0
tauHat = -tauHat/2.0
epsHat = +epsHat/2.0


exx = SHat
exy = -_ii * DHat
exz = nPar * nPer * etaHat

eyx = +_ii * DHat
eyy = SHat - 2*nPer^2 * tauHat
eyz = +_ii * nPar * nPer * epsHat

ezx = nPar * nPer * etaHat
ezy = -_ii * nPar * nPer * epsHat
ezz = PHat

epsilon = dComplexArr(3,3)

epsilon[0,0] = exx
epsilon[0,1] = exy
epsilon[0,2] = exz

epsilon[1,0] = eyx
epsilon[1,1] = eyy
epsilon[1,2] = eyz

epsilon[2,0] = ezx
epsilon[2,1] = ezy
epsilon[2,2] = ezz


stop
end