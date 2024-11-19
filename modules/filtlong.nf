process FILTLONG {
    container 'community.wave.seqera.io/library/filtlong:0.2.1--5cb367f8dffa9e28'
    publishDir "${params.outdir}/${params.prefix}", mode: 'copy'
    cpus = 2
    memory = { 10.GB * task.attempt }
    queue = 'medium'

    input:
    tuple val(sample_id), path(fastq)

    output:
    tuple val(sample_id), path("${params.prefix}_filt.fastq.gz"), emit: filtered

    script:
    """
    filtlong --min_length ${params.min_length} --min_mean_q ${params.min_mean_q} ${fastq} | gzip > ${params.prefix}_filt.fastq.gz
    """
}
