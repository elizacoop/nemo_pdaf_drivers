#!/bin/bash

set -euo pipefail

SRC="./EXP00_template_rundir"
FILE="namelist_cfg"
FILEICE="namelist_ice_cfg"

START=9
END=10

job_ids=()

for i in $(seq "$START" "$END"); do
    NUM="34848"

    #DST="../nemo_5.0.1/cfgs/exp-build-notop/ens_${i}" OLD PATH
    DST="../CRISP_NEMO_PDAF/CRISP_NEMO_PDAF_1/nemo_5.0.1/cfgs/exp-build-notop/ens_${i}"
    RESTART_STRING="ens_spin_toend2013"
    RESTART_ICE_STRING="ens_spin_ice_toend2013"
    RESTART_OUT_DIR="./restart_step0"
    RESTART_IN_DIR="./restart_end_spin"
    RESTART_IN_STRING="ORCA2_00175200_restart_2010"
    RESTART_IN_ICE_STRING="ORCA2_00175200_restart_ice_2010"

id=$( 
(
  cd "$DST"
  #OUTPUT NAME THINGS
  mkdir -p "$RESTART_OUT_DIR"
  sed -i "s/nn_itend\s*=\s*[0-9]*/nn_itend = ${NUM}/" "$FILE"      #set no.timesteps
  #sed -i "s/cn_ocerst_outdir\s*=\s*[0-9]*/cn_ocerst_outdir = "RESTART_OUT"" "$FILE"      #restart output folder ocean
  sed -i "s|cn_ocerst_outdir[[:space:]]*=[[:space:]]*\"[^\"]*\"|cn_ocerst_outdir = \"${RESTART_OUT_DIR}\"|" "$FILE"
  sed -i "s|cn_icerst_outdir[[:space:]]*=[[:space:]]*\"[^\"]*\"|cn_icerst_outdir = \"${RESTART_OUT_DIR}\"|" "$FILEICE"   #restart output folder ice
  #sed -i "s/cn_ocerst_out\s*=\s*[0-9]*/cn_ocerst_out = "RESTART_STRING"" "$FILE"      #restart filestring ocean (out)
  sed -i "s|cn_ocerst_out[[:space:]]*=[[:space:]]*\"[^\"]*\"|cn_ocerst_out = \"${RESTART_STRING}\"|" "$FILE"
  sed -i "s|cn_icerst_out[[:space:]]*=[[:space:]]*\"[^\"]*\"|cn_icerst_out = \"${RESTART_ICE_STRING}\"|" "$FILEICE"   #restart filestring ice   (out)


  #INPUT NAME THINGS
  sed -i "s|cn_ocerst_indir[[:space:]]*=[[:space:]]*\"[^\"]*\"|cn_ocerst_indir = \"${RESTART_IN_DIR}\"|" "$FILE"
  sed -i "s|cn_icerst_indir[[:space:]]*=[[:space:]]*\"[^\"]*\"|cn_icerst_indir = \"${RESTART_IN_DIR}\"|" "$FILEICE"   #restart INput folder ice
  sed -i "s|cn_ocerst_in[[:space:]]*=[[:space:]]*\"[^\"]*\"|cn_ocerst_in = \"${RESTART_IN_STRING}\"|" "$FILE"
  sed -i "s|cn_icerst_in[[:space:]]*=[[:space:]]*\"[^\"]*\"|cn_icerst_in = \"${RESTART_IN_ICE_STRING}\"|" "$FILEICE"   #restart filestring ice   (in)


  sbatch --parsable myscript_exp03.slurm
  #job_ids+=(id)
  #echo "Submitted job $id"
  ))

job_ids+=("$id")
echo "Submitted job $id"


done

echo "All jobs submitted"
#allow some time for the jobs to submit
sleep 30

echo "jobs ${job_ids[@]}"

for id in "${job_ids[@]}";do
	#while squeue -j $id &> /dev/null;do
	while sacct -j "$id" --format=State --noheader | grep -qE "RUN|PEND"; do
		echo "Waiting for job $id..."
		sleep 180
	done
	echo "job $id done"
	done

echo "All jobs complete!"

