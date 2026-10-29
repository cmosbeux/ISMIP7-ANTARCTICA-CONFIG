# Surface mass balance for TIPMIP Antarctica

Authors: Cyrille Mosbeux (based on some sources from A. Gilbert)

This repository contains an Elmer/Ice surface mass-balance (SMB) solver based on monthly precipitation and positive-degree-day melt. The solver accumulates the monthly contributions and writes annual SMB after the twelfth call.

## Source code

The Fortran sources are in `MY_SRC`; example Elmer input files and a test case are in `TEST`. `TIPMIP_SMB_Elemental.F90` is the location-aware implementation used by the example configuration. Despide its name, it supports both nodal and elemental output variables.

## Solver usage

Configure the solver in an Elmer SIF file. The output field is selected with the standard `Variable` setting; its existing nodal or elemental location determines where annual SMB is written.

```fortran
Solver 4
  Exec Solver = After Timestep
  Equation = String "Annual SMB"
  Procedure = "TIPMIP_SMB_Elemental" "TransientMassBalance_SMB"
  Variable = String "SMB"

  Reference SMB Variable = String "SMBref"
  Reference Temperature Variable = String "Tref"
  Precipitation Ratio Variable = String "Pratio"
  Temperature Anomaly Variable = String "Ts_anomaly"

  Radiative Mode = Logical False
  Elevation Feedback Mode = Logical False
End
```

The variable names shown are also the names used in `TEST/SMB.sif`. If omitted, the solver uses `Mass Balance` for the output and `SMBref`, `Surface Temperature`, `Precipitation Ratio`, and `Temperature Anomaly` for the forcing fields. The output variable must already exist and be scalar, either nodal or elemental.

## Inputs and calculation

- `Reference SMB Variable`: annual reference precipitation/SMB field. Negative values are clipped to zero for precipitation.
- `Reference Temperature Variable`: scalar reference surface temperature in degrees Celsius.
- `Temperature Anomaly Variable`: scalar monthly temperature anomaly in degrees Celsius.
- `Precipitation Ratio Variable`: non-negative monthly ratio. Monthly precipitation is computed as reference SMB times this ratio divided by 12.
- Forcing fields may be nodal or elemental. When a forcing field and output use different locations, the solver converts it by averaging over the associated nodes or adjacent elements.
- Monthly melt is calculated from positive degree days, using the month length and the configured ice degree-day factor. Annual SMB is accumulated precipitation minus melt and is written at month 12.

The following constants can be set in the SIF `Constants` section:

- `DDF Ice`: ice degree-day factor; default `0.00879` (m water equivalent per degree-day).
- `PDD Melt Temperature`: melt threshold in degrees Celsius; default `0.0`.
- `Temperature Sigma`: temperature variability used to estimate expected positive degree days; default `5.0` degrees Celsius. 
- `GradTemp`: temperature lapse rate used for elevation feedback; default `-0.0065` degrees Celsius per metre.
- `TempCorrec`: optional temperature correction; default `0.0` degrees Celsius.

### Elevation feedback

Set `Elevation Feedback Mode = Logical True` to adjust temperature using the difference between evolving and reference surface elevation. In that case, provide scalar `ZsRef` and `Zs` fields, or set `Reference Elevation Variable` and `Elevation Variable` to their configured names.

### Radiative mode

`Radiative Mode` is retained as a solver setting, but the monthly PDD path currently stops with an error if it is enabled. Leave it `False` for this solver configuration.

## Test case

The example is in `TEST/SMB.sif`. It reads geometry and velocity from a UGRID restart file, prepares the SMB forcing fields, runs the solver monthly, and writes VTU output. Update the file paths and ensure the mesh, restart data, and output directory referenced by the SIF are present in `TEST` before running.

### Video example

The following animation shows the 10-year evolution of the SMB and temperature (red areas have positive temperature and start to melt). The original AVI is retained in `TEST`; the MP4 copy is used here because it is supported by HTML5 video players.

<video controls width="100%">
  <source src="TEST/SMB_elevation_feedback_10years_dummy.mp4" type="video/mp4">
  Your Markdown viewer does not support embedded video. [Open the MP4](TEST/SMB_elevation_feedback_10years_dummy.mp4).
</video>

From the `TEST` directory, build the local solvers and run the SMB case with:

```sh
make compile
make run
```

The build requires the Elmer/Ice compiler wrapper `elmerf90`; running requires `ElmerSolver`. The Makefile also provides `make run_parallel` for a parallel run, with the process count controlled by `n` (default `2`).