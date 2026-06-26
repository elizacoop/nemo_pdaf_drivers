#!/bin/bash
#SBATCH --job-name=ensemble_submit
#SBATCH --time=00:19:50
#SBATCH --output=ensemble_submit_%j.out
#SBATCH --error=ensemble_submit_%j.err
#SBATCH --account=n01-CRISP
#SBATCH --partition=standard
#SBATCH --qos=short

#./run_ens_spin.sh
./run_ens_step_sublimit.sh
