TOOLS
=====

List of tools and examples
--------------------------
ADD_VAR_TO_RST  Beta_Weertmann2Joughin  INTERPOLATION_CONSERVATIVE  RSLT2NC  XIOStoISMIP6
- ADD_VAR_TO_RST: This is an example of how you can add extra variables into netcdf restart using Elmer capability.
- Beta_Weertmann2Joughin: Python script to convert a beta from a weertmann friction law to a beta ready for a regularised Coulomb friction law.
- RSLT2NC: Example on how to convert a .result file to a .nc file using Elmer
- XIOStoISMIP6: Tools to interpolate ELMER output produced with XIOS onto one ISMIP6 grid in a conservative manner. 3 scripts are present in this directory:
	* build_grid_ISMIP6.py: this script build one ISMIP6 output grid.
        * process_XIOS_output.bash: the main script (compute weights and run compute_interpolation.bash for each variables).
- INTERPOLATION_CONSERVATIVE: Tools to do conservative interpolation. It includes:
	* CreateElmerCDOgird.py: Script used to create the ELMER nc grid compatible with cdo
	* Job_back.sh is an example on how to remap in a conservative way a variable from Elmer grid to a regular stereo graphic grid
	* Job_interp_atmo_*.sh: Script exemple on how to interpolate conservatively from a regular stereo hrid toward the Elmer grid.
	* Job_weight_calculation.sh: Script used to compute weight required by the Job_interp_atmo_*.sh scripts.
