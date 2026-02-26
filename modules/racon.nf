process RACON {
    container 'community.wave.seqera.io/library/minimap2_racon:5f257adb6aaf9096'
    publishDir "${params.outdir}/${sample_id}/assembly/racon", mode: 'copy'

    input:
    tuple val(sample_id), path(fastq)
    tuple val(sample_id), path(necat_assembly)

    output:
    tuple val(sample_id), path("${sample_id}_racon.fasta"), emit: polished
    path "versions.yml"                                    , emit: versions

    script:
    """
    minimap2 -ax map-ont -t ${task.cpus} ${necat_assembly} ${fastq} > map.sam
    racon --threads ${task.cpus} ${fastq} map.sam ${necat_assembly} > ${sample_id}_racon.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        racon: \$(racon --version | head -n 1 | sed 's/v//')
        minimap2: \$(minimap2 --version)
    END_VERSIONS
    """
}
