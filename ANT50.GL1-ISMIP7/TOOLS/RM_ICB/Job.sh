#!/bin/bash
#MSUB -x
#MSUB -r Areas                # Request name
#MSUB -m  scratch,work 
#MSUB -n 1                       # Number of tasks to use
#MSUB -T 300                   # Elapsed time limit in seconds
#MSUB -o CA_%I.o              # Standard output. %I is the job id
#MSUB -e CA_%I.e              # Error output. %I is the job id
#MSUB -q rome
#MSUB -A gen6066                  # Project ID

set -x

newgrp  gen6066
cd ${BRIDGE_MSUB_PWD}

./Run.sh

