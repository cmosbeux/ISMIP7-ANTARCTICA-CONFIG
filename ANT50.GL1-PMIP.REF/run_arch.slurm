#!/bin/bash

# here is defined irene slurm header

######################
## IRENE   TGCC/CEA ##
######################

#MSUB -r <NAME>
#MSUB -e LOG/<NAME>.e%j
#MSUB -o LOG/<NAME>.o%j
#MSUB -n <NTASKS>
#MSUB -x
#MSUB -T <WALLTIME>
#MSUB -A <GROUPUSR>
#MSUB -q rome
#MSUB -m work,workflash,scratch
#MSUB -E "--parsable"

# here are define option specific to irene
. ~/.bashrc

# change groupe => without this vtu are wrote on ige group => quota exceeded
newgrp <GROUPUSR>

# below we instert the generic script to run elmer based on run_elmer_skel.bash
# done in prepare_elmer.bash
