#!/usr/bin/env bash

#SBATCH --job-name=interpolate-kobo-soil
#SBATCH --partition=earth-3
#SBATCH --time=0-06:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=128GB

# Initialize micromamba
export OHPC_HOME=/cfs/earth/scratch/shared/adls-ohpc
export MAMBA_ROOT_PREFIX="/cfs/earth/scratch/wismecla/.conda"
export CONDA_ENVS_DIRS="${MAMBA_ROOT_PREFIX}/envs"
eval "$("${OHPC_HOME}/bin/micromamba" shell hook -s posix)"

micromamba activate r

# Run the script
echo "Running Kobo Soil interpolation..."
cd /cfs/earth/scratch/wismecla/BA-BDM-modelling/BA-BDM-modeling
Rscript 03_geodata_processing/interpolate_kobo_soil.r

echo "Job completed successfully!"
