#!/bin/bash

#files=$(ls ISMIP6_W*.nc)
files=$(ls ISMIP6_W-expAE03_027.restart.nc)
for i in $files
do
  echo $i
  exp=$(echo $i | sed -e 's/ISMIP6_W-exp\(.*\).restart.nc/\1/')
  #sif_name=ConnectedAreas_"$exp".sif
  #sed "s/<EXP>/$exp/g" ConnectedAreas.sif.tp > $sif_name
  sif_name=ExcludeAreas_"$exp".sif
  sed "s/<EXP>/$exp/g" ExcludeAreas.sif.tp > $sif_name
  ElmerSolver $sif_name
done
