# nano-assembler-nf

A Nextflow pipeline for the de novo assembly, polishing, and comprehensive quality control of Oxford Nanopore Technologies (ONT) long-read sequencing data.

---

## 🚀 Overview

**nano-assembler-nf** is designed for high throughput assembly of ONT data. It handles everything from raw read preprocessing to final consensus generation and multi-metric QC. It is optimised for HPC environments using SLURM and Singularity/Apptainer.

### **Key Features**
- **Modular DSL2 Architecture**: Clean separation of processes with dedicated subworkflows for Read QC, Assembly, and Post-Assembly QC.
- **Per-Sample Flexibility**: Specify unique genome sizes for every sample in a single run via a CSV samplesheet.
- **Automated Polishing**: Sequential polishing using Racon (mapping-based) and Medaka (neural network consensus).
- **Standardised Outputs**: Automated contig sorting (by length) and standardised renaming (`contig_1`, `contig_2`, etc.).
- **Comprehensive QC**:
    *   Read statistics (NanoPlot) and K-mer analysis (Jellyfish/GenomeScope2).
    *   Assembly completeness (BUSCO, Merqury) and structural metrics (GFAStats).
    *   Contamination check (Kraken2) and organelle identification (Mito BLAST).
    *   Coverage analysis and histograms (Mosdepth).
- **Reproducibility**: Integrated software version tracking for all tools, reported directly in the final MultiQC summary.

---

## 🛠 Installation

### **Requirements**
- Nextflow (>= 24.04.0)
- Java 11 or later
- Docker, Singularity/Apptainer, or Conda

### **Setup**
1. Clone the repository:
   ```bash
   git clone https://github.com/jnprice/nano-assembler-nf.git
   cd nano-assembler-nf
   ```
2. Configure your environment in `nextflow.config` (e.g., set your Kraken2 and Mito BLAST database paths).

---

## 📋 Usage

### **1. Prepare Samplesheet**
Create a `samplesheet.csv` with the following header and columns:
```csv
sample,fastq,genome_size
AJ858,/path/to/reads/AJ858.fastq.gz,60000000
SAMPLE2,/path/to/reads/sample2.fastq.gz,1500000
```

An optional fourth column, `illumina`, supplies short reads for that sample. Separate
multiple files with `;`:

```csv
sample,fastq,genome_size,illumina
AJ858,/path/to/AJ858.fastq.gz,60000000,/path/to/AJ858_R1.fq.gz;/path/to/AJ858_R2.fq.gz
SAMPLE2,/path/to/sample2.fastq.gz,1500000,
```

**Merqury only runs for samples with short reads.** Its QV compares the assembly against a
k-mer set that must be independent of it and more accurate — building that set from the same
ONT reads that produced the assembly measures self-consistency, not accuracy. Samples without
an `illumina` entry get no QV rather than a misleading one.

### **2. Run on HPC (SLURM)**
Use the provided wrapper script to submit the pipeline to your cluster:
```bash
sbatch nano-assembler-nf.sh samplesheet.csv ./results
```

### **3. Optional Arguments**
You can pass any standard Nextflow flags or pipeline parameters at the end of the command:
```bash
# Resume a failed run
sbatch nano-assembler-nf.sh samplesheet.csv ./results -resume

# Use a specific BUSCO lineage
sbatch nano-assembler-nf.sh samplesheet.csv ./results --lineage hypocreales_odb10

# Assemble with Flye instead of NECAT, and purge haplotigs from a diploid
sbatch nano-assembler-nf.sh samplesheet.csv ./results --assembler flye --purge_dups
```

### **4. Testing**

A `test` profile is provided, configured for the *Candida albicans* SC5314 reference isolate:

```bash
# Plumbing check: runs the whole DAG with stubbed processes in seconds
nextflow run main.nf -profile test,singularity -stub-run --outdir ./stub

# Full smoke test on the cluster
EXTRA_PROFILES=test sbatch nano-assembler-nf.sh assets/samplesheet_test.csv ./results_sc5314
```

The wrapper already sets `-profile slurm,singularity`; add profiles via `EXTRA_PROFILES`
rather than passing `-profile` again, which would override it and run everything on the
submit node.

Every process defines a `stub:` block, so `-stub-run` validates channel wiring, output
declarations and MultiQC staging without running any tool.

---

## 📂 Output Structure

The pipeline organises results into a clean, logical hierarchy:

