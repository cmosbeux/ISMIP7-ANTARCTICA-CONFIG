Interpolation of restart from one mesh to the other
===================================================

.result case
------------

This tools is helping user to create restart on multiple decompositions

To do so:
 - update M2M.sif to deal with the needed variables for the restart (in the 2 solvers)
 - In the Mesh2Mesh solver as long as both input and output restart are on the same grid, no need of the `Mesh` variable.
 - If you need to move from one solver to the other, you need to have the mesh used to produce the initial restart (in mesh_in in this case) and add the path to it in Mesh variable (partinion.XX will be added automatically)

.nc case
--------

Netcdf restart can be interpolated the same way as the .result in theory. Not tested yet. To do so use the bloc used to read your netcdf restart in you Elmer/Ice production run sif and add `Mesh` variable.

Limitation
----------

 - No success to run it on TGCC. Only on dahu. Why ???? 
 - Elmer solver to do it fail in my test. Why ????
