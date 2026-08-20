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

WORKTMP=${CCCSCRATCHDIR}/TMPDIR_XIOStoELMER
if [ -z "$CCCSCRATCHDIR" ]; then
	echo "E R R O R: CCCSCRATCHDIR is not defined; exit 42"
	exit 42
fi
if [ ! -d "$WORKTMP" ]; then
	echo "E R R O R: $WORKTMP missing; exit 42"
	exit 42
fi

cd "$WORKTMP" || exit 42

# check presence of input file
if [ ! -f $FILEIN  ]; then echo "E R R O R: $FILEIN  missing; exit 42"; nerr=$((nerr+1)); fi
if [ ! -f $GRIDIN  ]; then echo "E R R O R: $GRIDIN  missing; exit 42"; nerr=$((nerr+1)); fi
if [ ! -f $GRIDOUT ]; then echo "E R R O R: $GRIDOUT missing; exit 42"; nerr=$((nerr+1)); fi

echo ""
if [[ $nerr != 0 ]]; then echo "$nerr detected; exit 42"; exit 42; fi

echo "REMAP $VAR from $FILEIN on $GRIDIN toward $GRIDOUT grid"

# time variable
time_axis=$(ncdump -h "$FILEIN" | grep -E "[[:space:]]$VAR:coordinates" | grep -Eo 'time[[:alnum:]_]*' | head -n 1)

# Fallbacks for files without a usable coordinates attribute on the variable.
if [ -z "$time_axis" ] || ! ncks -m -v "$time_axis" "$FILEIN" >/dev/null 2>&1; then
	for cand in time_instant time time_centered time_counter; do
		if ncks -m -v "$cand" "$FILEIN" >/dev/null 2>&1; then
			time_axis="$cand"
			break
		fi
	done
fi

if [ -z "$time_axis" ]; then
	echo "E R R O R: cannot determine time axis for variable $VAR in $FILEIN; exit 42"
	exit 42
fi

extract_list="$VAR,$time_axis"
time_bounds_var=$(ncdump -h "$FILEIN" | grep -E "[[:space:]]$time_axis:bounds" | sed -E 's/.*"([^"]+)".*/\1/' | head -n 1)
if [ -n "$time_bounds_var" ] && ncks -m -v "$time_bounds_var" "$FILEIN" >/dev/null 2>&1; then
	extract_list="$extract_list,$time_bounds_var"
elif ncks -m -v "${time_axis}_bounds" "$FILEIN" >/dev/null 2>&1; then
	extract_list="$extract_list,${time_axis}_bounds"
fi

## some renaming to be compatible with cdo....
## might be easier to use ESMF or xios foer the interpolation
## extract the asmb and time axis (centered for averaged variables)
TMPf=tmp_${VAR}.nc
ncks -O -C -v "$extract_list" "$FILEIN" "$TMPf" || exit 42
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
cdo -L remap,$GRIDOUT,$WEIGHTS -selname,$VAR $TMPf $TMPf1 || exit 42

echo "   REMAPING DONE!!"

# fix att, name ...
# bounds dim can be named differently depending on CDO/NCO versions.
if ncdump -h "$TMPf1" | grep -q '[[:space:]]nv4 ='; then
	ncrename -d nv4,nv "$TMPf1" || exit 42
elif ncdump -h "$TMPf1" | grep -q '[[:space:]]axis_nbounds ='; then
	ncrename -d axis_nbounds,nv "$TMPf1" || exit 42
fi

if [ "$time_axis" != "time" ]; then
	if ncks -m -v time "$TMPf1" >/dev/null 2>&1; then
		# target time axis already exists, remove duplicate source axis if present
		if ncks -m -v "$time_axis" "$TMPf1" >/dev/null 2>&1; then
			ncks -O -x -v "$time_axis" "$TMPf1" "$TMPf1" || exit 42
		fi
	else
		ncrename -d "$time_axis",time -v "$time_axis",time "$TMPf1" || exit 42
	fi
fi

# If bounds variable followed time axis rename, standardize to time_bounds.
if ncks -m -v "${time_axis}_bounds" "$TMPf1" >/dev/null 2>&1; then
	if ncks -m -v time_bounds "$TMPf1" >/dev/null 2>&1; then
		# target bounds already exists, remove duplicate source bounds
		ncks -O -x -v "${time_axis}_bounds" "$TMPf1" "$TMPf1" || exit 42
	else
		ncrename -v "${time_axis}_bounds",time_bounds "$TMPf1" || exit 42
	fi
fi

ncks -A -v mapping $GRIDOUT $TMPf1                  || exit 42
ncatted -a 'grid_mapping',$VAR,c,c,'mapping' $TMPf1 || exit 42
ncatted -a 'mesh',$VAR,d,,                   $TMPf1 >/dev/null 2>&1 || true
ncatted -a 'location',$VAR,d,,               $TMPf1 >/dev/null 2>&1 || true

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

ncatted -a title,global,a,c,"ISMIP7 AIS simulation (Tier 1): variable $VAR for experiment $EXP" DATA_ISMIP6/$FILEOUT
ncatted -a url,global,a,c,"https://www.ismip.org" DATA_ISMIP6/$FILEOUT 
ncatted -a experiment,global,a,c,'ssp585' DATA_ISMIP6/$FILEOUT 
ncatted -a institution,global,a,c,"Institut des Géosciences de l'Environnement, CNRS, Grenoble, France" DATA_ISMIP6/$FILEOUT 
ncatted -a contacts,global,a,c,"C. Mosbeux, M. Lebescond de Coatpont and F. Gillet-Chaulet" DATA_ISMIP6/$FILEOUT 
ncatted -a contact email,global,a,c,"cyrille.mosbeux@univ-grenoble-alpes.fr" DATA_ISMIP6/$FILEOUT 

ncatted -a history_of_appended_files,global,d,, DATA_ISMIP6/$FILEOUT
ncatted -h -a history,global,d,, DATA_ISMIP6/$FILEOUT 

rm -f tmp_${VAR}.nc tmpout_${VAR}.nc tmpout_${VAR}_spval.nc

echo "   REFORMATTING DONE!!"

cd ..

echo "   ALL DONE"
