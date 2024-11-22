#!/usr/bin/env bash
#SBATCH -J nf-ONT
#SBATCH --partition=medium
#SBATCH --mem=8G
#SBATCH --cpus-per-task=2

# INPUTS
ReadsDir=$1
GenomeSize=$2
OutDir=$3

source activate nextflow

nextflow run main.nf -c ~/cropdiv.config \
    --reads_dir $ReadsDir \
    --genome_size $GenomeSize \
    --outdir $OutDir \
    -resume