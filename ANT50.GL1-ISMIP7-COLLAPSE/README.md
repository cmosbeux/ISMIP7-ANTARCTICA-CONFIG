# ISMIP7 Antarctica collapse configuration

This directory is the Elmer/Ice configuration template for the ANT50.GL1
ISMIP7 runs with the shelf-collapse treatment. The case builder creates a
separate run directory for each scenario/GCM/experiment; it fills in the
forcing periods, restart, friction, and ocean parameters there.


## Configuration options

The interactive case builder asks for:

- Scenario, GCM, experiment, and simulation years.
- Friction law: `weertman1`, `weertman3`, or `coulomb_reg`. The default
  coefficient is respectively `beta_1`, `beta_3`, or `beta_cr`; a different
  coefficient variable can be selected.
- Initial restart file. Historical/OCX and future scenarios use different
  expected restart names; make sure the selected file is available.
- Ocean parameterization. PICO is the configured option, with adjustable
  overturning and heat-flux values.


Atmospheric, ocean, and collapse forcing periods are recorded separately.
The builder prepares 1 segment for HISTORICAL/OCX, 5 for SSP370, and 19 for
other scenarios; each segment advances 15 years.

All the required information for parameterization should be present in the 
restart/initial ugrid netcdf and in forcing files.

## Black-box run

Run the builder from the repository root on the supported TGCC environment:

```bash
bash ./clone_ISMIP7.sh
```

Answer the prompts. The script clones this template, reads
`CONFIG_CASES/config_case_exp<EXP>.<FINAL_YEAR>`, writes the chosen values to
`config_case.txt`, and runs `prepare_files.bash` to rename and configure the
case files and build the Fortran sources. At the final prompt, answer `y` to
run `prepare_elmer.bash` and submit the generated jobs, or `n` to stop after
preparing the case.

The run scripts target the TGCC/IRENE batch system (`ccc_msub`) and expect the
Elmer/Ice and XIOS modules, forcing data, initial restart, and mesh to be
available at the paths configured in `param_arch.bash` and 
`ANT50.GL1-SSPXXX_GCM_EXPXXX_elmer.incf`. They are not a standalone local run command. 
Review those paths and the selected case inputs before submitting a production run.

## SIF configuration

`ANT50.GL1-SSPXXX_GCM_EXPXXX_elmer.sif` is the Elmer solver setup template.
`prepare_files.bash` substitutes the friction law and restart coefficient,
while `prepare_elmer.bash` fills in per-segment values such as timestep
count, segment ID, and restart ID before each job.

The SIF includes `elmer.param` for physical/model constants and
`elmer.incf` for case-specific forcing-file names. Its main controls are:

- **Time stepping:** transient BDF integration; the run script sets a segment
  to 1,095 5-day steps (15 years) and writes output annually.
- **Initial state and friction:** the restart reader loads geometry, masks,
  velocity, and the selected beta/friction coefficient. The material block includes
  the chosen law from `FRICTION_PARAM/friction_law.*`.
- **Surface and ocean forcing:** SMB reference/anomaly readers provide
  surface accumulation, and the MELT/PICO setup provides basal melt.
- **Collapse treatment:** the fracture-mask reader and `CollapseAreas`
  solver are enabled. The solver runs yearly with a collapse ratio of `0.6`,
  shelf-area lower limit of `2e7`, and thickness factor of `0.8`; these
  settings can be adjusted in the SIF.
- **Ice dynamics:** SSA, thickness, flotation.
- **Outputs:** XIOS outputs are controlled in the last solver which outputs 2D and 1D 
  data each year

To change model behavior, edit the SIF template or the associated parameters
and include files, then create a fresh case with the builder. 
