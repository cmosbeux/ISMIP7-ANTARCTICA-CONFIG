Netcdf restart
==============

Convert .result => .nc
----------------------
A tools has been built to assist in this task
*Tools location*: TOOLS/RSLT2NC

Modification to the sif
-----------------------
- *1*: remove call the .result restart in the simulation section of the sif
- *2*: add a solver for restart with UgridReader (make sure restart contain only one time steps)
- *3*: if it failed to read some variable, you need to export them somewhere.

Checks did
----------
- Compare output between .nc and .result restart => differences on the partition edges: This comes from the interpolation error in the .result that comes from Benoit (change of domain and decomposition). There is a minor difference of value on common point between 2 partition. With the netcdf, the value are exactly the same on the common node on the 2 ppartitions.

How to activate netcdf restart
------------------------------
- Be sure the UgridReader solver read all the variable you need.
- Possibility to do the interpolation from on domain to another on the fly possible (Key word Mesh to add in the solver)
