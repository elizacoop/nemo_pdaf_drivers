#!/bin/bash
set -euo pipefail

SRC="./EXP00_template_rundir"
FILE="namelist_cfg"
FILEICE="namelist_ice_cfg"
START=1   #start is first ens number, end is final number
END=$9
BATCH_SIZE=10   # Maximum number of jobs to have in the queue at once

#order in main_driver: "$INDIR" "$INSTRING" "$INICESTRNG" "$OUTDIR" "$OUTSTRING" "$OUTICESTRING" "$NXTRNTS" "$START_STRING"

START_DATE=$8
NUM=$7
RESTART_STRING=$5
RESTART_ICE_STRING=$6
RESTART_OUT_DIR=$4
RESTART_IN_DIR=$1
RESTART_IN_STRING=$2
RESTART_IN_ICE_STRING=$3

# Where to archive the output.init_* files (which get overwritten in the
# rundir on every cycle). Adjust to wherever you want these to live.
INIT_ARCHIVE_ROOT="./output_init_archive"

# ── Helper: wait until fewer than BATCH_SIZE jobs are running/pending ─────────
wait_for_slot() {
    while true; do
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

# ── Helper: wait for all remaining jobs to finish, then archive init files ────
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

        if sacct -j "$id" --format=State --noheader 2>/dev/null | grep -qE "FAILED|CANCELLED|TIMEOUT"; then
            echo "ERROR: job $id failed — exiting"
            exit 1
        fi

        echo "Job $id done"

        # ── Archive this job's output.init_* files before the next cycle
        #    overwrites them in the rundir ─────────────────────────────────
        dst="${job_dst[$id]}"
        init_out="${job_init_out[$id]}"
        mkdir -p "$init_out"

        shopt -s nullglob
        init_files=("$dst"/output.init_*.nc)
        shopt -u nullglob

        if [[ ${#init_files[@]} -gt 0 ]]; then
            echo "Archiving ${#init_files[@]} output.init_* file(s) for job $id -> $init_out"
            mv "${init_files[@]}" "$init_out"/
        else
            echo "WARNING: no output.init_* files found in $dst for job $id"
        fi
    done
}

# ── Main submission loop ───────────────────────────────────────────────────────
job_ids=()
declare -A job_dst        # job_id -> directory the job ran in
declare -A job_init_out   # job_id -> destination for output.init_* archive

for i in $(seq "$START" "$END"); do
    DST="../CRISP_NEMO_PDAF/CRISP_NEMO_PDAF_1/nemo_5.0.1/cfgs/exp-build-notop/ens_${i}"

    wait_for_slot

    echo "Submitting ensemble member $i..."

    id=$(
        cd "$DST" || { echo "Failed to cd to $DST"; exit 1; }

        mkdir -p "$RESTART_OUT_DIR"

        #run settings
        sed -i "s/nn_itend\s*=\s*[0-9]*/nn_itend = ${NUM}/" "$FILE"
        sed -i "s/nn_date0\s*=\s*[0-9]*/nn_date0 = ${START_DATE}/" "$FILE"

        # Output settings
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
    job_dst["$id"]="$DST"
    job_init_out["$id"]="${INIT_ARCHIVE_ROOT}/ens_${i}/${RESTART_IN_STRING}"
    echo "Submitted ensemble member $i as job $id"

    sleep 2
done

echo "All $((END - START + 1)) jobs submitted: ${job_ids[*]}"
echo "Waiting for all jobs to complete..."

wait_for_all

echo "All jobs complete!"
