# SSA calving tests

This directory contains a small Elmer/Ice SSA ice-shelf test case for experimenting with calving-front retreat and readvance.

## Calving routine

`MY_SRC/SSACalving.F90` identifies thin floating elements connected to the ice front and updates the element variable `CalvingMask`:

- `-1`: grounded element
- `0`: intact floating element
- `1`: calved element

The `passive` mode marks calved elements for passive thickness/velocity conditions. It supports an active front buffer (`Calving Buffer Layers`) and readvance when neighboring active ice reaches `Recovery Thickness`.

The `minimum` mode sets the nodal thickness of calved elements to a minimum value. The front-thickness test uses the maximum nodal thickness by default. `Mean Front Thickness = Logical True` selects the nodal mean instead; this can trigger early retreat when an element includes both thick active nodes and nodes at the minimum thickness.

## Case files

- `Case_passive.sif`: passive calving, with a two-layer active buffer and recovery threshold H_recovery = H_critical * 1.1
- `Case_minimum.sif`: minimum-thickness calving, with the same critical and recovery thresholds. It does not use the passive buffer.
- `PARAMETERS.sif`: shared physical and ramp parameters.

The cases use the mesh database `rectangle_2000` and write transient VTU output for viewing in ParaView.


## Build and run

Run commands from this directory. You need Gmsh, ElmerGrid, `elmerf90`, `ElmerSolver`, and (for the parallel target) MPI available in your environment.

1. Generate and partition the mesh:

   ```sh
   bash MakeMesh.sh
   ```

   The script creates the `rectangle_2000` Elmer mesh and partitions it for two MPI ranks.

2. Compile the custom solvers:

   ```sh
   make compile
   ```

3. Run a case:

   Serial with minimum thickness
   ```sh
   make run_minimum
   ```

   Serial with passive/active element shifts
   ```sh
   make run_minimum
   ```

  For now, the passive/active mode does not work in parallel. You can only run the minimum mode with
   ```sh
   make run_minimum_par
   ```

The run targets launch `ElmerSolver` with the corresponding SIF file. Results are written according to the output settings in the case file.

> [!WARNING]
> ### 🧊 Calving-thickness threshold
> This test case uses **$H_{critical} = 40\,\mathrm{m}$**. For Antarctica, a more representative value may be around **150–250 m**.
>
> 🟠 **A smaller threshold is more conservative** and can cause calving to begin at thinner ice.