#!/bin/bash
######################
## IRENE   TGCC/CEA ##
######################
#MSUB -r interp
#MSUB -o res.o%j
#MSUB -e res.e%j
#MSUB -n 1 
#MSUB -x (eq -exclusive, remove it for share queue)
#MSUB -T 6000 (walltime in second)
#MSUB -A gen6066 (gen6035 for us)
#MSUB -q rome (partition name, rome for us)
#MSUB -m work,scratch (spaces accessible from the compute node)

set -x

module load cdo
newgrp  gen6066

cd ${BRIDGE_MSUB_PWD}

export OMP_NUM_THREADS=32

## asmb unit conversion and remaping
#aSMB [m yr-1] = aSMB [kg m-2 s-1] * 31556926 / 1000 * (1000/ρi), 
yearinsec=31536000.0
rhoi=917.0

## data
grid_Elmer_file="NC/ant50.gl1-ismip6_grid.nc" 
weights_file="NC/yCONweights_4km_ant50.gl1.nc"
initial_SMB_file="/ccc/work/cont003/gen6066/gen6066/ISMIP6/ISMIP6_ANT/FORCING/ATMOSPHERE/ANOMALY/CCSM4/CCSM4_4km_anomaly_1995-2300.nc"
final_SMB_file="/ccc/work/cont003/gen6066/gen6066/ISMIP6/ISMIP6_ANT/FORCING/ATMOSPHERE/ANOMALY/CCSM4/CCSM4_ant50.gl1_anomaly_1995-2300.nc"
#smb = "smb_anomaly"

cdo remap,$grid_Elmer_file,$weights_file -selname,asmb -expr,"asmb=smb_anomaly*$yearinsec/$rhoi" $initial_SMB_file  $final_SMB_file
#cdo remap,ant50.gl1-ismip6_grid.nc,yCONweights_4km_ant50.gl1.nc -selname,asmb -expr,"asmb=smb_anomaly*$yearinsec/$rhoi" CESM2-WACCM_4km_anomaly_ssp585_1995-2299.nc  CESM2-WACCM_ant50.gl1_anomaly_ssp585_1995-2299.nc

ierr=$?
if [[ $ierr != 0 ]]; then 
   echo ' E R R O R ' 
   if [ $final_SMB_file ]; then
     rm -f $final_SMB_file
   fi
   exit 42
else
  echo ' SUCCESSFULL'
fi
