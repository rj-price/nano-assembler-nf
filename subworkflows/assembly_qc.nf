//
// Subworkflow: Post-Assembly QC
//

include { BUSCO } from '../modules/busco'
include { MERQURY } from '../modules/merqury'
include { TAPESTRY } from '../modules/tapestry'
include { GFASTATS } from '../modules/gfastats'
include { KRAKEN2 } from '../modules/kraken2'
include { MITO_CHECK } from '../modules/mito_check'
include { COVERAGE } from '../modules/coverage'

workflow ASSEMBLY_QC {
    take:
    qc_input_ch // channel: [val(sample_id), path(fastq), path(assembly), val(genome_size)]
    illumina_ch // channel: [val(sample_id), path(illumina_reads)] -- only samples that have them
    kraken2_db  // val: path
    mito_db     // val: path

    main:
    versions = Channel.empty()

    // Each process takes one already-paired tuple, so nothing depends on the
    // order the samples happen to be emitted in.
    reads_asm_ch = qc_input_ch.map { id, fq, asm, _gs -> tuple(id, fq, asm) }
    asm_ch       = qc_input_ch.map { id, _fq, asm, _gs -> tuple(id, asm) }
    asm_gs_ch    = qc_input_ch.map { id, _fq, asm, gs -> tuple(id, asm, gs) }

    // Coverage
    COVERAGE(reads_asm_ch)
    versions = versions.mix(COVERAGE.out.versions)

    // Merqury. The k-mer set must come from reads that are independent of the
    // assembly and more accurate than it -- building it from the same ONT reads
    // makes QV self-referential. join() against illumina_ch means samples
    // without short reads are skipped rather than given a misleading QV.
    MERQURY(illumina_ch.join(asm_ch).map { id, ill, asm -> tuple(id, ill, asm) })
    versions = versions.mix(MERQURY.out.versions)

    // Tapestry
    TAPESTRY(reads_asm_ch)
    versions = versions.mix(TAPESTRY.out.versions)

    // BUSCO
    BUSCO(asm_ch)
    versions = versions.mix(BUSCO.out.versions)

    // GFAStats
    GFASTATS(asm_gs_ch)
    versions = versions.mix(GFASTATS.out.versions)

    // Kraken2 for contamination check. Both databases are optional: skip the
    // step rather than requiring every user to have one installed.
    kraken2_report_ch = Channel.empty()
    if (kraken2_db) {
        KRAKEN2(asm_ch, kraken2_db)
        versions = versions.mix(KRAKEN2.out.versions)
        kraken2_report_ch = KRAKEN2.out.report
    }

    // Identify mitochondrial contigs
    if (mito_db) {
        MITO_CHECK(asm_ch, mito_db)
        versions = versions.mix(MITO_CHECK.out.versions)
    }

    emit:
    busco_summary = BUSCO.out.summary
    gfastats_stats = GFASTATS.out.stats
    merqury_completeness = MERQURY.out.completeness
    merqury_qv = MERQURY.out.qv
    kraken2_report = kraken2_report_ch
    mosdepth_global_dist = COVERAGE.out.global_dist
    mosdepth_summary = COVERAGE.out.summary
    versions
}
