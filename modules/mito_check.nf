process MITO_CHECK {
    container 'community.wave.seqera.io/library/blast_seqtk:9cca2195d54cc9d0'
    publishDir "${params.outdir}/${sample_id}/qc/mito_check", mode: 'copy'

    input:
    tuple val(sample_id), path(assembly)
    path mito_db

    output:
    path "${sample_id}_mito_blast.txt", emit: blast_results
    path "${sample_id}_mito_contigs.fasta", emit: mito_contigs
    path "${sample_id}_mito_summary.txt", emit: summary
    path "versions.yml"                 , emit: versions

    script:
    """
    # Run BLAST
    blastn -query ${assembly} \
           -db ${mito_db}/mito \
           -outfmt "6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore qlen slen" \
           -num_threads ${task.cpus} \
           -max_target_seqs 3 \
           -evalue 1e-6 \
           -out ${sample_id}_mito_blast.txt

    # Extract mitochondrial contigs
    awk '\$3 >= 90 && \$4 >= 2000' ${sample_id}_mito_blast.txt | cut -f1 | sort | uniq > mito_contig_ids.txt
    seqtk subseq ${assembly} mito_contig_ids.txt > ${sample_id}_mito_contigs.fasta

    # Generate summary
    echo "Potential mitochondrial contigs:" > ${sample_id}_mito_summary.txt
    grep ">" ${sample_id}_mito_contigs.fasta | sed 's/>//' >> ${sample_id}_mito_summary.txt
    echo "" >> ${sample_id}_mito_summary.txt
    echo "Number of potential mitochondrial contigs: \$(grep -c ">" ${sample_id}_mito_contigs.fasta)" >> ${sample_id}_mito_summary.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        blast: \$(blastn -version | head -n 1 | sed 's/blastn: //')
        seqtk: \$(seqtk 2>&1 | head -n 3 | tail -n 1 | sed 's/Version: //')
    END_VERSIONS
    """
}