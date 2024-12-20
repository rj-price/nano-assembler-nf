process TAPESTRY {
    container 'nanozoo/tapestry:1.0.0--80fd6ac'
    publishDir "${params.outdir}/${params.prefix}/tapestry", mode: 'copy'
    cpus = 4
    memory = { 8.GB * task.attempt }
    queue = 'medium'
    
    input:
    tuple val(sample_id), path(reads)
    tuple val(sample_id), path(assembly)

    output:
    path "${params.prefix}/${params.prefix}.tapestry_report.html"
    path "${params.prefix}/contig_details.tsv"

    script:
    """
    weave \
        --assembly ${assembly} \
        --reads ${reads} \
        --telomere TTAGGG \
        --length 2000 \
        --output ${params.prefix} \
        --cores ${task.cpus}
    """
}
