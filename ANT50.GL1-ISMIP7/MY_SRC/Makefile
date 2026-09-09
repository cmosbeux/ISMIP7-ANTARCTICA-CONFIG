
SRC=./

BLD=../MY_BLD

NCINC=-I$(NETCDFFORTRAN_INCDIR) -I$(NETCDFC_INCDIR)

NCLIB=-L$(NETCDFFORTRAN_LIBDIR) -L$(NETCDFC_LIBDIR) -lnetcdf -lnetcdff

VPATH=$(BLD)

#Test compiler and flags
FC ?= elmerf90

COMPILER := $(shell $(FC) --version 2>/dev/null | head -n 1)

FFLAGS = -I$(XIOS_INC) -O2 -g

ifneq ($(findstring GNU,$(COMPILER)),)
  FFLAGS += -ffpe-trap=invalid,zero,overflow -fbacktrace
else ifneq ($(findstring Intel,$(COMPILER)),)
  FFLAGS += -fpe0 -traceback
else
  $(warning Unknown compiler: $(COMPILER))
endif
# FFLAGS=-I$(XIOS_INC) -O2 -fpe0 -ftrapuv -g -traceback
# FFLAGS=-I$(XIOS_INC) -O2 -ffpe-trap=invalid,zero,overflow -fbacktrace -g


LIBS= CollapseAreas Melt USF_ExitCondition FrontThickness_mask USF_CondFront USF_CondDistance SlipCoef nearestpoint GetConnectedAreas passive_cond ExcludeAreas UGridDataReader

all: $(LIBS)

#---------------------------------------------------
# USR function
USF_ExitCondition:${SRC}/USF_ExitCondition.F90
	elmerf90 $^ -o $(BLD)/$@ $(FFLAGS)

UGridDataReader:$(SRC)/UGridDataReader.F90
	elmerf90 $(NCINC) $^ -o $(BLD)/$@ $(FFLAGS) $(NCLIB)

#---------------------------------------------------
# Post Porcessing
# PP define basin
nearestpoint:$(SRC)/nearestpoint.F90
	elmerf90 $(NCINC) $^ -o $(BLD)/$@ $(FFLAGS) $(NCLIB)
#
#---------------------------------------------------


#---------------------------------------------------
# COLLAPSE
CollapseAreas: $(SRC)/ConnectedAreasUtils.F90 $(SRC)/CollapseAreas.F90
	rm -f $(BLD)/*.mod
	elmerf90 $^ -o $(BLD)/$@ $(FFLAGS) $(NCINC) $(NCLIB)

# BMB 
# BMB: PICO

Melt: $(SRC)/DistanceModule.F90 $(SRC)/PICO.F90 $(SRC)/Melt.F90
	rm -f $(BLD)/*.mod
	elmerf90 $^ -o $(BLD)/$@ $(FFLAGS) $(NCINC) $(NCLIB)

FrontThickness_mask:$(SRC)/FrontThickness_mask.F90
	elmerf90 $^ -o $(BLD)/$@ $(FFLAGS)

USF_CondFront:$(SRC)/USF_CondFront.F90
	elmerf90 $^ -o $(BLD)/$@ $(FFLAGS)

USF_CondDistance:$(SRC)/USF_CondDistance.F90
	elmerf90 $^ -o $(BLD)/$@ $(FFLAGS)

#---------------------------------------------------
# Slip Coefficient correction Coulomb
SlipCoef:$(SRC)/SlipCoef.F90
	elmerf90 $^ -o $(BLD)/$@ $(FFLAGS)

SlipCoef_Limiter:$(SRC)/SlipCoef_Limiter.F90
	elmerf90 $^ -o $(BLD)/$@ $(FFLAGS)

clean:
	cd $(BLD) && rm -f $(LIBS)

#---------------------------------------------------
# Processing icebergs
GetConnectedAreas: $(SRC)/GetConnectedAreas.F90
	elmerf90 $^ -o $(BLD)/$@ $(FFLAGS)

passive_cond: $(SRC)/passive_cond.F90
	elmerf90 $^ -o $(BLD)/$@ $(FFLAGS)

ExcludeAreas: $(SRC)/ExcludeAreas.F90
	elmerf90 $^ -o $(BLD)/$@ $(FFLAGS)

clean:
	cd $(BLD) && rm -f $(LIBS)
