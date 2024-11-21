process KRAKEN2 {
    container 'community.wave.seqera.io/library/kraken2:2.1.3--de40043c074a5c69'
    publishDir "${params.outdir}/${params.prefix}/kraken2", mode: 'copy'
    cpus = 2
    memory = { 18.GB * task.attempt }
    queue = 'medium'

    input:
    tuple val(sample_id), path(assembly)
    path kraken2_db

    output:
    path "${params.prefix}_kraken2_report.txt", emit: report
    path "${params.prefix}_kraken2_output.txt", emit: classifications

    script:
    """   
    kraken2 --db ${kraken2_db} \
        --threads 4 \
        --use-names \
        --output ${params.prefix}_kraken2_output.txt \
        --report ${params.prefix}_kraken2_report.txt \
        ${assembly}
    """
}