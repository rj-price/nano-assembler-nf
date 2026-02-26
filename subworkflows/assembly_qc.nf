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
    reads_ch    // channel: [val(sample_id), path(fastq)]
    assembly_ch // channel: [val(sample_id), path(assembly)]
    genome_size // val: genome_size
    kraken2_db  // val: path
    mito_db     // val: path

    main:
    versions = Channel.empty()

    // Coverage
    COVERAGE(reads_ch, assembly_ch)
    versions = versions.mix(COVERAGE.out.versions)

    // Merqury
    MERQURY(reads_ch, assembly_ch)
    versions = versions.mix(MERQURY.out.versions)

    // Tapestry
    TAPESTRY(reads_ch, assembly_ch)
    versions = versions.mix(TAPESTRY.out.versions)

    // BUSCO
    BUSCO(assembly_ch)
    versions = versions.mix(BUSCO.out.versions)

    // GFAStats
    GFASTATS(assembly_ch, genome_size)
    versions = versions.mix(GFASTATS.out.versions)

    // Kraken2 for contamination check
    KRAKEN2(assembly_ch, kraken2_db)
    versions = versions.mix(KRAKEN2.out.versions)

    // Identify mitochondrial contigs
    MITO_CHECK(assembly_ch, mito_db)
    versions = versions.mix(MITO_CHECK.out.versions)

    emit:
    busco_summary = BUSCO.out.summary
    gfastats_stats = GFASTATS.out.stats
    merqury_completeness = MERQURY.out.completeness
    merqury_qv = MERQURY.out.qv
    kraken2_report = KRAKEN2.out.report
    mosdepth_global_dist = COVERAGE.out.global_dist
    mosdepth_summary = COVERAGE.out.summary
    versions
}
