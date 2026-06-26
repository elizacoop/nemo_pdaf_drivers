#!/bin/bash
set -euo pipefail

SRC="./EXP00_template_rundir"
FILE="namelist_cfg"
FILEICE="namelist_ice_cfg"
START=1
END=19
BATCH_SIZE=10   # Maximum number of jobs to have in the queue at once

START_DATE="20131223"
NUM="360"
RESTART_STRING="ens_step1"
RESTART_ICE_STRING="ens_ice_step1"
RESTART_OUT_DIR="./restart_step1"
RESTART_IN_DIR="./restart_step0"
RESTART_IN_STRING="ORCA2_00034848_ens_spin_toend2013"
RESTART_IN_ICE_STRING="ORCA2_00034848_ens_spin_ice_toend2013"

# ── Helper: wait until fewer than BATCH_SIZE jobs are running/pending ─────────
wait_for_slot() {
    while true; do
        # Count how many of our submitted jobs are still running or pending
        running=0
        for id in "${job_ids[@]}"; do
            state=$(sacct -j "$id" --format=State --noheader 2>/dev/null | tr -d ' ')
            if [[ -z "$state" ]] || echo "$state" | grep -qE "RUNNING|PENDING"; then
                running=$((running + 1))
            fi
        done

        if [[ "$running" -lt "$BATCH_SIZE" ]]; then
            echo "Slot available ($running / $BATCH_SIZE jobs active)"
            break
        else
            echo "$running / $BATCH_SIZE jobs active, waiting for a slot..."
            sleep 60
        fi
    done
}

# ── Helper: wait for all remaining jobs to finish ─────────────────────────────
wait_for_all() {
    for id in "${job_ids[@]}"; do
        while true; do
            state=$(sacct -j "$id" --format=State --noheader 2>/dev/null | tr -d ' ')
            if [[ -z "$state" ]] || echo "$state" | grep -qE "RUNNING|PENDING"; then
                echo "Waiting for job $id..."
                sleep 60
            else
                break
            fi
        done

        # Check for failure
        if sacct -j "$id" --format=State --noheader 2>/dev/null | grep -qE "FAILED|CANCELLED|TIMEOUT"; then
            echo "ERROR: job $id failed — exiting"
            exit 1
        fi

        echo "Job $id done"
    done
}

# ── Main submission loop ───────────────────────────────────────────────────────
job_ids=()

for i in $(seq "$START" "$END"); do
    DST="../CRISP_NEMO_PDAF/CRISP_NEMO_PDAF_1/nemo_5.0.1/cfgs/exp-build-notop/ens_${i}"

    # Wait until there is a free slot before submitting
    wait_for_slot

    echo "Submitting ensemble member $i..."

    id=$(
        cd "$DST" || { echo "Failed to cd to $DST"; exit 1; }

        mkdir -p "$RESTART_OUT_DIR"
	
	#run settings
	sed -i "s/nn_itend\s*=\s*[0-9]*/nn_itend = ${NUM}/" "$FILE" 
	sed -i "s/nn_date0\s*=\s*[0-9]*/nn_date0 = ${START_DATE}/" "$FILE"

        # Output settings
        #sed -i "s/nn_itend\s*=\s*[0-9]*/nn_itend = ${NUM}/"                                               "$FILE"
        sed -i "s|cn_ocerst_outdir[[:space:]]*=[[:space:]]*\"[^\"]*\"|cn_ocerst_outdir = \"${RESTART_OUT_DIR}\"|" "$FILE"
        sed -i "s|cn_icerst_outdir[[:space:]]*=[[:space:]]*\"[^\"]*\"|cn_icerst_outdir = \"${RESTART_OUT_DIR}\"|" "$FILEICE"
        sed -i "s|cn_ocerst_out[[:space:]]*=[[:space:]]*\"[^\"]*\"|cn_ocerst_out = \"${RESTART_STRING}\"|"        "$FILE"
        sed -i "s|cn_icerst_out[[:space:]]*=[[:space:]]*\"[^\"]*\"|cn_icerst_out = \"${RESTART_ICE_STRING}\"|"    "$FILEICE"

        # Input settings
        sed -i "s|cn_ocerst_indir[[:space:]]*=[[:space:]]*\"[^\"]*\"|cn_ocerst_indir = \"${RESTART_IN_DIR}\"|"   "$FILE"
        sed -i "s|cn_icerst_indir[[:space:]]*=[[:space:]]*\"[^\"]*\"|cn_icerst_indir = \"${RESTART_IN_DIR}\"|"   "$FILEICE"
        sed -i "s|cn_ocerst_in[[:space:]]*=[[:space:]]*\"[^\"]*\"|cn_ocerst_in = \"${RESTART_IN_STRING}\"|"      "$FILE"
        sed -i "s|cn_icerst_in[[:space:]]*=[[:space:]]*\"[^\"]*\"|cn_icerst_in = \"${RESTART_IN_ICE_STRING}\"|"  "$FILEICE"

        sbatch --parsable myscript_short.slurm
    )

    job_ids+=("$id")
    echo "Submitted ensemble member $i as job $id"

    # Brief pause to avoid hammering the scheduler
    sleep 2
done

echo "All $((END - START + 1)) jobs submitted: ${job_ids[*]}"
echo "Waiting for all jobs to complete..."

wait_for_all

echo "All jobs complete!"
