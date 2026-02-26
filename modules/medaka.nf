process MEDAKA {
    container 'quay.io/biocontainers/medaka:2.0.1--py38h8774169_0'
    publishDir "${params.outdir}/${sample_id}/assembly", mode: 'copy'
    
    input:
    tuple val(sample_id), path(fastq)
    tuple val(sample_id), path(racon_assembly)

    output:
    tuple val(sample_id), path("${sample_id}_medaka.fasta"), emit: consensus
    path "versions.yml"                                     , emit: versions

    script:
    """
    wget https://github.com/nanoporetech/medaka/raw/master/medaka/data/${params.model}_model_pt.tar.gz
    medaka_consensus -i ${fastq} -d ${racon_assembly} -o . -t ${task.cpus} -m ${params.model}_model_pt.tar.gz
    mv consensus.fasta ${sample_id}_medaka.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        medaka: \$(medaka --version | head -n 1 | sed 's/medaka //')
    END_VERSIONS
    """
}
