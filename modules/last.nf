process DOTPLOT {
    container 'community.wave.seqera.io/library/last:1542--2e796163dffa1f85'
    publishDir "${params.outdir}/${params.prefix}/dotplot", mode: 'copy'
    cpus 2
    memory { 4.GB * task.attempt }
    queue 'medium'

    input:
    tuple val(sample_id), path(assembly)
    path ref_genome

    output:
    path "${params.prefix}_vs_ref.maf", emit: maf
    path "${params.prefix}_vs_ref.png", emit: dotplot

    script:
    """
    lastdb ref_index ${ref_genome}

    lastal ref_index ${assembly} > ${params.prefix}_vs_ref.maf

    last-dotplot ${params.prefix}_vs_ref.maf > ${params.prefix}_vs_ref.png
    """
}