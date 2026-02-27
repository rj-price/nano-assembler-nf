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
- Nextflow (>= 21.10.3)
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
```

---

## 📂 Output Structure

The pipeline organises results into a clean, logical hierarchy:

```text
results/
├── <sample_id>/
│   ├── preprocessing/     # Porechop and Filtlong outputs
│   ├── assembly/          # Final polished & renamed assembly (.fasta)
│   │   ├── necat/         # Initial NECAT assembly
│   │   └── racon/         # Racon polished intermediate
│   └── qc/
│       ├── nanoplot/      # Pre and post-filter read QC
│       ├── busco/         # Gene-set completeness
│       ├── coverage/      # Mosdepth stats and BAM index
|       ├── gfastats/      # Assembly and contig statistics
|       ├── jellyfish/     # k-mer analysis of reads
│       ├── kraken2/       # Contamination reports
|       ├── merqury/       # k-mer analysis of assembly
│       ├── mito_check/    # Mitochondrial contig identification
|       ├── nanoplot/      # Read metrics
|       └── tapestry/      # Telomere predictions
├── multiqc/               # Aggregated MultiQC HTML report
└── pipeline_info/         # Execution reports, traces, and software versions
```

---

## ⚙️ Configuration

The pipeline's behavior can be tuned in `nextflow.config`. Key parameters include:
- `min_length`: Minimum read length for Filtlong (default: 1000).
- `min_mean_q`: Minimum mean quality for Filtlong (default: 90).
- `coverage`: Target coverage for NECAT assembly (default: 80).
- `model`: Medaka basecalling model (default: r1041_e82_400bps_sup_g615).

---

## 📜 License
Distributed under the MIT License. See `LICENSE` for more information.
