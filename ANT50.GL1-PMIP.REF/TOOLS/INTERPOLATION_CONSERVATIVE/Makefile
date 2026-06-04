LIBS=MyUGridDataReader

all: $(LIBS)

MyUGridDataReader: UGridDataReader.F90
	elmerf90 -I$(XIOS_INC) -I/ccc/products/ccc_users_env/compil/Atos_7__x86_64/netcdf-fortran-4.4.4/intel--19.0.5.281__openmpi--4.0.1/hdf5__parallel/include  $^ -o $@ -L/ccc/products/ccc_users_env/compil/Atos_7__x86_64/netcdf-fortran-4.4.4/intel--19.0.5.281__openmpi--4.0.1/hdf5__parallel/lib -lnetcdff -L/ccc/products/ccc_users_env/compil/Atos_7__x86_64/netcdf-c-4.6.0/intel--19.0.5.281__openmpi--4.0.1/hdf5__parallel/lib -lnetcdf