```text
results/
├── <sample_id>/
│   ├── preprocessing/     # Porechop and Filtlong outputs
│   ├── assembly/          # Final polished & renamed assembly (.fasta)
│   │   ├── necat/         # Initial NECAT assembly (or flye/ with --assembler flye)
│   │   ├── purge_dups/    # Haplotig-purged assembly (only with --purge_dups)
│   │   └── racon/         # Racon polished intermediate
│   └── qc/
│       ├── nanoplot/      # Pre and post-filter read QC
│       ├── busco/         # Gene-set completeness
│       ├── coverage/      # Mosdepth depth distribution and summary
|       ├── gfastats/      # Assembly and contig statistics
|       ├── jellyfish/     # k-mer analysis of reads
│       ├── kraken2/       # Contamination reports
|       ├── merqury/       # k-mer analysis of assembly
│       ├── mito_check/    # Mitochondrial contig identification
|       ├── multiqc_tables/ # Custom-content tables for the MultiQC report
|       └── tapestry/      # Telomere predictions
├── multiqc/               # Aggregated MultiQC HTML report
└── pipeline_info/         # Execution reports, traces, and software versions
```

---

## 🗄️ Database Setup

The pipeline uses two external databases. **Both are optional** — no path is assumed or
defaulted, since database locations are site-specific. If you do not supply one, the QC step
that needs it is skipped and the rest of the pipeline runs normally:

| Parameter | Enables | Skipped if unset |
|---|---|---|
| `--kraken2_db` | Kraken2 contamination screening | `qc/kraken2/`, MultiQC Kraken section |
| `--mito_db` | Mitochondrial contig identification | `qc/mito_check/` |

A path that *is* supplied must exist — the run fails immediately on a typo rather than quietly
disabling the check.

### **1. Kraken2 Database**
Used for contamination screening. Download a pre-built database (see the
[index list](https://benlangmead.github.io/aws-indexes/k2)) — the 16 GB PlusPF build is a
reasonable default for fungal work:
```bash
mkdir -p /path/to/kraken2_db
wget https://genome-idx.s3.amazonaws.com/kraken/k2_pluspf_16gb_20240112.tar.gz
tar -xzvf k2_pluspf_16gb_20240112.tar.gz -C /path/to/kraken2_db/
```
Point `--kraken2_db` at the directory containing the `.k2d` files. Note the database is loaded
into memory, so the `KRAKEN2` process must be given at least its size (the 16 GB build is
configured for 18 GB).

### **2. Mitochondrial BLAST Database**
Used to identify organelle contigs. Build it from the NCBI RefSeq mitochondrion release:
```bash
mkdir -p /path/to/mito_db && cd /path/to/mito_db

# RefSeq mitochondrial genomes (two files at time of writing)
wget https://ftp.ncbi.nlm.nih.gov/refseq/release/mitochondrion/mitochondrion.1.1.genomic.fna.gz
wget https://ftp.ncbi.nlm.nih.gov/refseq/release/mitochondrion/mitochondrion.2.1.genomic.fna.gz
gunzip -c mitochondrion.*.genomic.fna.gz > mitochondrion.fna

# The database MUST be named `mito` -- the pipeline calls `-db <mito_db>/mito`
makeblastdb -in mitochondrion.fna -dbtype nucl -out mito
```
Point `--mito_db` at the directory. The `-out mito` name is not optional.

### **Supplying the paths**

Either pass them per run:
```bash
sbatch nano-assembler-nf.sh samplesheet.csv ./results \
    --kraken2_db /path/to/kraken2_db --mito_db /path/to/mito_db
```
or export them once, which the wrapper picks up:
```bash
export KRAKEN2_DB=/path/to/kraken2_db
export MITO_DB=/path/to/mito_db
sbatch nano-assembler-nf.sh samplesheet.csv ./results
```

---

## ⚙️ Configuration

The pipeline's behaviour can be tuned in `nextflow.config`, or overridden per run on the
command line. Key parameters include:
- `skip_porechop`: Skip adapter trimming, for reads already chopped or basecalled with dorado (default: false).
- `min_length`: Minimum read length for Filtlong (default: 1000).
- `min_mean_q`: Minimum mean quality for Filtlong (default: 90).
- `assembler`: `necat` or `flye` (default: necat).
- `coverage`: Target coverage for NECAT assembly (default: 80).
- `purge_dups`: Purge haplotigs after assembly, for heterozygous diploids (default: false).
- `model`: Medaka basecalling model (default: r1041_e82_400bps_sup_g615). Validated at startup.
- `lineage`: BUSCO lineage (default: ascomycota_odb10).
- `telomere`: Telomere repeat unit for Tapestry (default: TTAGGG). **Set this per species** —
  the default is the vertebrate motif and is wrong for fungi.
- `kraken2_db`: Path to the directory containing Kraken2 `.k2d` files. Optional; contamination
  screening is skipped if unset.
- `mito_db`: Path to the directory containing the BLAST database named `mito`. Optional;
  organelle identification is skipped if unset.

See [`REVIEW.md`](REVIEW.md) for a critique of tool choices and a prioritised improvement backlog.

---

## 📜 License
Distributed under the MIT License. See `LICENSE` for more information.
