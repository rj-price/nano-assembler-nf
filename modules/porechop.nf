process PORECHOP {
    container 'community.wave.seqera.io/library/porechop:0.2.4--b0e5b14915819586'
    publishDir "${params.outdir}/${sample_id}/qc", mode: 'copy'

    input:
    tuple val(sample_id), path(reads_dir)

    output:
    tuple val(sample_id), path("${sample_id}_porechopped.fastq.gz"), emit: porechopped
    path "versions.yml"                                             , emit: versions

    script:
    """
    porechop -t ${task.cpus} -i ${reads_dir} -o ${sample_id}_porechopped.fastq.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        porechop: \$(porechop --version | head -n 1 | sed 's/Porechop //')
    END_VERSIONS
    """
}
