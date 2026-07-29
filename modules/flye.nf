process FLYE {
    container 'quay.io/biocontainers/flye:2.9.6--py39h475c85d_0'
    publishDir "${params.outdir}/${sample_id}/assembly/flye", mode: 'copy'

    input:
    tuple val(sample_id), path(fastq), val(genome_size)

    output:
    tuple val(sample_id), path("${sample_id}_flye.fasta"), emit: assembly
    path "${sample_id}_assembly_graph.gfa"               , emit: gfa
    path "${sample_id}_assembly_info.txt"                , emit: info
    path "versions.yml"                                  , emit: versions

    script:
    // --nano-hq covers both sup basecalls and Q20+ chemistry; --nano-raw is
    // only right for pre-Guppy5 R9 data.
    """
    flye \\
        --nano-hq ${fastq} \\
        --genome-size ${genome_size} \\
        --threads ${task.cpus} \\
        --out-dir flye_out

    cp flye_out/assembly.fasta ${sample_id}_flye.fasta
    cp flye_out/assembly_graph.gfa ${sample_id}_assembly_graph.gfa
    cp flye_out/assembly_info.txt ${sample_id}_assembly_info.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        flye: \$(flye --version)
    END_VERSIONS
    """

    stub:
    """
    touch ${sample_id}_flye.fasta
    touch ${sample_id}_assembly_graph.gfa
    touch ${sample_id}_assembly_info.txt
    touch versions.yml
    """
}
