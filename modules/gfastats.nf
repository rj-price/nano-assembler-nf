process GFASTATS {
    container 'community.wave.seqera.io/library/gfastats:1.3.7--5ddeb8c027819e41'
    publishDir "${params.outdir}/${sample_id}/qc/gfastats", mode: 'copy'

    input:
    tuple val(sample_id), path(assembly)
    val genome_size

    output:
    path "${sample_id}_genome_stats.tsv", emit: stats
    path "${sample_id}_contig_stats.tsv", emit: contig_stats
    path "versions.yml"                 , emit: versions

    script:
    """
    gfastats ${assembly} ${genome_size} --threads ${task.cpus} --tabular --nstar-report > ${sample_id}_genome_stats.tsv

    gfastats ${assembly} ${genome_size} --threads ${task.cpus} --tabular --nstar-report --seq-report > ${sample_id}_contig_stats.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gfastats: \$(gfastats --version | head -n 1 | sed 's/gfastats //')
    END_VERSIONS
    """
}
