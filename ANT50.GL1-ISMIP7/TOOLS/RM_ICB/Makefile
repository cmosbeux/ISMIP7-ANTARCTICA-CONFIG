LIBS= GetConnectedAreas passive_cond ExcludeAreas

all: $(LIBS)


%: %.F90
	elmerf90 -I$(XIOS_INC) $^ -o $@ 

clean:
	rm -f $(LIBS)
