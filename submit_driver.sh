#!/bin/bash
#SBATCH --job-name=da_submit
#SBATCH --time=95:59:59
#SBATCH --output=da_submit_%j.out
#SBATCH --error=eda_submit_%j.err
#SBATCH --account=n01-CRISP
#SBATCH --partition=standard
#SBATCH --qos=long

./orca1_driver.sh 8 true
