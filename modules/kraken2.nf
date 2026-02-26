process KRAKEN2 {
    container 'community.wave.seqera.io/library/kraken2:2.1.3--de40043c074a5c69'
    publishDir "${params.outdir}/${sample_id}/qc/kraken2", mode: 'copy'

    input:
    tuple val(sample_id), path(assembly)
    path kraken2_db

    output:
    path "${sample_id}_kraken2_report.txt", emit: report
    path "${sample_id}_kraken2_output.txt", emit: classifications
    path "versions.yml"                    , emit: versions

    script:
    """   
    kraken2 --db ${kraken2_db} \
        --threads ${task.cpus} \
        --use-names \
        --output ${sample_id}_kraken2_output.txt \
        --report ${sample_id}_kraken2_report.txt \
        ${assembly}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        kraken2: \$(kraken2 --version | head -n 1 | sed 's/Kraken version //')
    END_VERSIONS
    """
}