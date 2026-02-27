process COVERAGE {
    container 'community.wave.seqera.io/library/minimap2_mosdepth_samtools:ea43294d3c125655'
    publishDir "${params.outdir}/${sample_id}/qc/coverage", mode: 'copy'

    input:
    tuple val(sample_id), path(fastq)
    tuple val(sample_id), path(assembly)

    output:
    path "${sample_id}.mosdepth.global.dist.txt", emit: global_dist
    path "${sample_id}.mosdepth.summary.txt"     , emit: summary
    path "versions.yml"                         , emit: versions

    script:
    """
    minimap2 -ax map-ont -t ${task.cpus} ${assembly} ${fastq} | 
    samtools sort -@ ${task.cpus} -o ${sample_id}_sorted.bam -
    samtools index ${sample_id}_sorted.bam

    mosdepth --threads ${task.cpus} --fast-mode --no-per-base ${sample_id} ${sample_id}_sorted.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        minimap2: \$(minimap2 --version)
        samtools: \$(samtools --version | head -n 1 | sed 's/samtools //')
        mosdepth: \$(mosdepth --version | sed 's/mosdepth //')
    END_VERSIONS
    """
}
