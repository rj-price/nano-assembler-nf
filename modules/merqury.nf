process MERQURY {
    container 'community.wave.seqera.io/library/merqury:1.3--3dd862c6d2916492'
    publishDir "${params.outdir}/${sample_id}/qc/merqury", mode: 'copy'
    
    input:
    tuple val(sample_id), path(reads)
    tuple val(sample_id), path(assembly)

    output:
    path "${sample_id}.completeness.stats", emit: completeness
    path "${sample_id}.qv", emit: qv
    path "${sample_id}.*.qv", emit: contig_qv
    path "${sample_id}*.spectra-cn.fl.png", emit: spectra_cn_plot
    path "${sample_id}.spectra-asm.fl.png", emit: spectra_asm_plot
    path "${sample_id}*.bed", emit: error_bed
    path "${sample_id}*.wig", emit: error_wig
    path "versions.yml"                 , emit: versions

    script:
    """
    meryl k=21 threads=${task.cpus} memory=${task.memory.toGiga()} count output ${sample_id}.meryl ${reads}

    export MERQURY="/opt/conda/pkgs/merqury-1.3-hdfd78af_3/share/merqury"
    
    merqury.sh ${sample_id}.meryl ${assembly} ${sample_id}

    sed -i '1i seq\tunique_kmers\tall_kmers\tQV\terror' ${sample_id}*.qv
    sed -i '1i assembly\tkmer_set\tsolid_kmers\ttotal_kmers\tcompleteness(%)' ${sample_id}.completeness.stats

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        merqury: 1.3
        meryl: \$(meryl --version | head -n 1 | sed 's/meryl //')
    END_VERSIONS
    """
}
