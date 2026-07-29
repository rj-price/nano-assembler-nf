process NANOPLOT {
    container 'community.wave.seqera.io/library/nanoplot:1.43.0--c7226d331b0968bf'
    label 'optional_qc'
    publishDir "${params.outdir}/${sample_id}/qc/nanoplot/${stage}", mode: 'copy'

    input:
    tuple val(sample_id), path(fastq)
    val(stage)

    output:
    path "${stage}/*", emit: plots
    path "versions.yml", emit: versions

    script:
    // MultiQC stages every input flat, so the prefix must include the sample
    // id or NanoStats.txt from two samples collides and one is silently lost.
    """
    NanoPlot -t ${task.cpus} --fastq ${fastq} --prefix ${sample_id}_${stage}_ --outdir ./${stage}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nanoplot: \$(NanoPlot --version | head -n 1 | sed 's/NanoPlot //')
    END_VERSIONS
    """

    stub:
    """
    mkdir -p ${stage}
    touch ${stage}/${sample_id}_${stage}_NanoStats.txt
    touch versions.yml
    """
}
