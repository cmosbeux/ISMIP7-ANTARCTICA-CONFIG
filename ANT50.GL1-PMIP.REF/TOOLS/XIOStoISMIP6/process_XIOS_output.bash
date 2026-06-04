#!/bin/bash

if [[ $# != 4 ]]; then echo "Usage process_XIOS_output [GRID IN (ant50.gl1-ismip6)] [GRID OUT ()] [AIS or GIS] [EXP]"; exit 42; fi

EXPLST=${@:4}
GRIDIN=$1
GRIDOUT=$2
ISNAME=$3

GRIDINfile=${GRIDIN}_grid.nc
GRIDOUTfile=${GRIDOUT}_grid.nc

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
if [ ! -f GRID_XIOS/${GRIDINfile}  ]; then echo "E R R O R: $GRIDINfile  is missing"; exit 42; fi
if [ ! -f GRID_ISMIP6/$GRIDOUTfile ]; then echo "E R R O R: $GRIDOUTfile is missing"; exit 42; fi
ln -sf $DIR/GRID_XIOS/${GRIDINfile} $TMPDIR/.   || nerr=$((nerr+1))
ln -sf $DIR/GRID_ISMIP6/$GRIDOUTfile $TMPDIR/.  || nerr=$((nerr+1))

if [[ $nerr != 0 ]]; then
   echo 'E R R O R during linking stage; exit 42'
   exit 42
else
   echo "   DONE"
fi

# Compute weights
cd TMPDIR
echo ""
echo "Compute weights for remapping from ${GRIDIN} to ${GRIDOUT}"
echo '    destarea normalization weights'
export CDO_REMAP_NORM='destarea'
WEIGHTS_destarea=ycon_weights_${GRIDIN}_to_${GRIDOUT}_destarea.nc
cdo genycon,$GRIDOUTfile $GRIDINfile $WEIGHTS_destarea || exit 42

echo '    fracarea normalization weights'
export CDO_REMAP_NORM='fracarea'
WEIGHTS_fracarea=ycon_weights_${GRIDIN}_to_${GRIDOUT}_fracarea.nc
cdo genycon,$GRIDOUTfile $GRIDINfile $WEIGHTS_fracarea || exit 42

if [[ $nerr != 0 ]]; then
   echo 'E R R O R during weight computation stage; exit 42'
   exit 42
else
   echo "   DONE"
fi

cd ..

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
   if [ -f TMPDIR/ismip6_fluxes_${cexp}.nc ]; then rm TMPDIR/ismip6_fluxes_${cexp}.nc ; fi
   ncrcat -O DATA_XIOS/$EXP/ismip6_fluxes_${cexp}_???.nc TMPDIR/ismip6_fluxes_${cexp}.nc || nerr=$((nerr+1)) &

   if [ -f TMPDIR/ismip6_states_${cexp}.nc ]; then rm TMPDIR/ismip6_states_${cexp}.nc ; fi
   ncrcat -O DATA_XIOS/$EXP/ismip6_states_${cexp}_???.nc TMPDIR/ismip6_states_${cexp}.nc || nerr=$((nerr+1)) &
   wait

   if [[ $nerr != 0 ]]; then
      echo 'E R R O R during concatenation stage; exit 42'
      exit 42
   fi

   # run conservative interpolation variable by variable
   FILE=ismip6_states_${cexp}.nc
   for VAR in lithk orog base topg xvelmean yvelmean strbasemag lithkaf velmean; do
      echo ""
      echo "Interpolate $VAR ..."
      echo ""
      time ./compute_interpolation.bash $VAR $FILE $GRIDINfile $GRIDOUTfile $WEIGHTS_fracarea ${ISNAME} ${EXP} > LOG_$EXP/log_${VAR}_${ISNAME}_${EXP} || nerr=$((nerr+1))
   done

   wait

   if [[ $nerr != 0 ]]; then
      echo 'E R R O R during interpolation stage (state variables); exit 42'
      exit 42
   fi

   FILE=ismip6_fluxes_${cexp}.nc
   for VAR in acabf libmassbfgr libmassbffl dlithkdt lifmassbf ligroundf ; do
      echo ""
      echo "Interpolate $VAR ..."
      echo ""
      time ./compute_interpolation.bash $VAR $FILE $GRIDINfile $GRIDOUTfile $WEIGHTS_fracarea ${ISNAME} ${EXP} > LOG_$EXP/log_${VAR}_${EXP} || nerr=$((nerr+1)) &
   done

   # ice fraction need to be normalized with destarea to represent the effective ice fraction in the output grid (ie to take into accound different coastline in src and targ grid)
   FILE=ismip6_states_${cexp}.nc
   for VAR in sftgif sftgrf sftflf ; do
      echo ""
      echo "Interpolate $VAR ..."
      echo ""
      time ./compute_interpolation.bash $VAR $FILE $GRIDINfile $GRIDOUTfile $WEIGHTS_destarea ${ISNAME} ${EXP} > LOG_$EXP/log_${VAR}_${EXP} || nerr=$((nerr+1)) &
   done

   wait

   if [[ $nerr != 0 ]]; then
      echo 'E R R O R during interpolation stage (flux variables); exit 42'
      exit 42
   fi


   echo ""
   echo "   $EXP DONE"
   echo ""
done


#ENVIRONMENT
#    CDO_REMAP_NORM
#        This variable is used to choose the normalization of the conservative interpolation. 
#        By default CDO_REMAP_NORM is set to 'fracarea'. 'fracarea' uses the sum of the
#        non-masked source cell intersected areas to normalize each target cell field value.
#        This results in a reasonable flux value but the flux is not locally conserved.
#        The option 'destarea' uses the total target cell area to normalize each target cell
#        field value. Local flux conservation is ensured, but unreasonable flux values may result.
#    REMAP_AREA_MIN
#        This variable is used to set the minimum destination area fraction. The default
#        of this variable is 0.0.

