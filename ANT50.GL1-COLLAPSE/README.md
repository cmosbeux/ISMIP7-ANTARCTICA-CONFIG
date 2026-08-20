# Collapse mechanism for ISMIP7 Antarctica

Authors: Cyrille Mosbeux and Fabien Gillet-Chaulet

Participation in ISMIP7 requires implementing collapse mechanisms based either on a physical dependence on water content and/or stress, or on a predefined mask of regions prone to collapse established by the ISMIP7 team.

This development focuses on the numerical implementation of the second, simpler approach. It can be adapted to include other physical constraints if needed.

## Source code

The Fortran source files are available in the `MY_SRC` directory. Example test configuration files are provided in the `TEST` directory.

## Solver usage

The solver can be called from an Elmer input file as follows:

```fortran
Solver 3
  Exec Solver = Before Timestep
  Equation = "CollapseAreas"
  Variable = -dofs 1 dummy
  Procedure = "CollapseAreas_Parallel" "CollapseAreas_Parallel"

  Optimize Bandwidth = False

  Fracture Variable = String "fracture_mask"

  Collapse Ratio = Real 0.6
  Shelf Lower Limit for Collapse = Real 2e7

  File Name = File "output_collapse.txt"
End
```

## Main features

- `Fracture Variable`: name of the mask used to identify fracture-prone regions. This mask may be read from a file or computed by another solver based on physical constraints.
- `Collapse Ratio`: threshold at which a shelf collapses in the simulation, based on the ratio `Prone to Fracture Area / Shelf Area`.
- `Shelf Lower Limit for Collapse`: minimum shelf size considered for collapse. This keyword helps avoid collapsing small floating areas upstream of the main grounding line.

## Test case

A test case can be run over Antarctica. It requires a restart file containing the information necessary to reconstruct the mesh and the geometry of the ice sheet, including the detection of floating shelves.