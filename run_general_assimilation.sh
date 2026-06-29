#!/bin/bash

set -euo pipefail


wait_for_job() {
    local id="$1"

    while true; do
        state=$(sacct -j "$id" --format=State --noheader 2>/dev/null | tr -d ' ')

        if [[ -z "$state" ]] || [[ "$state" =~ RUNNING|PENDING ]]; then
            echo "Waiting for job $id..."
            sleep 60
        else
            break
        fi
    done

    if sacct -j "$id" --format=State --noheader 2>/dev/null | \
        grep -qE "FAILED|CANCELLED|TIMEOUT"; then
        echo "ERROR: job $id failed — exiting"
        exit 1
    fi

    echo "Job $id done"
}


FILE="namelist_cfg.pdaf" #we need to specify some things in here
NC_STEP=$5

#"$OUTDIR" "$PREFIX" "$OUTSTRING" "$OUTICESTRING" "$ASSIM_TIME" "$OBSFILE"


    DST="../CRISP_NEMO_PDAF/CRISP_NEMO_PDAF_1/nemo-pdaf/src" #cleaner to do in place
    RESTART_STRING=$3
    RESTART_ICE_STRING=$4
    RESTART_OUT_DIR=$1
    DIR_AMMENDED="${RESTART_OUT_DIR#./}/" #just ammended for syntax
    PREFIX=$2
    OBS_FILE=$6
    MEMBERS=$7

    
jobid=$(cd "$DST"
  #OUTPUT NAME THINGs
  sed -i "s/dim_ens\s*=\s*[0-9]*/dim_ens = ${MEMBERS}/" "$FILE"
  sed -i "s/nc_step\s*=\s*[0-9]*/nc_step = ${NC_STEP}/" "$FILE"      #set nc_step
  #sed -i "s/f_basename_rst\s*=\s*[0-9]*/path_rst_suffix = "RESTART_ICE_STRING"" "$FILE"      #restart ice string
  sed -i "s|f_basename_rst[[:space:]]*=[[:space:]]*'[^']*'|f_basename_rst = '${PREFIX}${RESTART_STRING}'|" "$FILE" #restart string NOT ICE
  sed -i "s|path_rst_suffix[[:space:]]*=[[:space:]]*'[^']*'|path_rst_suffix = '${DIR_AMMENDED}'|" "$FILE" #restart ice folder
  sed -i "s|rst_file[[:space:]]*=[[:space:]]*'[^']*'|rst_file = '${PREFIX}${RESTART_ICE_STRING}'|" "$FILE" #restart ICE string
  sed -i "s|file_ssh_mgrid[[:space:]]*=[[:space:]]*'[^']*'|file_ssh_mgrid = '${OBS_FILE}'|" "$FILE" #observation file


  sbatch --parsable run_pdaf.sh)

echo "Assimilation job $jobid submitted"
echo "Waiting for assimilation to complete"

wait_for_job "$jobid"

echo "Assimilation done!"

