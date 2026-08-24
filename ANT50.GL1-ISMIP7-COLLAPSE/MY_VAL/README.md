Example usage:
To output basin 01 for simulation ANT50.GL1-ISMIP6. Data are located on [-dir]/<CONFIG>/SIMU/[-runid]/MY_OUTPUT. <CONFIG> is automatically inferred from the runid name. The syntaxe of the run id name is expected to by <CONFIG>-<CASE> (Case being the experiment name for exemple).
To output all the basin replace 01 by ALL. TO build the build the plot without showing figure, use option -noshow

To avoid entering -dir, you can defined as environment variable in your bashrc the variable EDDIR. This will be the default picked up by the script.

In order to avoid very long processing, we first compute the sapatial integration and save it on disk then we do the plot

To compute the monitoring netcdf file for a list of simulation (here only one) [note, the -o option is useless]:
```
python valelmer.py -dir /ccc/cont003/home/gen6035/mathiotp/ELMER/ELMER_CM/ -runid ismip6_w-ctrlae -o cr -compute_nc
```

Once all the monitoring file are created, you can build the plot like this:
```
python valelmer.py -dir /ccc/cont003/home/gen6035/mathiotp/ELMER/ELMER_CM/ -runid ismip6_w-ctrlae -o cr -plt
```
