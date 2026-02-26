#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// Input validation
if (!params.reads_dir || !params.outdir || !params.genome_size || !params.prefix ) {
    error "Missing required parameters. Please provide --reads_dir, --genome_size, --prefix, and --outdir."
}


log.info """\

     N A N O   A S S E M B L E R     
=====================================
           INPUT PARAMETERS
Data Folder         : ${params.reads_dir}
Ouput Folder        : ${params.outdir}
Genome Size         : ${params.genome_size}
Prefix              : ${params.prefix}
=================================
        ADDITIONAL PARAMETERS
Minimum Read Length : ${params.min_length}
Minimum Mean Q      : ${params.min_mean_q}
Assembly Coverage   : ${params.coverage}
Basecalling Model   : ${params.model}
BUSCO lineage       : ${params.lineage}

""".stripIndent()


// Import modules
include { PORECHOP } from './modules/porechop'
include { NANOPLOT as NANOPLOT_TRIMMED } from './modules/nanoplot'
include { NANOPLOT as NANOPLOT_FILTERED } from './modules/nanoplot'
include { FILTLONG } from './modules/filtlong'
include { JELLYFISH } from './modules/jellyfish'
include { NECAT } from './modules/necat'
include { RACON } from './modules/racon'
include { MEDAKA } from './modules/medaka'
include { MERQURY } from './modules/merqury'
include { TAPESTRY } from './modules/tapestry'
include { BUSCO } from './modules/busco'
include { GFASTATS } from './modules/gfastats'
include { KRAKEN2 } from './modules/kraken2'
include { MITO_CHECK } from './modules/mito_check'
include { MULTIQC } from './modules/multiqc'

// Main workflow
workflow {
    // Create input channel
    reads_ch = Channel.fromPath(params.reads_dir)
        .map { dir -> tuple(dir.baseName, dir) }

    // Porechop
    PORECHOP(reads_ch)

    // NanoPlot trimmed reads
    NANOPLOT_TRIMMED(PORECHOP.out.porechopped, 'trimmed')

    // Filtlong
    FILTLONG(PORECHOP.out.porechopped)

    // NanoPlot filtered reads
    NANOPLOT_FILTERED(FILTLONG.out.filtered, 'filtered')
    
    // Jellyfish and GenomeScope2
    JELLYFISH(FILTLONG.out.filtered)

    // NECAT
    NECAT(FILTLONG.out.filtered, params.genome_size)

    // Racon
    RACON(FILTLONG.out.filtered, NECAT.out.assembly)

    // Medaka
    MEDAKA(FILTLONG.out.filtered, RACON.out.polished)

    // Merqury
    MERQURY(FILTLONG.out.filtered, MEDAKA.out.consensus)

    // Tapestry
    TAPESTRY(FILTLONG.out.filtered, MEDAKA.out.consensus)

    // BUSCO
    BUSCO(MEDAKA.out.consensus)

    // GFAStats
    GFASTATS(MEDAKA.out.consensus, params.genome_size)

    // Kraken2 for contamination check
    KRAKEN2(MEDAKA.out.consensus, params.kraken2_db)

    // Identify mitochondrial contigs
    MITO_CHECK(MEDAKA.out.consensus, params.mito_db)

    // Collect all QC reports
    multiqc_files = Channel.empty()
    multiqc_files = multiqc_files.mix(
        NANOPLOT_TRIMMED.out.flatten(),
        NANOPLOT_FILTERED.out.flatten(),
        BUSCO.out.summary.flatten(),
        GFASTATS.out.stats.flatten(),
        MERQURY.out.completeness.flatten(),
        MERQURY.out.qv.flatten(),
        KRAKEN2.out.report.flatten()
    )

    // MultiQC
    MULTIQC(multiqc_files.collect())
}

// Workflow completion notification
workflow.onComplete {
    log.info "Pipeline completed at: $workflow.complete"
    log.info "Execution status: ${ workflow.success ? 'OK' : 'failed' }"
}