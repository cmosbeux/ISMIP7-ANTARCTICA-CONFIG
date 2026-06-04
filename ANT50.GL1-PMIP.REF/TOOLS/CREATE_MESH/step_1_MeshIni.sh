#!/bin/bash

if [[ $# != 1 ]]; then echo "Usage: step_1_Meshini.sh [shp file path]"; exit 42; fi

## make geo file
SHPFILE=$1
echo 'Build contour.geo file: Convertion QGIS shp file to gmsh readable file'
echo ''
python Contour2geo.py -r 10000.0 -i $SHPFILE -o contour.geo
if [[ $? != 0 ]]; then echo 'E R R O R in Contour2geo.py script; stop';exit 42; fi
echo '-------------------------------------------------------------'
echo ''
## mesh
gmsh -2 -format msh2 contour.geo
if [[ $? != 0 ]]; then echo 'E R R O R in mesh step; stop';exit 42; fi
echo '-------------------------------------------------------------'
echo ''

## convert to Elmer
ElmerGrid 14 2 contour.msh -autoclean
if [[ $? != 0 ]]; then echo 'E R R O R in convertion to Elmer msh step; stop';exit 42; fi
echo '-------------------------------------------------------------'
echo ''

# command to generate vtu from msh file
ElmerGrid 14 5 Contour.msh -autoclean
if [[ $? != 0 ]]; then echo 'E R R O R in convertion msh to vtu step; stop';exit 42; fi
echo '-------------------------------------------------------------'
echo ''

## convert to vtu
ElmerGrid 2 5 contour
if [[ $? != 0 ]]; then echo 'E R R O R in convertion Elmer msh to vtu step; stop';exit 42; fi
echo '-------------------------------------------------------------'
echo ''
