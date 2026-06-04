# ISMIP6 Asmb conservative interpolation to ismip6

History:  

- date 12/07/2022; auteur: F. Gillet-Chaulet  
	- 1rst version

required input files: 
- ant50.gl1-ismip6_grid.nc: elmerice unstructured ant50.gl1 grid formatted for cdo
- e.g. CCSM4_ant50.gl1_anomaly_1995-2100.nc: ismip6 asmb forcing file


Steps:  
  
1. Job.sh:
	- conservative interpolation weights from the curvilinear 4km grid to Elmer grid; can be done only once if forcing grid do not change.
	- output file : yCONweights_4km_ant50.gl1.nc

2. Job2.sh: 
	- conservative remapping from the curvilinear to the unstructured elmer gid
	- output file: e.g. CCSM4_ant50.gl1_anomaly_1995-2100.nc

3. Job_elmer.sh: 
	- a test case to read the asmb values in elmer...

4. Job_back.sh:
	- interpolate elmer results back to the original grid.
