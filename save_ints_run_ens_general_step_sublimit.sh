#!/bin/bash
set -euo pipefail

#SRC="./EXP00_template_rundir"
FILE="namelist_cfg"
FILEICE="namelist_ice_cfg"
START=1   #start is first ens number, end is final number
END=$9
BATCH_SIZE=8   # Maximum number of jobs to have in the queue at once

#order in main_driver: "$INDIR" "$INSTRING" "$INICESTRNG" "$OUTDIR" "$OUTSTRING" "$OUTICESTRING" "$NXTRNTS" "$START_STRING"

START_DATE=$8
NUM=$7
RESTART_STRING=$5
RESTART_ICE_STRING=$6
RESTART_OUT_DIR=$4
RESTART_IN_DIR=$1
RESTART_IN_STRING=$2
RESTART_IN_ICE_STRING=$3

REBUILD_NEMO="/work/n01/n01/elicoo/CRISP_NEMO_PDAF/CRISP_NEMO_PDAF_1/nemo_5.0.2/cfgs/exp-build-notop/rebuild_nemo.exe"

# Rebuild every restart set found in directory $1 (any *_NNNN.nc group), then delete its pieces to save space
rebuild_all_in_dir() {
    local dir=$1
    [[ -d "$dir" ]] || { echo "WARNING: $dir not found, skipping"; return 0; }

    shopt -s nullglob
    local all=("$dir"/*_[0-9][0-9][0-9][0-9].nc)
    shopt -u nullglob
    (( ${#all[@]} > 0 )) || { echo "No per-process restart pieces in $dir"; return 0; }

    # unique base names (path without _NNNN.nc; 'pre' now moved in the inc writing script)
    local -A seen=()
    local f
    for f in "${all[@]}"; do seen["${f%_[0-9][0-9][0-9][0-9].nc}"]=1; done

    local base bname pieces n
    for base in "${!seen[@]}"; do
        shopt -s nullglob
        pieces=("${base}"_[0-9][0-9][0-9][0-9].nc)
        shopt -u nullglob
        n=${#pieces[@]}
        bname=$(basename "$base")
                echo "Rebuilding $bname from $n pieces"
        (
          cd "$dir"
          cat > nam_rebuild <<EOF
&nam_rebuild
   filebase = '${bname}'
   ndomain  = ${n}
   l_maskout=.true.
/
EOF
          "$REBUILD_NEMO"
        ) || { echo "ERROR: rebuild_nemo failed for $bname"; return 1; }
        rm -f "$dir/nam_rebuild"
        if [[ ! -s "${base}.nc" ]]; then
            echo "ERROR: ${base}.nc missing or empty, keeping pieces"; return 1
        fi
        rm -f -- "${pieces[@]}"

     
        echo "Kept ${base}.nc, removed $n pieces"
    done
}

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

        dst="${job_dst[$id]}"
        # this job's INPUT folder so we don't need these for running nowww: the analysis and the pre copy from the previous cycle
        rebuild_all_in_dir "$dst/$RESTART_IN_DIR" || exit 1
    done
}

# ── Main submission loop ───────────────────────────────────────────────────────
job_ids=()
declare -A job_dst        # job_id -> directory the job ran in

for i in $(seq "$START" "$END"); do
    DST="../CRISP_NEMO_PDAF/CRISP_NEMO_PDAF_1/nemo_5.0.2/cfgs/exp-build-notop/ens${i}"

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
    
    echo "Submitted ensemble member $i as job $id"

    sleep 2
done

echo "All $((END - START + 1)) jobs submitted: ${job_ids[*]}"
echo "Waiting for all jobs to complete..."

wait_for_all

echo "All jobs complete!"
