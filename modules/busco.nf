process BUSCO {
    container 'community.wave.seqera.io/library/busco:5.2.2--b38cf04af6adc85b'
    publishDir "${params.outdir}/${sample_id}/qc/busco", mode: 'copy'

    input:
    tuple val(sample_id), path(assembly)

    output:
    path "BUSCO_${sample_id}"
    path "BUSCO_${sample_id}/short_summary.*${sample_id}.txt", emit: summary
    path "versions.yml"                                      , emit: versions

    script:
    """
    busco -m genome -c ${task.cpus} -i ${assembly} -o BUSCO_${sample_id} -l ${params.lineage}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        busco: \$(busco --version | head -n 1 | sed 's/BUSCO //')
    END_VERSIONS
    """
}
