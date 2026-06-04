LIBS= M2M

all: $(LIBS)

M2M: MyMesh2MeshSolver.F90 MyInterpolateMeshToMesh.F90
	elmerf90  $^ -o $@ -I$(XIOS_INC)

clean:
	rm -f $(LIBS)
