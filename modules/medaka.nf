process MEDAKA {
    container 'quay.io/biocontainers/medaka:2.0.1--py38h8774169_0'
    publishDir "${params.outdir}/${params.prefix}/final", mode: 'copy'
    cpus = 4
    memory = { 40.GB * task.attempt }
    queue = 'long'
    
    input:
    tuple val(sample_id), path(fastq)
    tuple val(sample_id), path(racon_assembly)

    output:
    tuple val(sample_id), path("${params.prefix}_medaka.fasta"), emit: consensus

    script:
    """
    wget https://github.com/nanoporetech/medaka/raw/master/medaka/data/${params.model}_model_pt.tar.gz
    medaka_consensus -i ${fastq} -d ${racon_assembly} -o . -t ${task.cpus} -m ${params.model}_model_pt.tar.gz
    mv consensus.fasta ${params.prefix}_medaka.fasta
    """
}
