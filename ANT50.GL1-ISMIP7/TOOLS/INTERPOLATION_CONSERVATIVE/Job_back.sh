#!/bin/bash
#MSUB -x
#MSUB -r MC                # Request name
#MSUB -m  scratch,work 
#MSUB -n 1                       # Number of tasks to use
#MSUB -c 32
#MSUB -T 180                   # Elapsed time limit in seconds
#MSUB -o IB_%I.o              # Standard output. %I is the job id
#MSUB -e IB_%I.e              # Error output. %I is the job id
#MSUB -q rome
#MSUB -A gen6066                  # Project ID

set -x

module load cdo
newgrp  gen6066

cd ${BRIDGE_MSUB_PWD}

export OMP_NUM_THREADS=32


## some renaming to be compatible with cdo....
## might be easier to use ESMF or xios foer the interpolation
var_name=asmb
time_axis=time_centered
## extract the asmb and time axis (centered for averaged variables)
ncks -O -C -v $var_name,$time_axis asmb_asmb_1.nc tmp.nc
## rename cell dim
ncrename -d nmesh2D_face,ncells tmp.nc
## change coordinates of var
ncatted -a coordinates,$var_name,o,c,"lon lat" tmp.nc
## copy coordiantes from the grid
ncks -A -v lat,lon,lat_bnds,lon_bnds ant50.gl1-ismip6_grid.nc tmp.nc
## we should also chnage the name of teh time axis to time to be compliant with ismip6?

echo "RENAMING DONE!!"

## conservative weights from elmer ant50.gl1 grid To 4km
cdo genycon,CCSM4_4km_anomaly_1995-2100.nc ant50.gl1-ismip6_grid.nc yCONweights_ant50.gl1_4km.nc

echo "WEIGHTS DONE!!"

## remapping
cdo remap,CCSM4_4km_anomaly_1995-2100.nc,yCONweights_ant50.gl1_4km.nc -selname,asmb tmp.nc CCSM4_anomaly_backTo4km.nc

echo "ALL DONE"
