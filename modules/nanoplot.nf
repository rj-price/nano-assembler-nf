process NANOPLOT {
    container 'community.wave.seqera.io/library/nanoplot:1.43.0--c7226d331b0968bf'
    publishDir "${params.outdir}/${params.prefix}/nanoplot/${stage}", mode: 'copy'

    input:
    tuple val(sample_id), path(fastq)
    val(stage)

    output:
    path "*"

    script:
    """
    NanoPlot -t ${task.cpus} --fastq ${fastq} --prefix ${stage}_ --outdir ./${stage} 
    """
}
