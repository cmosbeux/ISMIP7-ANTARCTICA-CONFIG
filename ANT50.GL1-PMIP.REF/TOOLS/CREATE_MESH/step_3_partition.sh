#!/bin/bash

if [[ $# != 2 ]]; then echo "Usage: step3_partition.sh [NAME: mesh directory name] [N: number of partitions wanted]"; exit 42; fi

# define number of partition
n=$2
MESHNAME=$1

# Enleve les blanc qui pose pb dans les grilles créees
echo "Remove blank character from mesh.nodes (reason not clear) ..."
if [ ! -f $MESHNAME/mesh.nodes.withblank ]; then cp $MESHNAME/mesh.nodes $MESHNAME/mesh.nodes.withblank; fi
sed  '/^[[:blank:]]*$/ d' $MESHNAME/mesh.nodes.withblank > $MESHNAME/mesh.nodes

# Cut the grid in n partitions
echo "Cut the mesh in $n partitions"
ElmerGrid 2 2 $MESHNAME/ -autoclean -metis $n  

if [[ $? -ne 0 ]]; then echo "ERROR; exit 42"; exit 42; fi

# We are DONE
echo "partionioned mesh is available in $MESHNAME/partition.$n"
echo "DONE"
