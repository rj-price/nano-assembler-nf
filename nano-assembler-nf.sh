#!/usr/bin/env bash
#SBATCH -J nf-ONT
#SBATCH --partition=medium
#SBATCH --mem=8G
#SBATCH --cpus-per-task=2

# This script is a wrapper for running the nano-assembler-nf pipeline on a SLURM cluster.
# Usage: sbatch nano-assembler-nf.sh <samplesheet.csv> <genome_size> <output_dir>

SAMPLESHEET=$1
GENOME_SIZE=$2
OUT_DIR=$3

# Check if mandatory arguments are provided
if [[ -z "$SAMPLESHEET" || -z "$GENOME_SIZE" || -z "$OUT_DIR" ]]; then
    echo "Usage: sbatch nano-assembler-nf.sh <samplesheet.csv> <genome_size> <output_dir>"
    exit 1
fi

source activate nextflow

nextflow run main.nf \
    -profile slurm,singularity \
    --input "$SAMPLESHEET" \
    --genome_size "$GENOME_SIZE" \
    --outdir "$OUT_DIR" \
    -resume \
    "$@"
