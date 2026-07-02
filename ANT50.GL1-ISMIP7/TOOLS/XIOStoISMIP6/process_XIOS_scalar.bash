#!/bin/bash

if [[ $# != 2 ]]; then echo "Usage process_XIOS_output [AIS or GIS] [EXP]"; exit 42; fi

EXPLST=${@:2}
ISNAME=$1

TMPDIR=$CCCSCRATCHDIR/TMPDIR_XIOStoELMER/
DATAOUT=$CCCSCRATCHDIR/TMPDIR_XIOStoELMER/DATA_ISMIP6

nerr=0

# load module (nco and cdo)
echo ""
echo "Load modules"
module purge
module load intel || exit 42
module load hdf5  || exit 42
module load cdo   || exit 42
module load nco   || exit 42
echo "   DONE"

# link grid file in TMP
echo ""
echo "link ${GRIDIN} and ${GRIDOUT}"
DIR=`pwd`
if [ ! -d $TMPDIR  ]; then mkdir -p $TMPDIR; fi ; ln -sf $TMPDIR TMPDIR;
if [ ! -d $DATAOUT ]; then mkdir -p $DATAOUT; fi ; ln -sf $DATAOUT DATA_ISMIP6

if [[ $nerr != 0 ]]; then
   echo 'E R R O R during linking stage; exit 42'
   exit 42
else
   echo "   DONE"
fi

# compute final output file
#    - concatenation exp by exp
#    - remapping var by var
#    - fix att, name ... issues

for EXP in $EXPLST; do
   echo ""
   echo "Convert XIOS output in $EXP to ISMIP6 compliant output ..."

   if [ ! -d LOG_$EXP ]; then mkdir LOG_$EXP; fi
   # work file by file : 
   # concatanate all the files for scalar, fluxes and states
   nerr=0
   cexp=`echo "$EXP" | tr '[:upper:]' '[:lower:]'` || nerr=$((nerr+1))
   if [ -f TMPDIR/ismip6_scalar_${cexp}.nc ]; then rm TMPDIR/ismip6_scalar_${cexp}.nc ; fi
   ncrcat -O DATA_XIOS/$EXP/ismip6_scalar_${cexp}_???.nc TMPDIR/ismip6_scalar_${cexp}.nc || nerr=$((nerr+1)) &

   if [ -f TMPDIR/ismip6_scalar_${cexp}.nc ]; then rm TMPDIR/ismip6_scalar_${cexp}.nc ; fi
   ncrcat -O DATA_XIOS/$EXP/ismip6_scalar_${cexp}_???.nc TMPDIR/ismip6_scalar_${cexp}.nc || nerr=$((nerr+1)) &
   wait

   if [[ $nerr != 0 ]]; then
      echo 'E R R O R during concatenation stage; exit 42'
      exit 42
   fi

   # run conservative interpolation variable by variable
   FILE=ismip6_scalar_${cexp}.nc
   for VAR in lim limnsw iareagr iareafl tendacabf tendlibmassbf tendlibmassbffl tendlifmassbf tendligroundf ;  do
      echo ""
      echo "Extract $VAR ..."
      echo ""
      time ncks -v $VAR $FILE ${VAR}_${ISNAME}_IGE_ElmerIce_${EXP}.nc || nerr=$((nerr+1))
   done

   wait

   if [[ $nerr != 0 ]]; then
      echo 'E R R O R during extraction stage (scalar variables); exit 42'
      exit 42
   fi

   FILE=ismip6_scalar_true_cell_area_${cexp}.nc
   for VAR in lim_tca limnsw_tca iareagr_tca iareafl_tca tendacabf_tca tendlibmassbf_tca tendlibmassbffl_tca tendlifmassbf_tca tendligroundf_tca ;  do
      echo ""
      echo "Extract $VAR ..."
      echo ""
      time ncks -v $VAR $FILE ${VAR}_${ISNAME}_IGE_ElmerIce_${EXP}.nc || nerr=$((nerr+1))
   done

   wait

   if [[ $nerr != 0 ]]; then
      echo 'E R R O R during extraction stage (scalar_true_cell_area variables); exit 42'
      exit 42
   fi

   echo ""
   echo "   $EXP DONE"
   echo ""
done
