process PURGE_DUPS {
    // The bioconda purge_dups package depends on minimap2, so both are present.
    container 'quay.io/biocontainers/purge_dups:1.2.6--h577a1d6_3'
    publishDir { "${params.outdir}/${sample_id}/assembly/purge_dups" }, mode: 'copy'

    input:
    tuple val(sample_id), path(fastq), path(assembly)

    output:
    tuple val(sample_id), path("${sample_id}_purged.fasta"), emit: purged
    path "${sample_id}_hap.fasta"                          , emit: haplotigs
    path "${sample_id}_cutoffs"                            , emit: cutoffs
    path "${sample_id}_dups.bed"                           , emit: dups_bed
    path "versions.yml"                                    , emit: versions

    script:
    // Standard purge_dups long-read workflow: self-coverage from the reads,
    // then a self-alignment to find the duplicated haplotigs.
    """
    minimap2 -x map-ont -t ${task.cpus} ${assembly} ${fastq} > reads.paf
    pbcstat reads.paf
    calcuts PB.stat > cutoffs 2> calcuts.log

    split_fa ${assembly} > asm.split
    minimap2 -x asm5 -DP -t ${task.cpus} asm.split asm.split > asm.split.self.paf

    purge_dups -2 -T cutoffs -c PB.base.cov asm.split.self.paf > dups.bed
    get_seqs -e dups.bed ${assembly}

    mv purged.fa ${sample_id}_purged.fasta
    mv hap.fa ${sample_id}_hap.fasta
    mv cutoffs ${sample_id}_cutoffs
    mv dups.bed ${sample_id}_dups.bed

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        purge_dups: 1.2.6
        minimap2: \$(minimap2 --version)
    END_VERSIONS
    """

    stub:
    """
    touch ${sample_id}_purged.fasta ${sample_id}_hap.fasta
    touch ${sample_id}_cutoffs ${sample_id}_dups.bed
    touch versions.yml
    """
}
