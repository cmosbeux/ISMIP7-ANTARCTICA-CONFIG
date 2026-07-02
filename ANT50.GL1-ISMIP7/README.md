# ELMER_ISMIP6_Antarctica

Repository to work on the Elmer/Ice IGE contribution to ISMIP6.

## TODO

### Input
- [ ] Setup a data directory and add it in the README
- [X] SMB input file
    - [X] Control
    - [X] Scenario XXX
- [X] Ocean forcing data file
    - [X] Control
    - [X] delta T estimation
    - [X] Scenario XXX
- [ ] Benoit's grid (first)
    - [ ] grid with ice tongue and instruction to do it in README or elsewhere
    - [X] tools and instruction to convert restart from 1 grid to another that also manage change in partition numbers
    - [ ] grid refined over all the run history and instruction to do it in README or elsewhere
- [ ] Initial condition compatible with Benoit's grid (first)
    - [ ] Initial condition compatible with grid with no ice tongue
    - [ ] Initial condition compatible with grid refined
    - [X] Build netcdf restart => this will make obsolete the two previous points.
- [X] Clean directory for only the production file

### SIF
- [X] Check SSA  solver
- [X] Check H    solver
- [X] Check XIOS solver
    - [X] Check metadata
    - [X] Check integrated value wrt to save scalar
    - [X] Check all netcdf varaible with paraview (need sno account)
- [X] Netcdf restart
    - [X] Tools to interpolate from a result file to a netcdf file has been done
    - [X] Differences on domain interior tiny in a comparison .result and .nc restart format
    - [X] Why is there differences on the domain edges ?
- [ ] Coulomb Regularisé
    - [X] Convert linear friction coef from initial condition to CR friction coefficient
    - [ ] Check all blocs
- [X] Check SMB solver
    - [X] Read reference SMB
    - [X] Read anomaly SMB year by year
    - [X] Compute SMB as it is required for ISMIP6
- [ ] Check BMB solver
    - [X] PICO melt solver blocs and parameter
    - [ ] Quadratic local melt blocs and parameter
    - [ ] Check SIF compatibility (not both melt activated ...)
    - [X] Compute BMB as it is required for ISMIP6
- [X] Nearestpoint => create basin mask : variable added in restart (see TOOL/ADD_RST_VAR for method)

### Solver
- [ ] Build Quadratic melt Solver.F90
- [X] Update Benoit's regional pp to new variable name (dh/dt for example)

### Test to do
- [X] Check Benoit's IMITMIP diag and XIOS integrated method
   - [X] check all ouput with paraview (min, max, pattern ...)
   - [X] when succesful rm Benoit's diag
   - [X] buil pp script to do it
- [ ] compare overall with Benoit's configuration

### Run to do
#### Reference run
- [ ] Control
#### Perturbation runs
- [ ] ... to be completed
#### Otional runs
- [ ]

### Post Processing
- [X] review the ISMIP6 XIOS context file
- [X] review the ISMIP6 XIOS output file
- [X] build the pp script to convert XIOS output to ISMIP6 output
- [X] review the ISMIP6 output
- [ ] process all the output (available tools - need data)

### Distribution
- [ ] write readme
- [ ] push data on the server
