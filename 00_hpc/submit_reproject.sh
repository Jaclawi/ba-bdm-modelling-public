#!/usr/bin/env bash

#SBATCH --job-name=reproject
#SBATCH --partition=earth-3
#SBATCH --time=0-06:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=64GB

# Initialize micromamba
export OHPC_HOME=/cfs/earth/scratch/shared/adls-ohpc
export MAMBA_ROOT_PREFIX="/cfs/earth/scratch/wismecla/.conda"
export CONDA_ENVS_DIRS="${MAMBA_ROOT_PREFIX}/envs"
eval "$("${OHPC_HOME}/bin/micromamba" shell hook -s posix)"

micromamba activate r

# Run the script
cd /cfs/earth/scratch/wismecla/BA-BDM-modelling/BA-BDM-modeling

echo "Running Reprojecting of Tiff Layers..."
Rscript 03_geodata_processing/reproject_lv95.r

echo "Job completed successfully!"
