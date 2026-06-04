#!/bin/bash

# here is defined irene slurm header

######################
## IRENE   TGCC/CEA ##
######################

#MSUB -r rslt2nc
#MSUB -e rslt2nc.e%j
#MSUB -o rslt2nc.o%j
#MSUB -n 49
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

# below we instert the generic script to run elmer based on run_elmer_skel.bash
# done in prepare_elmer.bash
#!/bin/bash
ulimit -s unlimited

# 
echo ''
echo "run Elmer/Ice in $WELMER"
echo ''

# manage sif info
echo result2nc.sif > ELMERSOLVER_STARTINFO

# run elmer (see function in param_hpc.bash)
module purge ; module load elmerfem/elmerfem-bfd923fb-opt

ccc_mprun -f app.conf
