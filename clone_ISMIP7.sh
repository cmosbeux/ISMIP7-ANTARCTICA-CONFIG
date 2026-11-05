#!/bin/bash


# Define source and target paths
source_folder="ANT50.GL1-ISMIP7-COLLAPSE"

echo '                                               '
echo '╔═════════════════════════════════════════════╗'
echo '║      ██╗███████╗███╗   ███╗██╗██████╗       ║'
echo '║      ██║██╔════╝████╗ ████║██║██╔══██╗      ║'
echo '║      ██║███████╗██╔████╔██║██║██████╔╝      ║'
echo '║      ██║╚════██║██║╚██╔╝██║██║██╔═══╝       ║'
echo '║      ██║███████║██║ ╚═╝ ██║██║██║           ║'
echo '║      ╚═╝╚══════╝╚═╝     ╚═╝╚═╝╚═╝           ║'
echo '║                                             ║'
echo '║                 ┌───────┐                   ║'
echo '║                 └─────┐ │                   ║'
echo '║                       │ │                   ║'
echo '║                       │ │                   ║'
echo '║                       │ │                   ║'
echo '║                       └─┘                   ║'
echo '║       ELMER/ICE CONFIGURATION CLONER        ║'
echo '║                                             ║'
printf '║   Source folder: %-27.27s║\n' "$source_folder "
echo '╚═════════════════════════════════════════════╝'


# Prompt user for input
while true; do
    read -p "Enter scenario (OCX, HISTORICAL, SSP126, SSP370, SSP585, or CTRL): " ssp
    ssp=$(echo "$ssp" | tr '[:lower:]' '[:upper:]')
    case "$ssp" in
        OCX|HISTORICAL|SSP126|SSP370|SSP585|CTRL)
            break
            ;;
        *)
            echo "Invalid scenario. Choose OCX, HISTORICAL, SSP126, SSP370, SSP585, or CTRL."
            ;;
    esac
done


read -p "Enter GCM (default CESM2-WACCM): " gcm
gcm=${gcm:-CESM2-WACCM}
read -p "Enter EXP (e.g., 004): " exp

read -p "Enter START YEAR (default is 2000 for HISTORICAL and 2015 for SSPs): " start_year
if [[ -z "$start_year" ]]; then
    if [[ "$ssp" == "HISTORICAL" ]]; then
        start_year=2000
    else
        start_year=2015
    fi
fi

read -p "Enter FINAL YEAR (default is 2014 for HISTORICAL and 2300 for SSPs): " final_year
if [[ -z "$final_year" ]]; then
    if [[ "$ssp" == "HISTORICAL" ]]; then
        final_year=2014
    else
        final_year=2300
    fi
fi


if [[ "$ssp" == "HISTORICAL" ]]; then
    initial_ocean_year=1850
    initial_atmo_year=1850
else
    initial_ocean_year=2015
    initial_atmo_year=2015
fi

final_ocean_year=$final_year
final_atmo_year=$final_year
final_collapse_year=$final_year

# Prompt user for friction law
echo "Choose a friction law:"
echo "  1) weertman1"
echo "  2) weertman3"
echo "  3) coulomb_reg"
read -p "Enter the number of the desired friction law (1-3: default is 3): " friction_choice
friction_choice=${friction_choice:-3}

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

# Determine initial state file
echo "Initial State File:"
if [[ "$ssp" == "HISTORICAL" || "$ssp" == "OCX" ]]; then
    init_file_name="restart_ant50.gl1.init_2000-2015_CoulombReg_beta_gradual0.1.nc"
    echo "  default: $init_file_name"
else
    init_file_name="ANT50.GL1-HISTORICAL_${gcm}_EXP${exp}.init.nc"
    echo "  default: $init_file_name"
    if [ ! -f "$init_file_name" ]; then
        printf '\033[1;33m  /|\   Warning: Initial state file %s does not exist.\n' "$init_file_name"
        printf ' / ! \  Please make sure the file exists before proceeding.\033[0m\n'

    fi
fi


# Melt Parameters
read -p "OCEAN PARAMETERIZATION (default: PICO): " ocean_param
ocean_param=${ocean_param:-PICO}

# Prompt user for ocean parameterization and related melt parameters
# default values have been optimized with ISMIP7 MIPkit
if [[ "$ocean_param" =~ ^[Pp][Ii][Cc][Oo]$ ]]; then
    ocean_param="PICO"
    read -p "Overturning value (default: 2.5.e6): " overturning
    overturning=${overturning:-2.5e6}
    read -p "Heat flux value (default: 2e-5): " heatflux
    heatflux=${heatflux:-2e-5}  
fi



# Convert input to uppercase
ssp=$(echo "$ssp" | tr '[:lower:]' '[:upper:]')
gcm=$(echo "$gcm" | tr '[:lower:]' '[:upper:]')
exp=$(echo "$exp" | tr '[:lower:]' '[:upper:]')
final_year=$(echo "$final_year" | tr '[:lower:]' '[:upper:]')
final_ocean_year=$(echo "$final_ocean_year" | tr '[:lower:]' '[:upper:]')
final_atmo_year=$(echo "$final_atmo_year" | tr '[:lower:]' '[:upper:]')
final_collapse_year=$(echo "$final_collapse_year" | tr '[:lower:]' '[:upper:]')

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

sed -i "s/<OINITIAL_DATE>/$initial_ocean_year/g" "$target_folder/config_case.txt"
sed -i "s/<OFINAL_DATE>/$final_ocean_year/g" "$target_folder/config_case.txt"

sed -i "s/<AINITIAL_DATE>/$initial_atmo_year/g" "$target_folder/config_case.txt"
sed -i "s/<AFINAL_DATE>/$final_atmo_year/g" "$target_folder/config_case.txt"

sed -i "s/<CFINAL_DATE>/$final_collapse_year/g" "$target_folder/config_case.txt"

sed -i "s/<SIMULATION_END>/$final_year/g" "$target_folder/config_case.txt"
sed -i "s/<OVERTURNING>/$overturning/g" "$target_folder/config_case.txt"
sed -i "s/<HEAT_FLUX>/$heatflux/g" "$target_folder/config_case.txt"


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
    jobid0=333 # dummy number to ensure no dependency at first run
    . ./prepare_elmer.bash
else
    echo "Simulation not executed. Exiting."
