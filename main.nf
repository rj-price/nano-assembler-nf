#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// Input Parameters
params.reads_dir    = "${launchDir}/data"
params.outdir       = "${launchDir}/output"
params.prefix       = "assembly"
params.genome_size  = null

// Filtlong Parameters
params.min_length   = 1000
params.min_mean_q   = 90

// NECAT Parameters
params.coverage     = 80

// Medaka Parameters
params.model        = "r1041_e82_400bps_sup_g615"

// BUSCO Parameters
params.lineage      = "fungi_odb10"

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
include { KMC_READS } from './modules/kmc'
include { NECAT } from './modules/necat'
include { RACON } from './modules/racon'
include { MEDAKA } from './modules/medaka'
include { KMC_COMPARE } from './modules/kmc'
include { BUSCO } from './modules/busco'
include { GFASTATS } from './modules/gfastats'
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
    
    // KMC analysis on filtered reads
    KMC_READS(FILTLONG.out.filtered)

    // NECAT
    NECAT(FILTLONG.out.filtered, params.genome_size)

    // Racon
    RACON(FILTLONG.out.filtered, NECAT.out.assembly)

    // Medaka
    MEDAKA(FILTLONG.out.filtered, RACON.out.polished)
    
    // KMC comparison of filtered reads against final assembly
    KMC_COMPARE(KMC_READS.out.kmc_db, MEDAKA.out.consensus)

    // BUSCO
    BUSCO(MEDAKA.out.consensus)

    // GFAStats
    GFASTATS(MEDAKA.out.consensus, params.genome_size)

    // Collect all QC reports
    multiqc_files = Channel.empty()
    multiqc_files = multiqc_files.mix(NANOPLOT_TRIMMED.out.collect())
    multiqc_files = multiqc_files.mix(NANOPLOT_FILTERED.out.collect())
    multiqc_files = multiqc_files.mix(BUSCO.out.collect())
    multiqc_files = multiqc_files.mix(KMC_READS.out.stats.collect())
    multiqc_files = multiqc_files.mix(KMC_COMPARE.out.stats.collect())

    // MultiQC
    MULTIQC(multiqc_files.collect())
}

// Workflow completion notification
workflow.onComplete {
    log.info "Pipeline completed at: $workflow.complete"
    log.info "Execution status: ${ workflow.success ? 'OK' : 'failed' }"
}