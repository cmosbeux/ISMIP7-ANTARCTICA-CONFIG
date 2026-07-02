SRC=./src/

LIBS=Flotation2 USFs USF_GroundedAreaCoeff USF_CondFront USF_CondFront_2

all: $(LIBS)

%: $(SRC)/%.F90
	elmerf90 $^ -o $@ -I$(XIOS_INC)


clean:
	rm -f $(LIBS)

