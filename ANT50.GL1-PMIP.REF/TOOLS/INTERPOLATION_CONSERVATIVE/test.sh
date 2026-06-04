#!/bin/bash
######################
## IRENE   TGCC/CEA ##
######################
#MSUB -r test
#MSUB -o test.o%j
#MSUB -e test.e%j
#MSUB -n 1 
#MSUB -x (eq -exclusive, remove it for share queue)
#MSUB -T 90 (walltime in second)
#MSUB -A gen6066 (gen6035 for us)
#MSUB -q rome (partition name, rome for us)
#MSUB -m work,scratch (spaces accessible from the compute node)

set -x
ls dslfkgjsldfkgj
ls titi
ierr=$?
if [[ $ierr != 0 ]]; then echo 'E R R O R'; exit 42; fi
