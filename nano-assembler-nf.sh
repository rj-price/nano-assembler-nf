#!/usr/bin/env bash
#SBATCH -J nf-ONT
#SBATCH --partition=long
#SBATCH --mem=8G
#SBATCH --cpus-per-task=2

# INPUTS
ReadsDir=$1
GenomeSize=$2
OutDir=$3

export MYCONDAPATH=/mnt/shared/scratch/jnprice/apps/conda
source ${MYCONDAPATH}/bin/activate nextflow

nextflow run main.nf -c ~/cropdiv.config \
    --reads_dir $ReadsDir \
    --genome_size $GenomeSize \
    --outdir $OutDir