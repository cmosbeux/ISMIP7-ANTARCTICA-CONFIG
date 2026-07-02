How to rebuild a mesh from a QGIS contour
=========================================

0: Pre-requisite
----------------

Elmer compiled with MMG, conda and QGIS software


1: Convert QGIS contour to an uniform elmer mesh
------------------------------------------------

This is step 1 file: run it offline line by line
```
conda env create -f elmer_msh.yml
conda activate elmer_msh
step_1_Meshini.sh [shp file path]
```
`[shp file path]` being where the QGIS Antarctica contour sits.

You can validate this step by visualizing the contour.vtu file

2: Build refined Elmer grid
---------------------------

This is step 2: need an HPC (it takes a while). This step optimized the msh based on velocity and ice geometry.
These data need to be provide in:
```
data/formeshing.nc
data/formeshing_vel.nc 
```

Step 2 can take a while, so it is recommended to run it as a batch script. To do so, adapt `step_2_optim_mesh.slurm` to your computer and run it.

3: Cut your grid in partition
-----------------------------

The step 3 cut your domain in `n` partition:
```
./step_3_partition.sh [dir: Mesh directory] [n: number of partition]
```
By default if no change in step_2_optim_mesh.sif, the grid are in MSH_output

The output mesh on `n` partitions sits in `[dir: Mesh directory]` as `partition.[n: number of partition]`
