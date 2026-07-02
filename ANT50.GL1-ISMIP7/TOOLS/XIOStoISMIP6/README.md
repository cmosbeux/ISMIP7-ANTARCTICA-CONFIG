initial grid have to be in `GRID_XIOS` directory with this foramt: <INPUT_GRID_NAME>_grid.nc
target grid have to be in `GRID_ISMIP6` directory with this format: <OUTPUT_GRID_NAME>_grid.nc
Use link to spare space in your home if needed

Usage:
./process_XIOS_output.bash ant50.gl1-ismip6 ISMIP6_AIS_4000m ISMIP6
ant50.gl1-ismip6 = <INPUT_GRID_NAME>
ISMIP6_AIS_4000m = <OUTPUT_GRID_NAME>
ISMIP6 = Experience name

Input data have to be in `DATA_XIOS/<EXP_NAME>/` with this name format: `ismip6_<STREAM>_ant50.gl1-<EXP_NAME in lower case>_???.nc`


<STREAM> = states or fluxes

Require nco, cdo

Working on TGCC. Please adapte *.sh to match your computer

To generate the target grid, use build_grid_ISMIP6.ipynb (default is 4km resolution)

All variable are interpolated with fracarea normalization except sftgif sftgrf and sftflf than is interpolated using destarea. So to retreive the area integrated variable, you need to integrate variable over cell_area*sftgif (error of 1e-4 with acabf in one of our validation test, 1.5% otherwise)
