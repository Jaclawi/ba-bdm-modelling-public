#!/usr/bin/env bash

#SBATCH --job-name=rasterize-hab-map
#SBATCH --partition=earth-3
#SBATCH --time=0-04:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=48GB

# Initialize micromamba
export OHPC_HOME=/cfs/earth/scratch/shared/adls-ohpc
export MAMBA_ROOT_PREFIX="/cfs/earth/scratch/wismecla/.conda"
export CONDA_ENVS_DIRS="${MAMBA_ROOT_PREFIX}/envs"
eval "$("${OHPC_HOME}/bin/micromamba" shell hook -s posix)"

micromamba activate r

# Run the script
echo "Running Habitat Type rasterization..."
Rscript ./geodata_processing/rasterize_habitatmap.r

echo "Job completed successfully!"
