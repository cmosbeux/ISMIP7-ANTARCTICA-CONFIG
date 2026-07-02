#!/bin/bash

# group user 
GROUPUSR=gen6035

# define keywords
ELMER_SCRATCHDIR=${CCCSCRATCHDIR}
ELMER_WORKDIR=${GEN6035_ALL_CCCWORKDIR}
ELMER_HOMEDIR=${CCCHOME}

# define workdir, restart dir, input dir and output dir
WELMER=${ELMER_SCRATCHDIR}/ELMER/$CONFIG/$CONFIG-$CASE/$CONFIG-${CASE}_WORK
RELMER=${ELMER_SCRATCHDIR}/ELMER/$CONFIG/$CONFIG-$CASE/$CONFIG-${CASE}_R
#IELMER=${ELMER_SCRATCHDIR}/ELMER/$CONFIG/$CONFIG-I
IELMER=/ccc/work/cont003/gen6066/gen6066/ISMIP6/ISMIP6_ANT/
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
#     module load c/intel/19.0.5.281 c++/intel/19.0.5.281 fortran/intel/19.0.5.281 intel/19.0.5.281 mpi/openmpi/4.0.2
#     module load flavor/buildcompiler/intel/19 flavor/buildmpi/openmpi/4.0 flavor/hdf5/parallel
#     module load netcdf-c/4.6.0 netcdf-fortran/4.4.4
#     module load cmake/3.16.5
#     module load ELMER/Elmer_v9.0_r21ddff3a
     module load  elmerfem/elmerfem-bfd923fb-opt
     module load  nco

     # add check on elmerf90 et elmersolver_mpi here

           }
