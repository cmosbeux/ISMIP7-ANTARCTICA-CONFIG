CONVERT .result in .nc
----------------------

*Requirement*:
- XIOS => xios_server.exe
- MSH directory containing the result you want to convert

*Instruction*:
- Step 1: Copy this directory in a place where you can run a mpi simulation
- Step 2: Copy xios_server.exe amd MSH inside the directory
- Step 3: adapt .sif, context and file_def in case some variable are missing (look at the header of one of your result file for the variable list)
- Step 4: adapt the run script to your computer
- Step 5: run the script
