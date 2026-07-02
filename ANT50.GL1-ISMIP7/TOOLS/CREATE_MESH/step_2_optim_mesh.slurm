#!/bin/bash

#MSUB -r MESH_OPTIM
#MSUB -e MESH_OPTIM.e%j
#MSUB -o MESH_OPTIM.o%j
#MSUB -n 24
#MSUB -T 28800
#MSUB -A gen6035
#MSUB -q rome
#MSUB -m store,work,workflash,scratch
#MSUB -E "--parsable"

# here are define option specific to irene
. ~/.bashrc

# change groupe => without this vtu are wrote on ige group => quota exceeded
newgrp gen6035

ulimit -s unlimited

echo MESH_OPTIM_Antarctica.sif > ELMERSOLVER_STARTINFO

module purge
module load elmerfem/elmerfem-bfd923fb-opt
module load mmg

ccc_mprun -n 1 ElmerSolver 
