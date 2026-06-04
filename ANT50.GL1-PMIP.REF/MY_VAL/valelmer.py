#!/usr/bin/env python
# coding: utf-8
print('load modules')
import re
import os
import glob
import matplotlib
matplotlib.use('TkAgg')
import matplotlib.pyplot as plt
from matplotlib.dates import DateFormatter
import argparse
import sys
import cartopy.crs as ccrs
import cartopy
import xarray as xr
import pandas as pd
from datetime import datetime

print('load functions')
# load arguments
def load_arguments():
    # deals with argument
    parser = argparse.ArgumentParser()
    parser.add_argument("-runid", metavar='runid list'  , help="used to look information in runid.db", type=str, nargs='+' , required=True )
    parser.add_argument("-dir"  , metavar='directory of input file' , help="directory of input file", type=str, nargs=1    , required=False, default=['EDDIR'])
    parser.add_argument("-o"    , metavar='figure_name', help="output figure name without extension", type=str, nargs=1    , required=False, default=['output'])
    parser.add_argument("-plt"  , help="plot figures (need monitoring files)", required=False, action="store_true")
    parser.add_argument("-compute_nc"  , help="compute monitoring files (-o option useless)", required=False, action="store_true")
    return parser.parse_args()

# parse style name
def parse_dbfile(runid):
    try:
        lstyle=False
        with open('style_elmer.db') as fid:
            for cline in fid:
                att=cline.split('|')
                if att[0].strip() == runid:
                    cpltrunid = att[0].strip()
                    cpltname  = att[1].strip()
                    cpltline  = att[2].strip()
                    cpltcolor = att[3].strip()
                    lstyle=True
        if not lstyle:
            print( runid+' not found in style_elmer.db' )
            raise Exception

    except Exception as e:
        print( 'Issue with file : style_elmer.db' )
        print( e )
        sys.exit(42)

    # return value
    return cpltrunid, cpltname, cpltline, cpltcolor

def parse_dbbasin():
    try:
        with open('basin_elmer.db') as fid:
            iline=0
            dict_basin={}
            for cline in fid:
                iline += 1
                if iline == 1:
                    cfile_basin=cline.split(':')[1].strip()
                else :
                    dict_basin[cline.split('|')[0].strip()]=cline.split('|')[1].strip()

    except Exception as e:
        print( 'Issue with file : basin_elmer.db' )
        print( e )
        sys.exit(42)

    return cfile_basin,dict_basin


# load arguments
args=load_arguments()

# define plotas
stoy=86400*365
kgtoGt=1e-9*1e-3
m2toMkm2=1e-6*1e-6
m3toMkm3=1e-6*1e-9

plot_keys =['SMB_Flux', 'BMB_Flux'   , 'Ice_Discharge', 'Ice_flux_at_Grounding_Line', 'Floating_ice_area', 'Volume_Above_Flotation'  , 'Volume_rate_of_change', 'Land_Ice_Area']
plot_sf   =[kgtoGt*stoy, kgtoGt*stoy   ,  kgtoGt*stoy    ,  kgtoGt*stoy                 ,  m2toMkm2          ,  m3toMkm3                 ,  1e-9*stoy         , m2toMkm2       ]
plot_units=['Gt/y'    , 'Gt/y'       , 'Gt/y'         , 'Gt/y'                      , '1e6 km2'          , '1e6 km3'                 , 'km3/y'                , '1e6 km2'      ]
plot_ncvar=['acabf'   , 'libmassbffl', 'lifmassbf'    , 'ligroundf'                 , 'sftflf'           , 'lithkaf'                 , 'dlithkdt'             , 'sftgif'        ]
plot_ncfil=['fluxes'  , 'fluxes'     , 'fluxes'       , 'fluxes'                    , 'states'           , 'states'                  , 'fluxes'               , 'states'       ]

# get basin definition
cfile_basin,dict_basin=parse_dbbasin()
basin_df=xr.open_dataset(cfile_basin)

# define run lst
runid_lst=args.runid

# define directory
cdir=args.dir[0]
if cdir == 'EDDIR':
    cdir=os.environ['EDDIR']+'/'

