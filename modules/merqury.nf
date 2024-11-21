process MERQURY {
    container 'community.wave.seqera.io/library/merqury:1.3--3dd862c6d2916492'
    publishDir "${params.outdir}/${params.prefix}/merqury/reads", mode: 'copy'
    cpus = 4
    memory = { 16.GB * task.attempt }
    queue = 'medium'
    
    input:
    tuple val(sample_id), path(reads)
    tuple val(sample_id), path(assembly)

    output:
    path "${params.prefix}.completeness.stats", emit: completeness
    path "${params.prefix}.qv", emit: qv
    path "${params.prefix}.*.qv", emit: contig_qv
    path "${params.prefix}*.spectra-cn.fl.png", emit: spectra_cn_plot
    path "${params.prefix}.spectra-asm.fl.png", emit: spectra_asm_plot
    path "${params.prefix}*.bed", emit: error_bed
    path "${params.prefix}*.wig", emit: error_wig

    script:
    """
    meryl k=21 threads=${task.cpus} memory=${task.memory.toGiga()} count output ${params.prefix}.meryl ${reads}

    export MERQURY="/opt/conda/pkgs/merqury-1.3-hdfd78af_3/share/merqury"
    
    merqury.sh ${params.prefix}.meryl ${assembly} ${params.prefix}

    sed -i '1i seq\tunique_kmers\tall_kmers\tQV\terror' ${params.prefix}*.qv
    sed -i '1i assembly\tkmer_set\tsolid_kmers\ttotal_kmers\tcompleteness(%)' ${params.prefix}.completeness.stats
    """
}
