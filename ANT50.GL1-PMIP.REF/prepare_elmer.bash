#!/bin/bash

source config_case.txt
#CONFIG=ANT50.GL1
#CASE=SSP585_IPSL-CM6A-LR_MAR_EXP004

HELMER=`pwd`

# check if error fix or not
if [ -f zELMER_*ERROR* ]; then echo ' ERROR files still there. rm zERROR_*_* files if you fixed it before re-run'; exit 42; fi

# source arch file
. param_arch.bash

# load modules
load_elmer_modules

if [ ! -d WELMER  ]; then mkdir -p  $WELMER   ; fi
if [ ! -d RELMER  ]; then mkdir -p  $RELMER   ; fi
if [ ! -d SELMER  ]; then mkdir -p  $SELMER   ; fi

. run_param.bash

# to fix issue for vtu group gidbit
chgrp -R ${GROUPUSR} ${WELMER}

# set symbolic link
if [ ! -L MY_WORK    ]; then ln -s $WELMER MY_WORK    ; fi
if [ ! -L MY_RESTART ]; then ln -s $RELMER MY_RESTART ; fi
if [ ! -L MY_OUTPUT  ]; then ln -s $SELMER MY_OUTPUT  ; fi

echo ''
echo "Copy executable to $WELMER"
echo "=========================="
echo ''
# to clean this we could find a way to check only what is needed in the sif file
# like this workdir only contains what is needed
\cp MY_BLD/* $WELMER/.

# copy xios
\cp $XIOS_BIN/xios_server.exe $WELMER/.

# build app.conf file
touch app.conf
echo "$NELMER ElmerSolver_mpi" > app.conf
echo "$NXIOS ./xios_server.exe" >> app.conf
mv app.conf $WELMER/.

# copy sif and param
echo ''
echo "Copy incf and param to: $WELMER"
echo "======================="
echo
\cp $CONFIG-${CASE}_elmer.param  $WELMER/elmer.param
\cp $CONFIG-${CASE}_elmer.incf   $WELMER/elmer.incf
\cp iodef_elmer.xml              $WELMER/.
\cp context_elmer.xml            $WELMER/.
\cp iodef_pp.xml                 $WELMER/.
\cp context_pp.xml               $WELMER/.
\cp $CONFIG-${CASE}_pp.sif       $WELMER/pp.sif
\cp -rf FUNCTIONS		 $WELMER/.
\cp -rf FRICTION_PARAM           $WELMER/.

# prepare file_def.xml
sed -e "s/<TIME_RST>/$TIME_RST/g"   ${CONFIG}-${CASE}_file_def.xml > $WELMER/file_def_elmer.xml

# link data
# elmer point directly to the data dir => no need to do anything
# except for the mesh
if [ ! -d $WELMER/MSH/partitioning.$NELMER ] ; then mkdir -p $WELMER/MSH/partitioning.$NELMER ; chmod g+s $WELMER/MSH ; chmod g+s $WELMER/MSH/partitioning.$NELMER ; fi
echo '   - link partionned mesh'
ln -sf $MSHINITpath/partitioning.$NELMER/part.* $WELMER/MSH/partitioning.$NELMER/.
echo '   - link serial mesh'
ln -sf $MSHINITpath/mesh.* $WELMER/MSH/.

echo ''
echo "$(($ENDITER - $STARTITER + 1)) segment to run"
echo '===================='

for ((ijob=$STARTITER ; ijob<=$ENDITER ; ijob++))
do
    im1=`printf %03d $((ijob-1))` ;
    ip1=`printf %03d $((ijob+1))` ;
    i=`printf %03d $((ijob))`     ;

    if [ -f zELMER_${i}_SUCCESSFUL ]; then echo "Run already successful. rm zELMER_${i}_SUCCESSFUL files if you want to overwrite this segment"; exit 42; fi
    
    # name
    NAME=$CONFIG-$CASE

    # get restart
    # no need to do anything, elmer point directly to the directory
    # except for the first one
    if [[ $((ijob-1)) -eq 0 ]]; then
      if [[ $RSTINITfile != NONE ]]; then
         RSTFILEnc=$RSTINITfile
         cp $RSTINITpath/${RSTINITfile} $WELMER/MSH/restart_${im1}.nc
         ncap2 -O -s "elmer_time=elmer_time*0" $WELMER/MSH/restart_${im1}.nc $WELMER/MSH/restart_${im1}.nc  
         #ln -sf $RSTINITpath/${RSTINITfile} $WELMER/MSH/restart_${im1}.nc
      fi
    else
         RSTFILEnc="${NAME}_${im1}.restart.nc"
    fi   
    
    
    echo ''
    echo "start: ${NAME}_elmer_$i from $RSTFILEnc"
    echo '======' 
    echo ''

    # prepare sif
    sed -e "s/<ID-1>/${im1}/g"           \
        -e "s/<ID>/${i}/g"               \
        -e "s/<NSTEPS>/$NSTEP/g"         \
        -e "s/<STPINDAYS>/$TIME_STP/g"   \
        -e "s/<STARTYEAR>/$START_SIMU/g" \
        -e "s/<OFFSET>/$OFFSET/g"        \
        -e "s/<OFFSETOC>/$OFFSETOC/g"        \
        -e "s/<RSTFILEnc>/$RSTFILEnc/g" ${NAME}_elmer.sif  > $WELMER/elmer_t${i}.sif  

    # prepare run script
    sed -e "s!<NAME>!${NAME}_$i!g"       \
        -e "s!<NNODES>!${NN}!g"          \
        -e "s!<GROUPUSR>!${GROUPUSR}!g"  \
        -e "s!<WALLTIME>!${WALLTIME}!g"  \
        -e "s!<NTASKS>!${NP}!g"        run_arch.slurm > run_elmer_${i}.slurm

    sed -e "s!<RSTFILEnc>!$RSTFILEnc!g"  \
        -e "s!<ECONFIG>!$CONFIG!g"       \
        -e "s!<ECASE>!$CASE!g"           \
        -e "s!<HELMER>!$HELMER!g"        \
        -e "s!<ID>!${i}!g"               \
        -e "s!<ID-1>!${im1}!g"           \
        -e "s!<ID+1>!${ip1}!g"         run_elmer_skel.bash >> run_elmer_${i}.slurm

    # manage status file
    if [[ $((ijob)) == 1 ]];then touch ${HELMER}/zELMER_${i}_READY; fi

    # submit job
    if [ ! -z "$jobid0" ];then
        jobid=$(submit_elmer_dependency $jobid0)
        echo "        id        : $jobid"
        echo "        dependency: $jobid0"
    else
        jobid=$(submit_elmer)
        echo "        id        : $jobid"
    fi
    jobid0=$jobid
 
done
echo ''
