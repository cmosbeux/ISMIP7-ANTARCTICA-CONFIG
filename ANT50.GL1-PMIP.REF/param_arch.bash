#!/bin/bash

# group user 
GROUPUSR=gen6066

# define keywords
ELMER_SCRATCHDIR=${CCCSCRATCHDIR}
ELMER_HOMEDIR=${CCCHOME}

# define workdir, restart dir, input dir and output dir
WELMER=${ELMER_SCRATCHDIR}/ELMER/$CONFIG/$CONFIG-$CASE/$CONFIG-${CASE}_WORK
RELMER=${ELMER_SCRATCHDIR}/ELMER/$CONFIG/$CONFIG-$CASE/$CONFIG-${CASE}_R
IELMER=/ccc/work/cont003/gen6066/mosbeuxc/ISMIP7-SIMULATIONS/REF.OUTPUTS
SELMER=${ELMER_SCRATCHDIR}/ELMER/$CONFIG/$CONFIG-$CASE/$CONFIG-${CASE}_S

## function to submit elmer script (output must be job id)
function submit_elmer() {
ztmp=`/usr/bin/newgrp $GROUPUSR <<EONG
    ccc_msub run_elmer_$i.slurm
EONG
`
echo $ztmp | awk '{print $4}'
    }

function submit_elmer_dependency() {
ztmp=`/usr/bin/newgrp $GROUPUSR <<EONG
    ccc_msub -E "--dependency=afterok:$1" run_elmer_$i.slurm
EONG
`
echo $ztmp | awk '{print $4}'
    }

## function to run elmer:
function run_elmer() {
    ccc_mprun -f app.conf
                     }

## function to load modules:
function load_elmer_modules() {
     module purge
     module load elmerfem-29fd3bf4-opt
     module load nco
           }
