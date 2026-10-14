clean:
	rm -f $(LIBS)

# Déclaration des cibles phony
.PHONY: all clean


mesh_name = MSH
mesh_output = MSH

compile:
	elmerf90 ./MY_SRC/ConnectedAreasUtils.F90 ./MY_SRC/SSACalving.F90 -o SSACalving
	elmerf90 ./MY_SRC/USF_RAMP.F90 -o USF_RAMP
run_passive:
	ElmerSolver Case_passive.sif
run_minimum:
	ElmerSolver Case_minimum.sif
run_passive_par:
	mpirun -np 2 ElmerSolver Case_passive.sif
run_minimum_par:
	mpirun -np 2 ElmerSolver Case_minimum.sif
