#!/bin/bash
# argument is the required mesh resolution
res=2000
# convert to int for the output name
printf -v int %.0f "$res"
output=rectangle_$int

# make gmsh mesh
gmsh -format msh2 -2 -setnumber lc $res rectangle.geo -o $output.msh

# convert to Elmer
ElmerGrid 14 2 $output.msh -autoclean

# Convert to Elmer mesh with partitioning, metis k-way and halogreedy elements
n=2
ElmerGrid 2 2 $output -partdual -metiskway "$n" -halogreedy -autoclean