if args.compute_nc:

    # Compute all the datasets
    print('Compute all the datasets :')

    varflx_lst=[plot_ncvar[istream] for istream,cstream in enumerate(plot_ncfil) if cstream == 'fluxes']
    varflx_lst.extend(['basins','time','time_centered','cell_area'])
    varsts_lst=[plot_ncvar[istream] for istream,cstream in enumerate(plot_ncfil) if cstream == 'states']
    varsts_lst.extend(['basins','time','time_instant','cell_area'])
    
    for runid in runid_lst:
        print(runid)
        data_vars_fluxes={}
        data_vars_states={}
        
        # open data
        print('    load data')
        CONFIG=runid.split('-')[0]
        cfile_dat=cdir+'/'+CONFIG+'/SIMU/'+runid+'/MY_OUTPUT/ismip6_states_'+runid.lower()+'_???.nc'
        ds_states=xr.open_mfdataset(cfile_dat,concat_dim='time', chunks={'time': 1}, preprocess=lambda ds: ds[varsts_lst])
    
        cfile_dat=cdir+'/'+CONFIG+'/SIMU/'+runid+'/MY_OUTPUT/ismip6_fluxes_'+runid.lower()+'_???.nc'
        ds_fluxes=xr.open_mfdataset(cfile_dat,concat_dim='time', chunks={'time': 1}, preprocess=lambda ds: ds[varflx_lst])
        
        print('    compute data')
        da_basin=ds_states['basins'].isel(time=0).drop('time_instant').drop('time')  
        basinlst=["%.2d" % int(i) for i in set(da_basin.values)]
        basinlst.append('00')
        for cbasin in basinlst:
            print('        '+cbasin)
            ibasin=int(cbasin)
    
            # mask data
            if ibasin > 0:
                ds_int_flx=ds_fluxes.where(ds_fluxes['basins']==ibasin, drop=True)
                ds_int_sts=ds_states.where(ds_states['basins']==ibasin, drop=True)
            elif ibasin == 0:
                ds_int_flx=ds_fluxes.where(ds_fluxes['basins']>0, drop=True)
                ds_int_sts=ds_states.where(ds_states['basins']>0, drop=True)

            # compute dataset for each run
            for ikey,ckey in enumerate(plot_keys):
                print(ckey)
                cvar=plot_ncvar[ikey]
                if plot_ncfil[ikey]=='states':
                    ds=ds_int_sts
                    da_int=(ds[cvar]*ds['cell_area']).sum(dim='nmesh2D_face')*plot_sf[ikey]
                    da_int.attrs['units'] = plot_units[ikey]
                    da_int.attrs['long_name'] = 'Integrated '+ckey+' over basin number '+cbasin
                    data_vars_states[ckey+'_'+cbasin] = da_int
                elif plot_ncfil[ikey]=='fluxes':
                    ds=ds_int_flx
                    da_int=(ds[cvar]*ds['cell_area']).sum(dim='nmesh2D_face')*plot_sf[ikey]
                    da_int.attrs['units'] = plot_units[ikey]
                    da_int.attrs['long_name'] = 'Integrated '+ckey+' over basin number '+cbasin
                    data_vars_fluxes[ckey+'_'+cbasin] = da_int
    
        print('    add basin')    
        data_vars_fluxes['basins']=da_basin
        data_vars_states['basins']=da_basin
        
        ds_fluxes=xr.Dataset(data_vars_fluxes)
        ds_states=xr.Dataset(data_vars_states)
    
    # Write netcdf (and likely do all the lazy operation)
        print('   write dataset')
        cfout_fluxes='ismip6_fluxes_'+runid.lower()+'_monitoring.nc'
        cfout_states='ismip6_states_'+runid.lower()+'_monitoring.nc'
        ds_fluxes.to_netcdf(cfout_fluxes)
        ds_states.to_netcdf(cfout_states)   
    print('End computing nc')

