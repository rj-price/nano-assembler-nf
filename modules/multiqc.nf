process MULTIQC {
    container 'community.wave.seqera.io/library/multiqc:1.25.1--dc1968330462e945'
    publishDir "${params.outdir}/multiqc", mode: 'copy'

    input:
    path '*'

    output:
    path 'multiqc_report.html'
    path 'multiqc_data'
    path "versions.yml"        , emit: versions

    script:
    """
    multiqc .

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        multiqc: \$(multiqc --version | head -n 1 | sed 's/multiqc, version //')
    END_VERSIONS
    """
}