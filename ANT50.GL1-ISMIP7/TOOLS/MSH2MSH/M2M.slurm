#!/bin/bash 
#MSUB -r m2m
#MSUB -e m2m.e%j
#MSUB -o m2m.o%j
#MSUB -n 48
#MSUB -x
#MSUB -T 1200
#MSUB -A gen6035
#MSUB -q rome
#MSUB -m store,work,workflash,scratch
#MSUB -E "--parsable"

# here are define option specific to irene
. ~/.bashrc

# change groupe => without this vtu are wrote on ige group => quota exceeded
newgrp gen6035

ulimit -s unlimited

# 
echo ''
echo "run M2M"
echo ''

# manage sif info
echo M2M.sif  > ELMERSOLVER_STARTINFO

# run elmer (see function in param_hpc.bash)
module purge ; module load elmerfem/elmerfem-bfd923fb-opt

ccc_mprun -n 48 ElmerSolver_mpi
