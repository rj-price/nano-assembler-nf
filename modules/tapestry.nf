process TAPESTRY {
    container 'nanozoo/tapestry:1.0.0--80fd6ac'
    publishDir "${params.outdir}/${sample_id}/qc/tapestry", mode: 'copy'
    
    input:
    tuple val(sample_id), path(reads)
    tuple val(sample_id), path(assembly)

    output:
    path "${sample_id}/${sample_id}.tapestry_report.html"
    path "${sample_id}/contig_details.tsv"
    path "versions.yml", emit: versions

    script:
    """
    weave \
        --assembly ${assembly} \
        --reads ${reads} \
        --telomere TTAGGG \
        --length 2000 \
        --output ${sample_id} \
        --cores ${task.cpus}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tapestry: 1.0.0
    END_VERSIONS
    """
}
