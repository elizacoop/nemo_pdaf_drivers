#!/bin/bash
#SBATCH --job-name=da_submit
#SBATCH --time=12:00:00
#SBATCH --output=da_submit_%j.out
#SBATCH --error=eda_submit_%j.err
#SBATCH --account=n01-CRISP
#SBATCH --partition=standard
#SBATCH --qos=standard

./main_driver.sh
