# nano-assembler-nf
A Nextflow pipeline to assemble Oxford Nanopore long WGS reads, and perform QC and variant calling.

**\#\#\# WORK IN PROGRESS \#\#\#**

## To Do:
- Add sort & rename contigs (should come immediately after medaka)
- Add coverage histogram(s)
- Add SNP & sv vs ref
- Add repeats analysis
- Add Flye (and longstitch)?
- Add help message in `main.nf` and documentation of usage in repo
- Add setup script (check & install conda/nextflow on hpc), config file, conditionals to submission script (needed? write simple bash pipeline to check)
- Add samplesheet integration to process multiple samples

## Test:
- Add Tapestry (https://github.com/johnomics/tapestry)

```bash
sbatch nano-assembler-nf.sh /mnt/shared/projects/niab/jnprice/UoK/porechop/791_SN152.fastq.gz 15000000 ./output
```

## Done:
- Add nanoplot (pre & post filter)
- Add kmer analysis (pre & post assembly)
- Add contamination check (kraken2)
- Add organelle check (mito blast)
- Add dotplot against ref (last)