process BUSCO {
    container 'quay.io/biocontainers/busco:6.1.0--pyhdfd78af_1'
    label 'optional_qc'
    publishDir { "${params.outdir}/${sample_id}/qc/busco" }, mode: 'copy'

    input:
    tuple val(sample_id), path(assembly)

    output:
    path "BUSCO_${sample_id}"                              , emit: busco_dir
    path "BUSCO_${sample_id}/short_summary.*${sample_id}.txt", emit: summary
    path "versions.yml"                                      , emit: versions

    script:
    """
    # Create a local download directory to avoid permission issues
    mkdir -p busco_downloads

    busco \\
        -m genome \\
        -c ${task.cpus} \\
        -i ${assembly} \\
        -o BUSCO_${sample_id} \\
        -l ${params.lineage} \\
        --download_path ./busco_downloads \\
        --force

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        busco: \$(busco --version | head -n 1 | sed 's/BUSCO //')
    END_VERSIONS
    """

    stub:
    """
    mkdir -p BUSCO_${sample_id}
    touch BUSCO_${sample_id}/short_summary.specific.${params.lineage}.${sample_id}.txt
    touch versions.yml
    """
}
