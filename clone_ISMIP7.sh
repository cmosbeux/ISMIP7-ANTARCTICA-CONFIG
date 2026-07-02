#!/bin/bash

# Prompt user for input
read -p "Enter SSP (e.g., SSP126): " ssp
read -p "Enter GCM (default CESM2-WACCM): " gcm
gcm=${gcm:-CESM2-WACCM}
read -p "Enter EXP (e.g., 004): " exp
read -p "Enter FINAL YEAR (2100 or 2200): " final_year
read -p "Enter ATMO FORCING END (default is 2200): " final_atmo_year
final_atmo_year=${final_atmo_year:-2200}

# Prompt user for friction law
echo "Choose a friction law:"
echo "  1) weertman1"
echo "  2) weertman3"
echo "  3) coulomb_reg"
read -p "Enter the number of the desired friction law (1-3): " friction_choice

# Determine friction law and default beta_coeff
case $friction_choice in
    1)
        friction_law="weertman1"
        default_beta="beta_1"
        ;;
    2)
        friction_law="weertman3"
        default_beta="beta_3"
        ;;
    3)
        friction_law="coulomb_reg"
        default_beta="beta_cr"
        ;;
    *)
        echo "Invalid choice. Exiting."
        return 1 2>/dev/null || exit 1
        ;;
esac

# Ask if user wants to override the default beta_coeff
read -p "Default beta coefficient is '$default_beta'. Do you want to override it? (y/n): " override
if [[ "$override" =~ ^[Yy]$ ]]; then
    read -p "Enter custom beta coefficient variable name: " beta_coeff
else
    beta_coeff=$default_beta
fi


echo "Initial State File:"
echo "  1) restart_ant50.gl1.init_2000-2015.nc"
echo "  2) restart_ant50.gl1.init_2000-2015_dhdt.nc"
echo "  3) restart_ant50.gl1.init_2000-2015_CoulombReg.nc"
echo "  4) restart_ant50.gl1.init_2000-2015_CoulombReg_friction_corrected.nc"
read -p "Enter the initial state you want (default is (3)): " init_choice
init_choice=${init_choice:-3}


# Determine friction law and default beta_coeff
case $init_choice in
    1)
        init_file_name="restart_ant50.gl1.init_2000-2015.nc"
        ;;
    2)
        init_file_name="restart_ant50.gl1.init_2000-2015_dhdt.nc"
        ;;
    3)
        init_file_name="restart_ant50.gl1.init_2000-2015_CoulombReg.nc"
        ;;
    4)
        init_file_name="restart_ant50.gl1.init_2000-2015_CoulombReg_friction_corrected.nc"
        ;;
    *)
        echo "Invalid choice. Exiting."
        return 1 2>/dev/null || exit 1
        ;;
esac


# Convert input to uppercase
ssp=$(echo "$ssp" | tr '[:lower:]' '[:upper:]')
gcm=$(echo "$gcm" | tr '[:lower:]' '[:upper:]')
exp=$(echo "$exp" | tr '[:lower:]' '[:upper:]')
final_year=$(echo "$final_year" | tr '[:lower:]' '[:upper:]')
final_atmo_year=$(echo "$final_atmo_year" | tr '[:lower:]' '[:upper:]')

# Define source and target paths
source_folder="ANT50.GL1-ISMIP7"
target_folder="ANT50.GL1-${ssp}_${gcm}_EXP${exp}"

# Clone the folder
cp -rLf "$source_folder" "$target_folder"

# Copy the config_case_expXXX.FINAL_YEAR file
config_case_file="./CONFIG_CASES/config_case_exp${exp}.${final_year}"
if [ -f "$config_case_file" ]; then
    cp -f "$config_case_file" "$target_folder/config_case.txt"
    echo "Config file $config_case_file copied to $target_folder/"
else
    echo "Config file $config_case_file not found."
fi

# Modify the config_case.txt file
sed -i "s/<SSPXXX>/$ssp/g" "$target_folder/config_case.txt"
sed -i "s/<GCM>/$gcm/g" "$target_folder/config_case.txt"
sed -i "s/<EXPXXX>/EXP$exp/g" "$target_folder/config_case.txt"
sed -i "s/<FRICTION_LAW>/$friction_law/g" "$target_folder/config_case.txt"
sed -i "s/<BETA_COEFF>/$beta_coeff/g" "$target_folder/config_case.txt"
sed -i "s/<INITIAL_STATE_FILE>/$init_file_name/g" "$target_folder/config_case.txt"
sed -i "s/<AFINAL_DATE>/$final_atmo_year/g" "$target_folder/config_case.txt"
sed -i "s/<SIMULATION_END>/$final_year/g" "$target_folder/config_case.txt"

# Print success message
echo "Folder cloned successfully: $source_folder to $target_folder"
echo "Config file updated in $target_folder/config_case.txt"

# Enter the target_folder and run prepare_files.sh
cd "$target_folder" || exit
. ./prepare_files.bash

# Ask user if they want to run the simulation
read -p "Do you want to run the simulation? (y/n): " run_simulation

if [ "$run_simulation" != "n" ]; then
    # Run prepare_elmer.sh
    jobid0 = 333 #dummy number to insure no dependency at first run
    . ./prepare_elmer.bash
else
    echo "Simulation not executed. Exiting."
fi

