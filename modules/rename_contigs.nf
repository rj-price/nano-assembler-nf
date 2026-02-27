process RENAME_CONTIGS {
    container 'quay.io/biocontainers/seqkit:2.8.2--h9ee0642_0'
    publishDir "${params.outdir}/${sample_id}/assembly", mode: 'copy'

    input:
    tuple val(sample_id), path(assembly)

    output:
    tuple val(sample_id), path("${sample_id}_final.fasta"), emit: renamed_assembly
    path "versions.yml"                                   , emit: versions

    script:
    """
    seqkit sort --by-length --reverse ${assembly} | \\
    seqkit replace --pattern '.*' --replacement 'contig_{NR}' > ${sample_id}_final.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        seqkit: \$(seqkit version | cut -d ' ' -f 2)
    END_VERSIONS
    """
}