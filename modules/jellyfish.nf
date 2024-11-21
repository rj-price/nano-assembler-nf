process JELLYFISH {
    container 'community.wave.seqera.io/library/genomescope2_jellyfish_gzip:efb795d20a6993c4'
    publishDir "${params.outdir}/${params.prefix}/jellyfish", mode: 'copy'
    cpus = 4
    memory = { 20.GB * task.attempt }
    queue = 'medium'
    
    input:
    tuple val(sample_id), path(reads)
    
    output:
    tuple val(sample_id), path("${params.prefix}_linear_plot.png")
    tuple val(sample_id), path("${params.prefix}_log_plot.png")
    tuple val(sample_id), path("${params.prefix}_summary.txt"), emit: summary
    
    script:
    """
    zcat ${reads} | jellyfish count -C -m 21 -s 1G -t 8 -o ${params.prefix}.jf /dev/fd/0
    jellyfish histo -t 8 ${params.prefix}.jf > ${params.prefix}.histo

    genomescope2 --input ${params.prefix}.histo --kmer_length 21 --ploidy 2 --max_kmercov 10000 --output . --name_prefix ${params.prefix}
    """
}