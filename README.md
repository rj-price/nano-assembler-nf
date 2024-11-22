# nano-assembler-nf
A Nextflow pipeline to assemble Oxford Nanopore long WGS reads, and perform QC and variant calling.


# To Do:
- Add coverage histogram(s)
- Add SNP & sv vs ref
- Add filter & rename contigs
- Add repeats analysis
- Add Flye (and longstitch)?
- Add help message in [main.nf](http://main.nf) and documentation of usage in repo
- Add setup script (check & install conda/nextflow on hpc), config file, conditionals to submission script (needed? write simple bash pipeline to check)
- Add samplesheet integration to process multiple samples

## Test:

```bash
sbatch nano-assembler-nf.sh ~/scratch/private/yeasties/ONT_assemblies/barcode05/barcode05.fastq.gz 10000000 ./output
```

## Done:
- Add nanoplot (pre & post filter)
- Add kmer analysis (pre & post assembly)
- Add contamination check (kraken2)
- Add organelle check (mito blast)
- Add dotplot against ref (last)