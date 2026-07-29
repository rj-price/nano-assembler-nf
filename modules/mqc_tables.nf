process MQC_TABLES {
    // MultiQC has no module for gfastats, Merqury or GenomeScope2, so without
    // this conversion those results are staged into the report and dropped.
    container 'community.wave.seqera.io/library/multiqc:1.25.1--dc1968330462e945'
    label 'optional_qc'
    publishDir "${params.outdir}/${sample_id}/qc/multiqc_tables", mode: 'copy'

    input:
    tuple val(sample_id), path(gfastats_stats), path(genomescope_summary)

    output:
    path "*_mqc.tsv"   , emit: tables
    path "versions.yml", emit: versions

    script:
    """
    mqc_tables.py gfastats    ${sample_id} ${gfastats_stats}
    mqc_tables.py genomescope ${sample_id} ${genomescope_summary}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //')
    END_VERSIONS
    """

    stub:
    """
    touch ${sample_id}_gfastats_mqc.tsv
    touch ${sample_id}_genomescope_mqc.tsv
    touch versions.yml
    """
}

process MQC_MERQURY {
    // Split out from MQC_TABLES because Merqury only runs for samples that
    // supplied short reads; the tables above must still be produced for the rest.
    container 'community.wave.seqera.io/library/multiqc:1.25.1--dc1968330462e945'
    label 'optional_qc'
    publishDir "${params.outdir}/${sample_id}/qc/multiqc_tables", mode: 'copy'

    input:
    tuple val(sample_id), path(merqury_qv), path(merqury_completeness)

    output:
    path "*_mqc.tsv"   , emit: tables
    path "versions.yml", emit: versions

    script:
    """
    mqc_tables.py merqury ${sample_id} ${merqury_qv} ${merqury_completeness}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //')
    END_VERSIONS
    """

    stub:
    """
    touch ${sample_id}_merqury_mqc.tsv
    touch versions.yml
    """
}
