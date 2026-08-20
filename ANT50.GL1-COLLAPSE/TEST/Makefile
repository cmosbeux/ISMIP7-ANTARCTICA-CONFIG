n=2
mesh_name = MSH
mesh_output = MSH.P$n

compile:
	elmerf90 ../MY_SRC/GetConnectedAreas.F90 -o GetConnectedAreas
	elmerf90 ../MY_SRC/CollapseAreas_Serial.F90 -o CollapseAreas_Serial
	elmerf90 ../MY_SRC/passive_cond.F90 -o passive_cond
	elmerf90 ../MY_SRC/passive_fracture.F90 -o passive_fracture
	elmerf90 ../MY_SRC/ExcludeAreas.F90 -o ExcludeAreas
	elmerf90 ../MY_SRC/ConnectedAreasUtils.F90 ../MY_SRC/CollapseAreas.F90 -o CollapseAreas
run:
	ElmerSolver Collapse.sif
run_p1:
	ElmerSolver Collapse_parallel.sif
run_parallel:
	mpirun -np $(n) ElmerSolver Collapse_parallel.sif
mesh:
	ElmerGrid 2 2 "$(mesh_output)" -partdual -metiskway "$(n)" -halo -autoclean
clean:
	rm -f output_collapse.txt*
