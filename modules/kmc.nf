process KMC_READS {
    container 'community.wave.seqera.io/library/kmc:3.2.1--h5bf99c6_1'
    publishDir "${params.outdir}/${params.prefix}/kmc_reads", mode: 'copy'
    cpus 4
    memory { 8.GB * task.attempt }
    
    input:
    tuple val(sample_id), path(reads)
    
    output:
    tuple val(sample_id), path("${sample_id}_reads.kmc_pre"), path("${sample_id}_reads.kmc_suf"), emit: kmc_db
    path "${sample_id}_reads_stats.txt", emit: stats
    
    script:
    """
    kmc -k21 -t${task.cpus} -m8 -ci1 -cs10000 ${reads} ${sample_id}_reads .
    kmc_tools info ${sample_id}_reads -s > ${sample_id}_reads_stats.txt
    """
}

process KMC_COMPARE {
    container 'community.wave.seqera.io/library/kmc:3.2.1--h5bf99c6_1'
    publishDir "${params.outdir}/${params.prefix}/kmc_compare", mode: 'copy'
    cpus 4
    memory { 8.GB * task.attempt }
    
    input:
    tuple val(sample_id), path(reads_pre), path(reads_suf)
    path assembly
    
    output:
    path "${sample_id}_compare_stats.txt", emit: stats
    
    script:
    """
    kmc -k21 -t${task.cpus} -m8 -ci1 -cs10000 ${assembly} assembly .
    kmc_tools complex -t${task.cpus} \
    "intersect ${sample_id}_reads assembly intersection \
    union ${sample_id}_reads assembly union \
    kmers_subtract ${sample_id}_reads assembly reads_only \
    kmers_subtract assembly ${sample_id}_reads assembly_only"
    
    echo "Intersection (kmers in both reads and assembly): \$(kmc_tools transform intersection histogram . -cx0 | awk '{sum+=\$2} END {print sum}')" > ${sample_id}_compare_stats.txt
    echo "Union (total unique kmers): \$(kmc_tools transform union histogram . -cx0 | awk '{sum+=\$2} END {print sum}')" >> ${sample_id}_compare_stats.txt
    echo "Reads only (kmers in reads but not in assembly): \$(kmc_tools transform reads_only histogram . -cx0 | awk '{sum+=\$2} END {print sum}')" >> ${sample_id}_compare_stats.txt
    echo "Assembly only (kmers in assembly but not in reads): \$(kmc_tools transform assembly_only histogram . -cx0 | awk '{sum+=\$2} END {print sum}')" >> ${sample_id}_compare_stats.txt
    """
}