process MULTIQC {
    container 'community.wave.seqera.io/library/multiqc:1.25.1--dc1968330462e945'
    publishDir "${params.outdir}/${params.prefix}/multiqc", mode: 'copy'
    cpus = 2
    memory = { 1.GB * task.attempt }
    queue = 'short'

    input:
    path '*'

    output:
    path 'multiqc_report.html'
    path 'multiqc_data'

    script:
    """
    multiqc .
    """
}