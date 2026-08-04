#!/usr/bin/env bash
#SBATCH -J nf-ONT
#SBATCH --partition=long
#SBATCH --time=7-00:00:00
#SBATCH --mem=8G
#SBATCH --cpus-per-task=2
#SBATCH --output=slurm-nf-ONT-%j.out
#SBATCH --error=slurm-nf-ONT-%j.err

# This script is a wrapper for running the nano-assembler-nf pipeline on a SLURM cluster.
# Usage: sbatch nano-assembler-nf.sh <samplesheet.csv> <output_dir> [extra nextflow flags]
# Example: sbatch nano-assembler-nf.sh samplesheet.csv ./output -resume
#
# The head job only orchestrates; it sits idle while tasks run, so its wall time
# has to outlast the whole pipeline. Hence `long` rather than `medium` (24 h).

set -euo pipefail

if [[ $# -lt 2 ]]; then
    echo "Usage: sbatch nano-assembler-nf.sh <samplesheet.csv> <output_dir> [extra nextflow flags]" >&2
    exit 1
fi

SAMPLESHEET=$1
OUT_DIR=$2
shift 2 # Move past the first two arguments

# Extra profiles to append. Passing `-profile ...` in the extra flags would be a
# duplicate of the one below and silently win, dropping the slurm executor and
# running the whole pipeline on the head node. Use this instead:
#   EXTRA_PROFILES=test sbatch nano-assembler-nf.sh ...
PROFILES=slurm,singularity${EXTRA_PROFILES:+,${EXTRA_PROFILES}}

for arg in "$@"; do
    if [[ "$arg" == "-profile" || "$arg" == -profile=* ]]; then
        echo "ERROR: do not pass -profile directly; use EXTRA_PROFILES=<name> instead." >&2
        exit 1
    fi
done

# Optional databases. Export these before submitting, or pass --kraken2_db /
# --mito_db in the extra flags. Deliberately not defaulted to any path: the
# corresponding QC step is skipped when its database is not supplied.
#   KRAKEN2_DB=/path/to/k2_db MITO_DB=/path/to/mito_db sbatch nano-assembler-nf.sh ...
# See the README for how to obtain them.
DB_ARGS=()
[[ -n "${KRAKEN2_DB:-}" ]] && DB_ARGS+=(--kraken2_db "$KRAKEN2_DB")
[[ -n "${MITO_DB:-}" ]]    && DB_ARGS+=(--mito_db "$MITO_DB")

# Share one image cache across runs instead of re-pulling into each work dir.
export NXF_SINGULARITY_CACHEDIR=${NXF_SINGULARITY_CACHEDIR:-${APPTAINER_CACHEDIR:-$HOME/.apptainer}}

# Resolve the pipeline from this script's own location, so the job can be
# launched from any directory. Concurrent runs need separate launch dirs --
# they would otherwise contend for the same .nextflow cache locks.
#
# Under SLURM, $0 is the spooled copy in /var/spool/slurm/job<N>/, not the
# submitted path, so ask the controller where the script actually came from.
if [[ -z "${PIPELINE_DIR:-}" ]]; then
    if [[ -n "${SLURM_JOB_ID:-}" ]] && command -v scontrol >/dev/null 2>&1; then
        _script=$(scontrol show job "$SLURM_JOB_ID" | sed -n 's/.*Command=\([^ ]*\).*/\1/p' | head -1)
    fi
    : "${_script:=$0}"
    PIPELINE_DIR=$(dirname "$(readlink -f "$_script")")
fi

if [[ ! -f "${PIPELINE_DIR}/main.nf" ]]; then
    echo "ERROR: main.nf not found in '${PIPELINE_DIR}'. Set PIPELINE_DIR explicitly." >&2
    exit 1
fi

cd "${SLURM_SUBMIT_DIR:-$PWD}"

# sbatch exports the submitting shell's environment (--export=ALL by default).
# If a conda env was active there, its CONDA_* vars leak in and `source
# activate` resolves against the wrong prefix. Start from a clean slate.
unset CONDA_PREFIX CONDA_DEFAULT_ENV CONDA_SHLVL CONDA_PROMPT_MODIFIER CONDA_ENVS_PATH

source activate "${NEXTFLOW_ENV:-nextflow}"

nextflow run "${PIPELINE_DIR}/main.nf" \
    -profile "$PROFILES" \
    --input "$SAMPLESHEET" \
    --outdir "$OUT_DIR" \
    ${DB_ARGS[@]+"${DB_ARGS[@]}"} \
    "$@"
