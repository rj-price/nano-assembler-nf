process NANOPLOT {
    container 'community.wave.seqera.io/library/nanoplot:1.43.0--c7226d331b0968bf'
    publishDir "${params.outdir}/${sample_id}/qc/nanoplot/${stage}", mode: 'copy'

    input:
    tuple val(sample_id), path(fastq)
    val(stage)

    output:
    path "*", exclude: "versions.yml", emit: plots
    path "versions.yml"              , emit: versions

    script:
    """
    NanoPlot -t ${task.cpus} --fastq ${fastq} --prefix ${stage}_ --outdir ./${stage} 

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nanoplot: \$(NanoPlot --version | head -n 1 | sed 's/NanoPlot //')
    END_VERSIONS
    """
}
