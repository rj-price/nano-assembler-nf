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
    kraken2_db  // val: path
    mito_db     // val: path

    main:
    versions = Channel.empty()

    // Coverage
    COVERAGE(
        qc_input_ch.map { id, fq, ass, gs -> tuple(id, fq) },
        qc_input_ch.map { id, fq, ass, gs -> tuple(id, ass) }
    )
    versions = versions.mix(COVERAGE.out.versions)

    // Merqury
    MERQURY(
        qc_input_ch.map { id, fq, ass, gs -> tuple(id, fq) },
        qc_input_ch.map { id, fq, ass, gs -> tuple(id, ass) }
    )
    versions = versions.mix(MERQURY.out.versions)

    // Tapestry
    TAPESTRY(
        qc_input_ch.map { id, fq, ass, gs -> tuple(id, fq) },
        qc_input_ch.map { id, fq, ass, gs -> tuple(id, ass) }
    )
    versions = versions.mix(TAPESTRY.out.versions)

    // BUSCO
    BUSCO(qc_input_ch.map { id, fq, ass, gs -> tuple(id, ass) })
    versions = versions.mix(BUSCO.out.versions)

    // GFAStats
    GFASTATS(
        qc_input_ch.map { id, fq, ass, gs -> tuple(id, ass) },
        qc_input_ch.map { id, fq, ass, gs -> gs }
    )
    versions = versions.mix(GFASTATS.out.versions)

    // Kraken2 for contamination check
    KRAKEN2(qc_input_ch.map { id, fq, ass, gs -> tuple(id, ass) }, kraken2_db)
    versions = versions.mix(KRAKEN2.out.versions)

    // Identify mitochondrial contigs
    MITO_CHECK(qc_input_ch.map { id, fq, ass, gs -> tuple(id, ass) }, mito_db)
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
