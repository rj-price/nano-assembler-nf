process JELLYFISH {
    container 'community.wave.seqera.io/library/genomescope2_jellyfish_gzip:efb795d20a6993c4'
    publishDir "${params.outdir}/${sample_id}/qc/jellyfish", mode: 'copy'
    
    input:
    tuple val(sample_id), path(reads)
    
    output:
    tuple val(sample_id), path("${sample_id}_linear_plot.png")
    tuple val(sample_id), path("${sample_id}_log_plot.png")
    tuple val(sample_id), path("${sample_id}_summary.txt"), emit: summary
    path "versions.yml"                                   , emit: versions
    
    script:
    """
    zcat ${reads} | jellyfish count -C -m 21 -s 1G -t ${task.cpus} -o ${sample_id}.jf /dev/fd/0
    jellyfish histo -t ${task.cpus} ${sample_id}.jf > ${sample_id}.histo

    genomescope2 --input ${sample_id}.histo --kmer_length 21 --ploidy 2 --max_kmercov 10000 --output . --name_prefix ${sample_id}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        jellyfish: \$(jellyfish --version | head -n 1 | sed 's/jellyfish //')
        genomescope2: \$(genomescope2 --version | head -n 1 | sed 's/GenomeScope 2.0 //')
    END_VERSIONS
    """
}