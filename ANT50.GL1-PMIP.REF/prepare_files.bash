#!/bin/bash

# Read the values of CONFIG and CASE from config_case.txt
#head -n 3 prepare_elmer.bash | tail -n 2 > config.txt
source config_case.txt

# Combine CONFIG and CASE to form the NEW_PREFIX
NEW_PREFIX="${CONFIG}-${CASE}"
PREFIX="ANT50.GL1-SSPXXX_GCM_RCM_EXPXXX"

# Loop through files starting with the original CONFIG value and rename them
for file in ${PREFIX}*; do
    if [ -f "$file" ]; then
        # Get the current filename without the prefix
        current_name="${file#${PREFIX}}"

        # Create the new filename with the new prefix
        new_name="${NEW_PREFIX}${current_name}"

        # Rename the file
        mv "$file" "$new_name"
        echo "Renamed $file to $new_name"
    fi
done

# Replace "REF" with the value of CASE in .incf
if [ -f "${NEW_PREFIX}_elmer.incf" ]; then
    # Replace "REF" with the value of CASE in the text file
    
    sed -i "s/${PREFIX}/${NEW_PREFIX}/g" "${NEW_PREFIX}_elmer.incf"
    echo "  Replaced '${PREFIX}' with '${NEW_PREFIX}' in ${NEW_PREFIX}_elmer.incf"
    
    sed -i "s/GCM/${GCM}/g" "${NEW_PREFIX}_elmer.incf"
    echo "  Setup GCM to: ${GCM}"
    
    sed -i "s/RCM/${RCM}/g" "${NEW_PREFIX}_elmer.incf"
    echo "  Setup RCM to: ${RCM}"
    
    # take care of both lower and upper case 
    sed -i "s/SSPXXX/${SSPXXX}/g" "${NEW_PREFIX}_elmer.incf"
    sed -i "s/sspxxx/$(echo "${SSPXXX}" | tr '[:upper:]' '[:lower:]')/g" "${NEW_PREFIX}_elmer.incf"
    echo "  Setup SSP to: ${SSPXXX}"
    
    sed -i "s/EXPXXX/${EXPXXX}/g" "${NEW_PREFIX}_elmer.incf"
    echo "  Setup EXP to: ${EXPXXX}"

    sed -i "s/OINITIAL_DATE/${OINITIAL_DATE}/g" "${NEW_PREFIX}_elmer.incf"
    sed -i "s/OFINAL_DATE/${OFINAL_DATE}/g" "${NEW_PREFIX}_elmer.incf"
    echo "  Setup ocean forcing date over : ${OINITIAL_DATE}-${OFINAL_DATE}"
    
    sed -i "s/AINITIAL_DATE/${AINITIAL_DATE}/g" "${NEW_PREFIX}_elmer.incf"
    sed -i "s/AFINAL_DATE/${AFINAL_DATE}/g" "${NEW_PREFIX}_elmer.incf"
    echo "  Setup atmospheric forcing date over: ${AINITIAL_DATE}-${AFINAL_DATE}"
fi


# Replace INITIAL_STATE in run param
if [ -f "run_param.bash" ]; then
    sed -i "s/INITIAL_STATE/${INITIAL_STATE}/g" "run_param.bash"
    echo "  Initial State: ${INITIAL_STATE}"

    #based on the final date of Atmo forcing, we fix the number_of_iterations
    if [ ${AFINAL_DATE} -eq 2050 ]; then
       sed -i "s/NB_MAX_ITERATION/2/g" "run_param.bash"
    elif [ ${AFINAL_DATE} -eq 2100 ]; then
       sed -i "s/NB_MAX_ITERATION/4/g" "run_param.bash"
    elif [ ${AFINAL_DATE} -eq 2200 ]; then
       sed -i "s/NB_MAX_ITERATION/8/g" "run_param.bash"
    else
       sed -i "s/NB_MAX_ITERATION/10/g" "run_param.bash"
    fi
fi

# include the right friction law .sif.
if [ -f "${NEW_PREFIX}_elmer.sif" ]; then
    #fix include issue with friction_law.param ? seems to now work as is...
    #sed -i "s/friction_law.param/friction_law.${FRICTION_LAW}/g" "${NEW_PREFIX}_elmer.sif"
    #fix is to directly copy the lines ffrom friction_law.param to the sif...
    #sed -e "/definition of the friction law/{
    #r FRICTION_PARAM/friction_law.${FRICTION_LAW}
    #N
    #s/.*\n//
    #}" -i ${NEW_PREFIX}_elmer.sif
   # setup the param in .sif

   sed -i "s/<FRICTION_LAW>/${FRICTION_LAW}/g"  "${NEW_PREFIX}_elmer.sif"   
   sed -i "s/<BETA_COEFF>/${BETA_COEFF}/g"  "${NEW_PREFIX}_elmer.sif"   
   echo "  Friction Law setup to: ${FRICTION_LAW}"
fi

# change PICO coefficients in the .param file
if [ -f "${NEW_PREFIX}_elmer.param" ]; then
    sed -i "s/OVERTURNING_VALUE/${OVERTURNING_VALUE}/g" "${NEW_PREFIX}_elmer.param"
    sed -i "s/HEAT_FLUX_VALUE/${HEAT_FLUX_VALUE}/g" "${NEW_PREFIX}_elmer.param"
    echo "  PICO parameter setup to: "
    echo "	-Overturning =  ${OVERTURNING_VALUE}"
    echo "	-Heat flux =  ${HEAT_FLUX_VALUE}"
fi
