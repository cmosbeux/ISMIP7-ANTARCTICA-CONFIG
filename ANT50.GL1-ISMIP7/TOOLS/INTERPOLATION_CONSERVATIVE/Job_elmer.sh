#!/bin/bash
#MSUB -x
#MSUB -r MyJob                # Request name
#MSUB -m  scratch,work 
#MSUB -n 49                        # Number of tasks to use
#MSUB -c 1
#MSUB -T 900                      # Elapsed time limit in seconds
#MSUB -o TEST_%I.o              # Standard output. %I is the job id
#MSUB -e TEST_%I.e              # Error output. %I is the job id
#MSUB -q rome
#MSUB -A gen6066                  # Project ID

set -x

newgrp  gen6066

cd ${BRIDGE_MSUB_PWD}

ccc_mprun -f mpmd.conf
