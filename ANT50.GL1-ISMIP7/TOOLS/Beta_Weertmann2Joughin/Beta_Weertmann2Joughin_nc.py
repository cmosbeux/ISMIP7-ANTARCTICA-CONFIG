#!/usr/bin/env python
# coding: utf-8

## History
# this code have been translate from the matlab code of julien brondex used in Brondex, 2019 by B. Urruty and cleaned by P. Mathiot (2022).
# 
## Usage
#  It take the data from the inversion to compute the parameter of different friction

## load module
import numpy as np
import xarray as xr

## Files names
cfilein  = 'restart_newmesh_t0.nc'                  #'ANT50.GL1-ISMIP6_5.restart_weertman_only.nc'
cfileout = 'restart_newmesh_t0_beta_coulomg_reg.nc' #'ANT50.GL1-ISMIP6_5.restart_beta_coulomg_reg.nc_v2'

## Constants
# Ice sheet parameters
m    =   1.0 / 3.0  # Exposant loi Weertman NL ou Schoof
Cmax =   0.4        # Cmax loi Schoof
hth  =  75          # [m]   treshold on high above flotation 
u0   = 300          # [m/a]  

# Physical constant (yrs**2 and 1e-6 factors are used to convert to 'Elmer/Ice unit system')
z_sl =        0       # [m] sea level heigh
yrs  = 31556926.0     # [s]
g    = 9.81 * yrs**2
rho_ice = 917.0  * 1.0e-6 /(yrs**2)
rho_sea = 1027.0 * 1.0e-6 /(yrs**2)

## Load input files
# load data
ds_weert=xr.open_dataset(cfilein)

# geometry
da_haf   = ds_weert['haf']
da_gmask = ds_weert['groundedmask'] 

# velocities
da_u     = ds_weert['ssavelocity 1']
da_v     = ds_weert['ssavelocity 2']

# ceff (use Ceff instead of beta to be more generic as it will work for any friction law)
da_ceff  = ds_weert['ceff']

## initialise output file
ds_cr=ds_weert.copy(deep=True)

# In order to have a generic file, we need to increase beta when haf below a treshold (hth). The correction is based on haf.

# coefficient reducteur lambda
# haf > hth => no change
# haf < 0   => floating part 
lbd=da_haf/hth
lbd.values[lbd.values>1]=1
lbd.values[lbd.values<0]=1

## Retreive taub in from Ceff
# Compute |ub|
u_norm=np.sqrt(da_u**2 + da_v**2)

# Compute taub
taub = da_ceff * u_norm

## Compute beta Coulomb Regularised
# définition du Beta qui sera injecté dans le modèle

coef=(u_norm/(u_norm+u0))
Beta_out1=taub/(coef**m)

# treshold on beta
Beta_out1_corr=Beta_out1*1.0/lbd
#cutoff=np.percentile(Beta_out1, 90.)
#Beta_out1_corr=xr.where( (Beta_out1_corr>cutoff) & (lbd < 1),cutoff,Beta_out1_corr)

# define a background value for floating part at 10kPa
Beta_out1_corr.values[da_gmask.values == -1] = 0.01

# add removed attributes
Beta_out1_corr.attrs=da_ceff.attrs

print(cutoff)
print(Beta_out1_corr.max())
print(xr.where( (lbd < 1),Beta_out1_corr,0).max())
## Save data
print('Write '+cfileout)
ds_cr['beta_cr']=Beta_out1_corr
ds_cr.attrs['History']=('Coulomb regularised beta parameter computed '
                              'from Ceff available in file '+cfilein+' '
                              'using Beta_Weertmann2Joughin_nc script')
ds_cr.to_netcdf(cfileout)
