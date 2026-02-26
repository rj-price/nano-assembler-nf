process FILTLONG {
    container 'community.wave.seqera.io/library/filtlong:0.2.1--5cb367f8dffa9e28'
    publishDir "${params.outdir}/${sample_id}/qc", mode: 'copy'

    input:
    tuple val(sample_id), path(fastq)

    output:
    tuple val(sample_id), path("${sample_id}_filt.fastq.gz"), emit: filtered
    path "versions.yml"                                      , emit: versions

    script:
    """
    filtlong --min_length ${params.min_length} --min_mean_q ${params.min_mean_q} ${fastq} | gzip > ${sample_id}_filt.fastq.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        filtlong: \$(filtlong --version | head -n 1 | sed 's/Filtlong v//')
    END_VERSIONS
    """
}
