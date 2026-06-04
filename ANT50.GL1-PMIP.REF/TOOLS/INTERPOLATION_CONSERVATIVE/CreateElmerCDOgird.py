# a quick python script used to generate the elmer grid definition compatible with cdo
#  require an unstructured netcdf file produced by xios as input....

import netCDF4 as nc
import numpy as np

fn = 'ismip6_fluxes_ant50.gl1-ismip6_1.nc'
gn = 'ant50.gl1-ismip6_grid.nc'

ds = nc.Dataset(fn)

flat = ds['mesh2D_face_y'][:]
flon = ds['mesh2D_face_x'][:]

nlat = ds['mesh2D_node_y'][:]
nlon = ds['mesh2D_node_x'][:]

connect = ds['mesh2D_face_nodes'][:,:]

ds.close()

sh = np.shape(connect)

flat_bnds = np.empty(sh)
flon_bnds = np.empty(sh)


for i in range(sh[1]):
    flat_bnds[:,i] = nlat[connect[:,i]]
    flon_bnds[:,i] = nlon[connect[:,i]]


cdog = nc.Dataset(gn, 'w')

cdog.CDI_grid_type='unstructured'

cell_dim = cdog.createDimension('ncells',sh[0])
v_dim = cdog.createDimension('vertices',sh[1])

lat_var = cdog.createVariable('lat', np.float64, ('ncells'))
lat_var.units = 'degrees_north'
lat_var.standard_name = 'latitude'
lat_var.bounds = 'lat_bnds'

lon_var = cdog.createVariable('lon', np.float64, ('ncells'))
lon_var.units = 'degrees_east'
lon_var.standard_name = 'longitude'
lon_var.bounds = 'lon_bnds'

latbnds_var = cdog.createVariable('lat_bnds', np.float64, ('ncells','vertices'))
lonbnds_var = cdog.createVariable('lon_bnds', np.float64, ('ncells','vertices'))

dummy = cdog.createVariable('dummy',np.byte,('ncells'))
dummy.long_name = 'dummy variable'
dummy.coordinates = 'lon lat'

lat_var[:] = flat[:]
lon_var[:] = flon[:]
latbnds_var[:,:] = flat_bnds[:,:]
lonbnds_var[:,:] = flon_bnds[:,:]

dummy[:] = 1

cdog.close()


