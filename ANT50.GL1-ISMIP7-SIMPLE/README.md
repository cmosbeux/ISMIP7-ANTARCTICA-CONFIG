# Simple Antarctic configuration

This directory contains a simplified Elmer/Ice Antarctic test configuration.
It reads an existing mesh and restart, computes flotation and SSA velocity, and
uses PICO to calculate ice-shelf basal melt. The SIF also contains a thickness
solver and a basin-based passive region. It is a test setup, not an automated
ISMIP7 production workflow; the source directory contains additional collapse
utilities, but the current SIF does not activate a collapse solver.

## Files and requirements

- `TEST/Antarctica.sif`: simulation, solver and boundary-condition settings.
- `TEST/elmer.param`: physical and PICO parameters, in MPa, metres and days.
- `TEST/FRICTION_PARAM/`: alternative SSA friction-law includes.
- `MY_SRC/`: Fortran sources for the basin reader, PICO and other utilities.
- `TEST/MSH/`: Elmer mesh and `restart_000.nc` initial fields.
- `TEST/PICO/`: basin map and ocean-forcing NetCDF files.

The test needs Elmer/Ice, `elmerf90`, a Fortran compiler and NetCDF Fortran
and C libraries. The mesh, restart and locally prepared files must be available
at the paths in the SIF; the existing `MSH` link may need to be changed on
another machine. In particular, check that `elmer.param`, the test `Makefile`
and all required source and input files are present in your checkout.

The restart reader requests `h`, `zs`, `zb`, `haf`, `groundedmask`, `bedrock`,
`mueta2`, `beta_1` and both `ssavelocity` components. The current basin
reader requests the `basins` variable from the Schmidtko basin file, and PICO
uses `Zhou_climatology_PICO.nc`. Paths are relative to the directory from
which ElmerSolver is launched.

## Run the test

From `TEST/`, check the file paths in `Antarctica.sif`, then build the user
functions and launch the solver:

```bash
cd ANT50.GL1-ISMIP7-SIMPLE/TEST
make compile
ElmerSolver Antarctica.sif
```
## Main Features of the simulation

1. The mehs is provided but is created in a similar fashion as in the ElmerIceCourse 2026
   with some adaptations to get a higher resolution in regions of interest
2. We run a simulation from a initial configuration of Antarctica obtained by inversion of
   two key parameters: `beta` (the friction coefficient) and `mu` (the effective viscosity)
3. We then compute the floatation based on a hydrostatic equilibrium
4. We compute the ocean
5. We compute the SSA solution (a simplification of the Stokes equations)
6. We update the thickness usig the calculated velocity in the SSA solver.
7. We save the result
8. We loop again.

## SIF configuration

The solver sequence is:

1. `UGridDataReader` loads the restart before the simulation.
2. `Flotation` computes `GroundedMask`, surface and base elevations, and
   height above flotation.
3. `nearestpoint` maps basin numbers from the NetCDF file to mesh elements
   before the simulation.
4. `Melt` computes grounding-line and front distances and PICO basal melt.
   The current setup uses a uniform temperature correction of -1 degree C.
5. `SSA` computes horizontal velocity using UMFPACK and the friction include
   selected in `Material 1`.
6. `Thickness` is configured but disabled with `Exec Solver = Never`; enable
   it explicitly to evolve thickness.
7. `ResultOutput` writes VTU files after saving.

The current test uses ten 0.01-day timesteps and outputs every step. Adjust
these settings in the `Simulation` block. The SSA block allows up to 20
nonlinear iterations and does not abort if they fail to converge: inspect
the solver log and convergence before interpreting results.

The current friction include, `friction_law.weertman1`, is linear and uses
`beta_1`. Other includes are supplied, but may need different restart fields
and parameters; check their requirements before switching. The boundary
condition marks boundary 1 as the calving front and ice front.

### Regional passive mask

The `Body Force 1` passive expressions select basin 14 as the non-passive
region: they return zero inside basin 14 and one elsewhere. Change the basin
number or remove the passive settings to change the domain of the solve.
The thickness mask has no effect while the thickness solver is disabled.

Passive elements do not remove the rest of the mesh from every computation,
and artificial regional boundaries can affect velocity. The current
`SSAVelocity 1` and `SSAVelocity 2` prescribed values are commented out;
choose and verify the intended passive-region and boundary conditions before
using the regional result. 