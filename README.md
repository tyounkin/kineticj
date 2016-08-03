# kineticj
Given a time harmonic electric wave field calculate the kinetic plasma current
## Build on gpufusion.ornl.gov
```
source env-gpufusion.sh
make clean
make
```

### Calculate the Guiding Center terms file

From the https://github.com/dlg0/orbit_tracer repo, run the `gc_terms.pro` routine on an `ar2Input.nc` file ...
```
cd ~/scratch/aorsa2d/colestock-kashuba-reference
idl
IDL>@constants
IDL>gc_terms, _me_amu, -1, ar2='input/ar2Input.nc', /oneD
```
