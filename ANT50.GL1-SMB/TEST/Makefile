n=2
mesh_name = MSH
mesh_output = MSH

compile:
	elmerf90 ../MY_SRC/TIPMIP_SMB.F90 -o TIPMIP_SMB	
	elmerf90 ../MY_SRC/TIPMIP_SMB_Elemental.F90 -o TIPMIP_SMB_Elemental	
run:
	ElmerSolver SMB.sif
run_parallel:
	mpirun -np $(n) ElmerSolver SMB.sif
mesh:
	# -halogreedy instead of -halo: needed so connected regions split by a partition boundary via a single shared node aren't wrongly disconnected
	ElmerGrid 2 2 "$(mesh_output)" -partdual -metiskway "$(n)" -halogreedy -autoclean
clean:
	rm -f output_collapse.txt*



