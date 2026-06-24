#!/bin/bash

set -euo pipefail


FILE="namelist_cfg.pdaf" #we need to specify some things in here
NC_STEP=77 #will need to make this a LOOPING INDEX

    DST="../CRISP_NEMO_PDAF/CRISP_NEMO_PDAF_1/nemo-pdaf/src" #cleaner to do in place
    RESTART_STRING="ens_spin_toend2013"
    RESTART_ICE_STRING="ens_spin_ice_toend2013"
    RESTART_OUT_DIR="./restart_step0"
    DIR_AMMENDED="${RESTART_OUT_DIR#./}/" #just ammended for syntax
    PREFIX="ORCA2_00034848_"
    OBS_FILE='/work/n01/n01/elicoo/observations/data_v3_2010-2023.nc'
    #RESTART_IN_DIR="./restart_end_spin"
    #RESTART_IN_STRING="ORCA2_00175200_restart_2010"
    #RESTART_IN_ICE_STRING="ORCA2_00175200_restart_ice_2010"

    
  (cd "$DST"
  #OUTPUT NAME THINGs
  sed -i "s/nc_step\s*=\s*[0-9]*/nc_step = ${NC_STEP}/" "$FILE"      #set nc_step
  #sed -i "s/f_basename_rst\s*=\s*[0-9]*/path_rst_suffix = "RESTART_ICE_STRING"" "$FILE"      #restart ice string
  sed -i "s|f_basename_rst[[:space:]]*=[[:space:]]*'[^']*'|f_basename_rst = '${PREFIX}${RESTART_STRING}'|" "$FILE" #restart string NOT ICE
  sed -i "s|path_rst_suffix[[:space:]]*=[[:space:]]*'[^']*'|path_rst_suffix = '${DIR_AMMENDED}'|" "$FILE" #restart ice folder
  sed -i "s|rst_file[[:space:]]*=[[:space:]]*'[^']*'|rst_file = '${PREFIX}${RESTART_ICE_STRING}'|" "$FILE" #restart ICE string
  sed -i "s|file_ssh_mgrid[[:space:]]*=[[:space:]]*'[^']*'|file_ssh_mgrid = '${OBS_FILE}'|" "$FILE" #observation file


  sbatch run_pdaf.sh)

echo "Assimilation job submitted"

