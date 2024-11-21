process MITO_CHECK {
    container 'community.wave.seqera.io/library/blast_seqtk:9cca2195d54cc9d0'
    publishDir "${params.outdir}/${params.prefix}/mito_check", mode: 'copy'
    cpus = 2
    memory = { 4.GB * task.attempt }
    queue = 'short'

    input:
    tuple val(sample_id), path(assembly)
    path mito_db

    output:
    path "${params.prefix}_mito_blast.txt", emit: blast_results
    path "${params.prefix}_mito_contigs.fasta", emit: mito_contigs
    path "${params.prefix}_mito_summary.txt", emit: summary

    script:
    """
    # Run BLAST
    blastn -query ${assembly} \
           -db ${mito_db}/mito \
           -outfmt "6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore qlen slen" \
           -num_threads ${task.cpus} \
           -max_target_seqs 3 \
           -evalue 1e-6 \
           -out ${params.prefix}_mito_blast.txt

    # Extract mitochondrial contigs
    awk '\$3 >= 90 && \$4 >= 2000' ${params.prefix}_mito_blast.txt | cut -f1 | sort | uniq > mito_contig_ids.txt
    seqtk subseq ${assembly} mito_contig_ids.txt > ${params.prefix}_mito_contigs.fasta

    # Generate summary
    echo "Potential mitochondrial contigs:" > ${params.prefix}_mito_summary.txt
    grep ">" ${params.prefix}_mito_contigs.fasta | sed 's/>//' >> ${params.prefix}_mito_summary.txt
    echo "" >> ${params.prefix}_mito_summary.txt
    echo "Number of potential mitochondrial contigs: \$(grep -c ">" ${params.prefix}_mito_contigs.fasta)" >> ${params.prefix}_mito_summary.txt
    """
}