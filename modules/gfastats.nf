process GFASTATS {
    container 'community.wave.seqera.io/library/gfastats:1.3.7--5ddeb8c027819e41'
    publishDir "${params.outdir}/${params.prefix}/final", mode: 'copy'

    input:
    tuple val(sample_id), path(assembly)
    val genome_size

    output:
    path "${params.prefix}_genome_stats.tsv", emit: stats
    path "${params.prefix}_contig_stats.tsv"

    script:
    """
    gfastats ${assembly} ${genome_size} --threads ${task.cpus} --tabular --nstar-report > ${params.prefix}_genome_stats.tsv

    gfastats ${assembly} ${genome_size} --threads ${task.cpus} --tabular --nstar-report --seq-report > ${params.prefix}_contig_stats.tsv
    """
}
