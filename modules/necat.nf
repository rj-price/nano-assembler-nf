process NECAT {
    container 'community.wave.seqera.io/library/necat:0.0.1_update20200803--3374eaaf9f244948'
    publishDir "${params.outdir}/${params.prefix}/necat", mode: 'copy'
    cpus = 4
    memory = { 40.GB * task.attempt }
    queue = 'long'

    input:
    tuple val(sample_id), path(fastq)
    val genome_size

    output:
    tuple val(sample_id), path("${params.prefix}_necat.fasta"), emit: assembly

    script:
    """
    echo ${fastq} > read_list.txt
    necat config ${params.prefix}_config.txt

    sed -i "s/PROJECT=/PROJECT=${params.prefix}/g" ${params.prefix}_config.txt
    sed -i 's/ONT_READ_LIST=/ONT_READ_LIST=read_list.txt/g' ${params.prefix}_config.txt
    sed -i "s/GENOME_SIZE=/GENOME_SIZE=${genome_size}/g" ${params.prefix}_config.txt
    sed -i 's/THREADS=4/THREADS=${task.cpus}/g' ${params.prefix}_config.txt
    sed -i 's/PREP_OUTPUT_COVERAGE=40/PREP_OUTPUT_COVERAGE=${params.coverage}/g' ${params.prefix}_config.txt
    sed -i 's/CNS_OUTPUT_COVERAGE=30/CNS_OUTPUT_COVERAGE=${params.coverage}/g' ${params.prefix}_config.txt

    necat correct ${params.prefix}_config.txt
    necat assemble ${params.prefix}_config.txt
    necat bridge ${params.prefix}_config.txt
    
    cp ${params.prefix}/6-bridge_contigs/polished_contigs.fasta ${params.prefix}_necat.fasta
    """
}
