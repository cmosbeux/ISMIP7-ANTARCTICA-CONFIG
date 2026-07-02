#!/usr/bin/env python
# coding: utf-8

# In[11]:


# load modules
import numpy as np
import xarray as xr
import pyproj


# In[15]:


# build x, y
xlimits=[-3040000, 3040000]
ylimits=[-3040000, 3040000]
res=2000
cproj='epsg:3031'
x=np.arange(xlimits[0],xlimits[1]+1,res)
y=np.arange(ylimits[0],ylimits[1]+1,res)


# In[9]:


#bounds
xbnds=np.zeros(shape=(x.shape[0],2))
ybnds=np.zeros(shape=(y.shape[0],2))
xbnds[:,0]=x-res/2 ; xbnds[:,1]=x+res/2 ;
ybnds[:,0]=y-res/2 ; ybnds[:,1]=y+res/2 ;


# In[18]:


# lat, lon
p = pyproj.Proj(cproj)
xin ,yin = np.meshgrid(x,y)
lon,lat = p(xin,yin,inverse=True)


# In[39]:


# lat lon bounds
lonbnds=np.zeros(shape=(lon.shape[0],lon.shape[1],4))
latbnds=np.zeros(shape=(lat.shape[0],lat.shape[1],4))

xin ,yin = np.meshgrid(xbnds[:,0],ybnds[:,0]); lonbnds[:,:,0],latbnds[:,:,0]=p(xin,yin,inverse=True)
xin ,yin = np.meshgrid(xbnds[:,1],ybnds[:,0]); lonbnds[:,:,1],latbnds[:,:,1]=p(xin,yin,inverse=True)
xin ,yin = np.meshgrid(xbnds[:,1],ybnds[:,1]); lonbnds[:,:,2],latbnds[:,:,2]=p(xin,yin,inverse=True)
xin ,yin = np.meshgrid(xbnds[:,0],ybnds[:,1]); lonbnds[:,:,3],latbnds[:,:,3]=p(xin,yin,inverse=True)


# In[122]:


# cell area
cell_area=np.zeros(shape=(lon.shape[0],lon.shape[1]))+res**2


# In[147]:


# define data
data_grid = {'lon':(['y','x'],lon,
                   {'long_name':'longitude',
                   'standard_name':'longitude',
                   'units':'degrees_east',
                   'bounds':'lon_bnds'}),
             'lon_bnds':(['y','x','nv4'],lonbnds),
             'lat':(['y','x'],lat,
                   {'long_name':'latitude',
                   'standard_name':'latitude',
                   'units':'degrees_north',
                   'bounds':'lat_bnds'}),
             'lat_bnds':(['y','x','nv4'],latbnds),
             'cell_area':(['y','x'],cell_area,
                   {'long_name':'area of grid cell',
                   'standard_name':'cell_area',
                   'coordinates':'lat lon',
                   'units':'m2'}),
             'mapping':([],3031,
                   {'grid_mapping_name':'Antarctic Polar Stereographic',
                    'latitude_of_origin':'-71',
                    'central_meridian':'0',
                    'false_easting':'0',
                    'false_northing':'0',
                    'unit':'m',
                    'authority':'epsg3031'})
            }
            
            #  'lon2d':(['y','x'],lon,
            #        {'long_name':'grid center longitude',
            #        'standard_name':'longitude',
            #        'units':'degrees_east',
            #        'coordinates':'lat lon',
            #        '_CoordinateAxisType':"Lon"}),
            #  'lat2d':(['y','x'],lat,
            #        {'long_name':'grid center latitude',
            #        'standard_name':'latitude',
            #        'units':'degrees_north',
            #        'coordinates':'lat lon',
            #        '_CoordinateAxisType':"Lat"}),
# define coordinates
coords = {'x': (['x'], x,
                {'units':'m',
                 'long_name':'x-coordinate in Cartesian system'}),
          'y': (['y'], y,
                {'units':'m',
                 'long_name':'y-coordinate in Cartesian system'})}

attrs = {'conventions':"x_bnds, y_bnds, lon_bnds and lat_bnds follow cf convention: https://cfconventions.org/cf-conventions/cf-conventions.html"}


# In[148]:


ds = xr.Dataset(data_vars=data_grid, 
                coords=coords,
                attrs=attrs)


# In[153]:


ds.to_netcdf('ISMIP6_grid_AIS_'+str(res)+'m.nc')

