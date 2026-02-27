#!/usr/bin/env bash
#SBATCH -J nf-ONT
#SBATCH --partition=medium
#SBATCH --mem=8G
#SBATCH --cpus-per-task=2

# This script is a wrapper for running the nano-assembler-nf pipeline on a SLURM cluster.
# Usage: sbatch nano-assembler-nf.sh <samplesheet.csv> <output_dir> [extra nextflow flags]
# Example: sbatch nano-assembler-nf.sh samplesheet.csv ./output -resume

SAMPLESHEET=$1
OUT_DIR=$2
shift 2 # Move past the first two arguments

# Check if mandatory arguments are provided
if [[ -z "$SAMPLESHEET" || -z "$OUT_DIR" ]]; then
    echo "Usage: sbatch nano-assembler-nf.sh <samplesheet.csv> <output_dir> [extra nextflow flags]"
    exit 1
fi

source activate nextflow

nextflow run main.nf \
    -profile slurm,singularity \
    --input "$SAMPLESHEET" \
    --outdir "$OUT_DIR" \
    "$@"
