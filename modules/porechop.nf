process PORECHOP {
    container 'community.wave.seqera.io/library/porechop:0.2.4--b0e5b14915819586'
    publishDir "${params.outdir}/${params.prefix}", mode: 'copy'
    cpus = 4
    memory = { 30.GB * task.attempt }
    queue = 'medium'

    input:
    tuple val(sample_id), path(reads_dir)

    output:
    tuple val(sample_id), path("${params.prefix}.fastq.gz"), emit: porechopped

    script:
    """
    porechop -t ${task.cpus} -i ${reads_dir} -o ${params.prefix}.fastq.gz
    """
}
