#!/usr/bin/env bash

export CFS_HOME=/cfs/earth/scratch/${USER}
export OHPC_HOME=/cfs/earth/scratch/shared/adls-ohpc

export MAMBA_ROOT_PREFIX="${OHPC_HOME:?}/.conda"
export CONDA_ENVS_DIRS=${MAMBA_ROOT_PREFIX:?}/envs
eval "$("${OHPC_HOME:?}/bin/micromamba" shell hook -s posix)"