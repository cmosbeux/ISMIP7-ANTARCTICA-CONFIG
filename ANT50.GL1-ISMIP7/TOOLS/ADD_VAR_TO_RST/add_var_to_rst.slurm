#!/bin/bash

# here is defined irene slurm header

######################
## IRENE   TGCC/CEA ##
######################

#MSUB -r add_var_to_rst
#MSUB -e add_var_to_rst.e%j
#MSUB -o add_var_to_rst.o%j
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

ulimit -s unlimit

# source arch file
. param_arch.bash
. run_param.bash

load_elmer_modules

# create workdir
if [ ! -d $CCCWORKDIR/ELMER/TMPDIR/ADD_VAR_TO_RST ]; then mkdir $CCCWORKDIR/ELMER/TMPDIR/ADD_VAR_TO_RST ; fi
ln -sf $CCCWORKDIR/ELMER/TMPDIR/ADD_VAR_TO_RST MY_WORK

# copy data to workdir
\cp add_var_to_rst.sif    MY_WORK/.
\cp add_var_to_rst.incf   MY_WORK/.
\cp add_var_to_rst.param  MY_WORK/.
\cp add_var_to_rst.lsol   MY_WORK/.
\cp *xml                  MY_WORK/.

# link data
if [ ! -d MY_WORK/MSH/partitioning.$NELMER ] ; then
   mkdir -p MY_WORK/MSH/partitioning.$NELMER
   chmod g+s MY_WORK/MSH
   chmod g+s MY_WORK/MSH/partitioning.$NELMER
fi
ln -sf $MSHINITpath/partitioning.$NELMER/part.* $CCCWORKDIR/ELMER/TMPDIR/ADD_VAR_TO_RST/MSH/partitioning.$NELMER/.

# copy xios
\cp $XIOS_BIN/xios_server.exe MY_WORK/.

# source
\cp nearestpoint MY_WORK/.
\cp USF_SSAViscosity MY_WORK/.
\cp SSASolver_bugfix MY_WORK/.

cd MY_WORK/.

# build app.conf file
if [ -f app.conf ]; then rm -f app.conf ; fi
touch app.conf
echo "$NELMER ElmerSolver_mpi" >> app.conf
echo "$NXIOS ./xios_server.exe" >> app.conf

echo add_var_to_rst.sif > ELMERSOLVER_STARTINFO

# run elmer
run_elmer ; RUNSTATUS=$?

ncks -A -v elmer_time elmer_scalars.nc restart_newmesh.nc
ncap2 -O -s 'elmer_time=elmer_time*0.0' restart_newmesh.nc restart_newmesh_t0.nc