elif args.plt:
# Read netcdf
    data_runid_states=[]
    data_runid_fluxes=[]
    for runid in runid_lst:
        ds_fluxes=xr.open_dataset('ismip6_fluxes_'+runid.lower()+'_monitoring.nc')
        ds_states=xr.open_dataset('ismip6_states_'+runid.lower()+'_monitoring.nc')
     
        data_runid_fluxes.append(ds_fluxes)
        data_runid_states.append(ds_states)
   
    # get basin list 
    da_basin=ds_states['basins']
    basinlst=["%.2d" % int(i) for i in set(da_basin.values)]
    basinlst.append('00')

    # load style
    plot_sty=[]
    plot_clr=[]
    line_name=[]
    for runid in runid_lst:
        _, runid_name, styline, styclr = parse_dbfile(runid)
        line_name.append(runid_name)
        plot_sty.append(styline)
        plot_clr.append(styclr)
    
    # make plot for each basin
    print('Build plots:')
    for cbasin in basinlst:
        ibasin=int(cbasin)
        print('    Basin: '+cbasin)
    
        print('        Build each panda df to plot')
        dict_df={}
        for ikey,ckey in enumerate(plot_keys):
            df=[]
            for irunid,runid in enumerate(runid_lst):
                if plot_ncfil[ikey]=='states':
                    ds_var=data_runid_states[irunid]
                elif plot_ncfil[ikey]=='fluxes':
                    ds_var=data_runid_fluxes[irunid]
    
                datadf=ds_var[ckey+'_'+cbasin].to_pandas()
                datadf.name=runid
                df.append(datadf.sort_index())
    
            dict_df[ckey]=pd.concat(df, axis=1)
            dict_df[ckey].index=dict_df[ckey].index.strftime('%Y')
        
        print('        initialise figure')    
        fig=plt.figure(figsize=(16,14), dpi= 100, facecolor='w', edgecolor='k')
        axes=[None]*9
        fig.suptitle('Elmer monitoring (basin '+dict_basin[cbasin]+')',fontsize=18)
        count=0
        print('        start plotting')
        for r in range(3):
            for c in range(3):
                count+=1
                if (r,c) != (2,2):
                    axes[count-1] = fig.add_subplot(3,3,count)
                    ckey=list(dict_df.keys())[count-1]
                    dict_df[ckey]=dict_df[ckey].interpolate(limit_area='inside')
                    lg=dict_df[ckey].plot(ax=axes[count-1],legend=False,label=line_name,linewidth=2,fontsize=14,color=plot_clr,style=plot_sty)
                    axes[count-1].set_title(ckey+' ['+plot_units[count-1]+']',fontsize=16)
                    axes[count-1].set_xlabel('')
                    axes[count-1].ticklabel_format(axis='y', style='sci', scilimits=(0,0), useOffset=False)
                    axes[count-1].grid(True)
                    ymin=dict_df[ckey].quantile([.01]).min().min()
                    ymax=dict_df[ckey].quantile([.99]).max().max()
                    yrange=ymax-ymin
                    ymin=ymin-0.05*yrange
                    ymax=ymax+0.05*yrange
                    axes[count-1].set_ylim(ymin, ymax)
    
                    if r == 2 or (r,c) == (1,2):
                        axes[count-1].set_xlabel('Time [years]',fontsize=16)
                else:
                    print('       plot map basin')
                    proj = ccrs.Stereographic(central_latitude=-90.0, central_longitude=0.0) 
                    axes[count-1] = fig.add_subplot(3,3,9,projection=proj)
                    data=basin_df.where(basin_df.basins == int(cbasin), drop=True)
                    data.basins.plot(x='lon', y='lat', transform=ccrs.PlateCarree(),add_colorbar=False)
                    axes[count-1].set_extent((-180, 180, -90, -65), ccrs.PlateCarree())
                    feature=cartopy.feature.NaturalEarthFeature('physical', 'antarctic_ice_shelves_polys', '50m', facecolor='none')
                    axes[count-1].add_feature(feature,linewidth=0.5,edgecolor='k')
                    feature=cartopy.feature.NaturalEarthFeature('physical', 'coastline'                , '50m', facecolor='none')
                    axes[count-1].add_feature(feature,linewidth=0.5,edgecolor='k')
    
        fig.subplots_adjust(left=0.01,right=0.98, bottom=0.05, top=0.93, wspace=0.20, hspace=0.20)
    
        lax = plt.axes([0.0, 0.0, 1, 0.00])
        lline, llabel = lg.get_legend_handles_labels()
        leg=plt.legend(lline, llabel, loc='upper left', ncol = 4, frameon=False,fontsize=16)
        lax.set_axis_off()
    
        # save figures
        print('        Save Figure')
        cfile_out=args.o[0]
        cfile_out_png=cfile_out+'_'+cbasin+'.png'
        fig.savefig(cfile_out_png, format='png', dpi=150, bbox_inches="tight")
    print('End plotting')
                
