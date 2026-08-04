process TAPESTRY {
    container 'nanozoo/tapestry:1.0.0--80fd6ac'
    label 'optional_qc'
    publishDir "${params.outdir}/${sample_id}/qc/tapestry", mode: 'copy'
    
    input:
    tuple val(sample_id), path(reads), path(assembly)

    output:
    path "${sample_id}/${sample_id}.tapestry_report.html", emit: report
    path "${sample_id}/contig_details.tsv"               , emit: details
    path "versions.yml"                                  , emit: versions

    script:
    """
    weave \
        --assembly ${assembly} \
        --reads ${reads} \
        --telomere ${params.telomere} \
        --length 2000 \
        --output ${sample_id} \
        --cores ${task.cpus}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tapestry: 1.0.0
    END_VERSIONS
    """

    stub:
    """
    mkdir -p ${sample_id}
    touch ${sample_id}/${sample_id}.tapestry_report.html
    touch ${sample_id}/contig_details.tsv
    touch versions.yml
    """
}
