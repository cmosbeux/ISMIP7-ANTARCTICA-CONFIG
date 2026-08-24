XIOS
====

Units management
----------------
Elmer/Ice outputs variable in the Elmer/Ice unit system used for the ISMIP6 simulation. This unit system is different than SI. 

*Decision*: We will apply the conversion in the context file

*Check*:
- Variable names and metadata checked
- Integrated variables vs Save scalar output checked => still need to understand what about Melt
- Melt check against LOG output
- Review all variable with paraview => all variables reviewed. Need input for basal drag
