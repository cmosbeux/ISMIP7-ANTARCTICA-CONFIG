#!/bin/bash
#MSUB -x
#MSUB -r MC                # Request name
#MSUB -m  scratch,workflash 
#MSUB -n 1                       # Number of tasks to use
#MSUB -c 32
#MSUB -T 180                   # Elapsed time limit in seconds
#MSUB -o IB_%I.o              # Standard output. %I is the job id
#MSUB -e IB_%I.e              # Error output. %I is the job id
#MSUB -q rome
#MSUB -A gen6035                  # Project ID

# input management
if [[ $# != 7 ]]; then echo "Usage ./compute_interpolation.bash [input variable name] [input file name] [src grid file name] [target grid file name] [weights file name] [ice sheet name (AIS/GIS)] [Experience name (hist, ...)] ]; exit 42"; exit 42; fi

nerr=0

VAR=$1
FILEIN=$2
GRIDIN=$3
GRIDOUT=$4
WEIGHTS=$5
ISNAME=$6
EXP=$7

FILEOUT=${VAR}_${ISNAME}_IGE_ElmerIce_${EXP}.nc

time_axis=time_centered

module purge
module load hdf5/1.8.20 netcdf-fortran/4.4.4 || exit 42
module load cdo || exit 42
module load nco || exit 42

cd TMPDIR

# check presence of input file
if [ ! -f $FILEIN  ]; then echo "E R R O R: $FILEIN  missing; exit 42"; nerr=$((nerr+1)); fi
if [ ! -f $GRIDIN  ]; then echo "E R R O R: $GRIDIN  missing; exit 42"; nerr=$((nerr+1)); fi
if [ ! -f $GRIDOUT ]; then echo "E R R O R: $GRIDOUT missing; exit 42"; nerr=$((nerr+1)); fi

echo ""
if [[ $nerr != 0 ]]; then echo "$nerr detected; exit 42"; exit 42; fi

echo "REMAP $VAR from $FILEIN on $GRIDIN toward $GRIDOUT grid"

# time variable
time_axis=`ncdump -h $FILEIN | grep -P "\t$VAR:coordinates" | egrep -o '(time)\w+'`

## some renaming to be compatible with cdo....
## might be easier to use ESMF or xios foer the interpolation
## extract the asmb and time axis (centered for averaged variables)
TMPf=tmp_${VAR}.nc
ncks -O -C -v $VAR,$time_axis,${time_axis}_bounds $FILEIN $TMPf || exit 42
## rename cell dim
ncrename -d nmesh2D_face,ncells $TMPf || exit 42
## change coordinates of var
ncatted -a coordinates,$VAR,o,c,"lon lat" $TMPf || exit 42
## copy coordiantes from the grid
ncks -A -v lat,lon,lat_bnds,lon_bnds $GRIDIN $TMPf || exit 42
## we should also chnage the name of teh time axis to time to be compliant with ismip6?

echo "   RENAMING DONE!!"

## remapping
TMPf1=tmpout_${VAR}.nc
cdo remap,$GRIDOUT,$WEIGHTS -selname,$VAR $TMPf $TMPf1 || exit 42

echo "   REMAPING DONE!!"

# fix att, name ...
ncrename -d nv4,nv -d $time_axis,time -v $time_axis,time $TMPf1 || exit 42
ncks -A -v mapping $GRIDOUT $TMPf1                  || exit 42
ncatted -a 'grid_mapping',$VAR,c,c,'mapping' $TMPf1 || exit 42
ncatted -a 'mesh',$VAR,d,,                   $TMPf1 || exit 42
ncatted -a 'location',$VAR,d,,               $TMPf1 || exit 42

TMPf2=tmpout_${VAR}_spval.nc
cdo setmissval,-1e20 $TMPf1 $TMPf2                 || exit 42
ncatted -a 'missing_value',$VAR,d,,         $TMPf2 || exit 42
ncks -O --dfl_lvl 1 --cnk_dmn x,200 --cnk_dmn y,200 --cnk_dmn time,1 $TMPf2 DATA_ISMIP6/$FILEOUT || exit 42

ncatted -a uuid,global,d,, DATA_ISMIP6/$FILEOUT 
ncatted -a timeStamp,global,d,, DATA_ISMIP6/$FILEOUT 
ncatted -a Conventions,global,d,, DATA_ISMIP6/$FILEOUT 
ncatted -a title,global,d,, DATA_ISMIP6/$FILEOUT
ncatted -a description,global,d,, DATA_ISMIP6/$FILEOUT
ncatted -a name,global,d,, DATA_ISMIP6/$FILEOUT

ncatted -a title,global,a,c,"ISMIP6 simulation (extention to 2300): variable $VAR for experiment $EXP" DATA_ISMIP6/$FILEOUT
ncatted -a url,global,a,c,"https://www.climate-cryosphere.org/wiki/index.php?title=ISMIP6-Projections-Antarctica" DATA_ISMIP6/$FILEOUT 
ncatted -a experiment,global,a,c,'hist' DATA_ISMIP6/$FILEOUT 
ncatted -a institution,global,a,c,"Institut des Géosciences de l'Environnement, CNRS, Grenoble, France" DATA_ISMIP6/$FILEOUT 
ncatted -a contacts,global,a,c,"J. Caillet, P. Mathiot and F. Gillet-Chaulet" DATA_ISMIP6/$FILEOUT 
ncatted -a reference,global,a,c,"Nowicki, S., Goelzer, H., Seroussi, H., Payne, A. J., Lipscomb, W. H., Abe-Ouchi, A., Agosta, C., Alexander, P., Asay-Davis, X. S., Barthel, A., Bracegirdle, T. J., Cullather, R., Felikson, D., Fettweis, X., Gregory, J. M., Hattermann, T., Jourdain, N. C., Kuipers Munneke, P., Larour, E., Little, C. M., Morlighem, M., Nias, I., Shepherd, A., Simon, E., Slater, D., Smith, R. S., Straneo, F., Trusel, L. D., van den Broeke, M. R., and van de Wal, R.: Experimental protocol for sea level projections from ISMIP6 stand-alone ice sheet models, The Cryosphere, 14, 2331–2368, https://doi.org/10.5194/tc-14-2331-2020, 2020." DATA_ISMIP6/$FILEOUT 

ncatted -a history_of_appended_files,global,d,, DATA_ISMIP6/$FILEOUT
ncatted -h -a history,global,d,, DATA_ISMIP6/$FILEOUT 

rm -f tmp_${VAR}.nc tmpout_${VAR}.nc tmpout_${VAR}_spval.nc

echo "   REFORMATTING DONE!!"

cd ..

echo "   ALL DONE"
