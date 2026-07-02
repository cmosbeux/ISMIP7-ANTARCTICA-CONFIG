#!/bin/bash
ulimit -s unlimited

function mv_data_to_s() {
   NCFILE=`echo "$1" | tr [:upper:] [:lower:]`
   # check file is present
   if [ ! -f $NCFILE ]; then 
      echo "$NCFILE missing; E R R O R"; nerr=$((nerr+1))
   else
      # check file is a netcdf
      cnc=$(ncdump -h $NCFILE 2> /dev/null | grep UNLIM )
      if [[ $? != 0 ]] ; then
        printf " E R R O R : %-50s is not a valid netcdf \n" $NCFILE
        nerr=$((nerr+1))
      else
        # all seem good, we move the file
        mv $NCFILE  $SELMER/.  || nerr=$((nerr+1))
      fi
   fi
                        }

HELMER=<HELMER>

# INPUTS
# segment number
i=<ID>
im1=<ID-1>
ip1=<ID+1>

# restart name
RSTFILEnc=<RSTFILEnc>
# conf case
CONFIG=<ECONFIG>
CASE=<ECASE>

# LOG links
ln -sf LOG/${CONFIG}-${CASE}_${i}.e$SLURM_JOBID elmer.err
ln -sf LOG/${CONFIG}-${CASE}_${i}.o$SLURM_JOBID elmer.out

# load arch parameter
. ./param_arch.bash

# load modules
load_elmer_modules

# print status file
mv ${HELMER}/zELMER_${i}_READY ${HELMER}/zELMER_${i}_IN_PROGRESS

# 
echo ''
echo "run Elmer/Ice in $WELMER"
echo ''
cd $WELMER

# manage sif info
echo "sif use is : elmer_t${i}.sif"
if [ ! -f elmer_t${i}.sif ] ; then echo "E R R O R: sif file missing"; exit 42; fi
echo elmer_t${i}.sif > ELMERSOLVER_STARTINFO

# manage restart
if [[ $((10#$i)) -gt 1 ]] ; then
   echo '$WELMER/${RSTFILEnc} is missing, we pick it up from $RELMER'
   ln -sf $RELMER/${RSTFILEnc} $WELMER/MSH/restart_${im1}.nc || nerr=$((nerr+1))

   if [[ $nerr -ne 0 ]] ; then
   echo 'ERROR during copying restart file; please check'
   mv ${HELMER}/zELMER_${i}_IN_PROGRESS ${HELMER}/zELMER_${i}_ERROR_rst
   exit 42
   fi
fi

# XIOS link
ln -sf iodef_elmer.xml iodef.xml

# run elmer (see function in param_hpc.bash)
run_elmer ; RUNSTATUS=$?

# post processing
if [[ $RUNSTATUS == 0 ]]; then
   
   # error count
   nerr=0

   # remove unconnected floating part
   echo "Remove isolated icy cells"
   RSTFILES=`echo "restart_$CONFIG-${CASE}_${i}.nc" | tr [:upper:] [:lower:]`
   cp -f $RSTFILES restart.nc
   ln -sf iodef_pp.xml iodef.xml
   ElmerSolver pp.sif   ||  nerr=$((nerr+1))
   if [[ $nerr -ne 0 ]] ; then echo 'E R R O R : pp failed (removing icebergs)'; exit 42 ; fi
   # process restart (add elmer_time)
   ncks -A -v 'beta_*' $RSTFILES restart_pp.nc
   mv -f restart_pp.nc $RSTFILES ; rm restart.nc

   # cp restart to RST dir
   echo "cp restart to $RELMER"
   RSTTIMEFILES=`echo "restart_time_$CONFIG-${CASE}_${i}.nc" | tr [:upper:] [:lower:]`
   RSTFILES=`echo "restart_$CONFIG-${CASE}_${i}.nc" | tr [:upper:] [:lower:]`
   ncks -A -v elmer_time $RSTTIMEFILES $RSTFILES             || nerr=$((nerr+1))
   mv -f $RSTFILES $RELMER/$CONFIG-${CASE}_${i}.restart.nc   || nerr=$((nerr+1))

   # mv data to S dir
   echo ''
   echo "mv ismip6 output to $SELMER"
   # fluxes
   NCFILES=`echo "ismip6_fluxes_$CONFIG-${CASE}_${i}.nc" | tr [:upper:] [:lower:]`
   mv_data_to_s $NCFILES

   # states
   NCFILES=`echo "ismip6_states_$CONFIG-${CASE}_${i}.nc" | tr [:upper:] [:lower:]`
   mv_data_to_s $NCFILES

   # scalar
   NCFILES=`echo "ismip6_scalars_$CONFIG-${CASE}_${i}.nc" | tr [:upper:] [:lower:]`
   mv_data_to_s $NCFILES
   NCFILES=`echo "ismip6_scalars_true_cell_area_$CONFIG-${CASE}_${i}.nc" | tr [:upper:] [:lower:]`
   mv_data_to_s $NCFILES

   # elmer debug
   NCFILES=`echo "elmer_debug_$CONFIG-${CASE}_${i}.nc" | tr [:upper:] [:lower:]`
   # add output in debug file
   ncks -A --no_crd -v 'region*' output_pp.nc $NCFILES
   mv_data_to_s $NCFILES

   # elmer scalars
   NCFILES=`echo "elmer_scalars_$CONFIG-${CASE}_${i}.nc" | tr [:upper:] [:lower:]`
   mv_data_to_s $NCFILES

   if [[ $nerr -ne 0 ]] ; then
      echo 'ERROR during copying output file/restarts; please check'
      mv ${HELMER}/zELMER_${i}_IN_PROGRESS ${HELMER}/zELMER_${i}_ERROR_pp
      exit 42
   fi

else

   echo 'ELMER failed, exit 42'
   mv ${HELMER}/zELMER_${i}_IN_PROGRESS ${HELMER}/zELMER_${i}_ERROR
   exit 42

fi

# manage indicator file
mv ${HELMER}/zELMER_${i}_IN_PROGRESS ${HELMER}/zELMER_${i}_SUCCESSFUL
touch ${HELMER}/zELMER_${ip1}_READY
