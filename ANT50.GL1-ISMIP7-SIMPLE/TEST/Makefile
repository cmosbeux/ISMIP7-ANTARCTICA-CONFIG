n=2
mesh_name = MSH
mesh_output = MSH
BLD ?= .

NETCDFFORTRAN_INCDIR ?= $(shell nf-config --includedir 2>/dev/null)
NETCDFC_INCDIR ?= $(shell nc-config --includedir 2>/dev/null)
NETCDFFORTRAN_LIBS ?= $(shell nf-config --flibs 2>/dev/null)

NCINC = $(if $(strip $(NETCDFFORTRAN_INCDIR)),-I$(NETCDFFORTRAN_INCDIR)) $(if $(strip $(NETCDFC_INCDIR)),-I$(NETCDFC_INCDIR))
NCLIB = $(NETCDFFORTRAN_LIBS)


compile:
	elmerf90 ../MY_SRC/GetConnectedAreas.F90 -o GetConnectedAreas
	elmerf90 ../MY_SRC/CollapseAreas_Serial.F90 -o CollapseAreas_Serial
	elmerf90 ../MY_SRC/passive_cond.F90 -o passive_cond
	elmerf90 ../MY_SRC/ExcludeAreas.F90 -o ExcludeAreas
	elmerf90 ../MY_SRC/ConnectedAreasUtils.F90 ../MY_SRC/CollapseAreas.F90 -o CollapseAreas
	elmerf90 ../MY_SRC/nearestpoint.F90 -o nearestpoint $(FFLAGS) -J$(BLD) $(NCINC) $(NCLIB)
	elmerf90 ../MY_SRC/DistanceModule.F90 ../MY_SRC/PICO.F90 ../MY_SRC/Melt.F90 -o Melt $(FFLAGS) -J$(BLD) $(NCINC) $(NCLIB)
	elmerf90 ../MY_SRC/USF_CondDistance.F90 -o USF_CondDistance $(FFLAGS) -J$(BLD) $(NCINC) $(NCLIB)
	elmerf90 ../MY_SRC/USF_CondFront.F90 -o USF_CondFront $(FFLAGS) -J$(BLD) $(NCINC) $(NCLIB)
run:
	ElmerSolver Antarctica.sif
mesh:
	# -halogreedy instead of -halo: needed so connected regions split by a partition boundary via a single shared node aren't wrongly disconnected
	ElmerGrid 2 2 "$(mesh_output)" -partdual -metiskway "$(n)" -halogreedy -autoclean

