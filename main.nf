#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// Input validation
if (!params.input || !params.outdir || !params.prefix ) {
    error "Missing required parameters. Please provide --input (samplesheet.csv), --prefix, and --outdir."
}


// Startup Log Information
log.info """\

     N A N O   A S S E M B L E R     
=====================================
${workflow.manifest.name} v${workflow.manifest.version}
=====================================
           INPUT PARAMETERS
Samplesheet         : ${params.input}
Ouput Folder        : ${params.outdir}
Prefix              : ${params.prefix}
=================================
        ADDITIONAL PARAMETERS
Minimum Read Length : ${params.min_length}
Minimum Mean Q      : ${params.min_mean_q}
Assembly Coverage   : ${params.coverage}
Basecalling Model   : ${params.model}
BUSCO lineage       : ${params.lineage}

=================================
        RUN INFORMATION
Executor            : ${workflow.containerEngine ?: 'local'}
Profile             : ${workflow.profile}
Nextflow version    : ${nextflow.version}
Launch dir          : ${workflow.launchDir}
=================================
""".stripIndent()


// Import subworkflows
include { READ_QC } from './subworkflows/read_qc'
include { ASSEMBLY } from './subworkflows/assembly'
include { ASSEMBLY_QC } from './subworkflows/assembly_qc'

// Import modules
include { MULTIQC } from './modules/multiqc'
include { CUSTOM_DUMP_SOFTWARE_VERSIONS } from './modules/dump_software_versions'

// Function to parse samplesheet
def parseSamplesheet(csvFile) {
    Channel.fromPath(csvFile)
        .splitCsv(header:true, sep:',')
        .map { row ->
            def sample_id = row.sample
            def fastq = file(row.fastq)
            def genome_size = row.genome_size
            if (!fastq.exists()) {
                error "FASTQ file does not exist: ${row.fastq}"
            }
            if (!genome_size) {
                error "Genome size missing for sample: ${sample_id}"
            }
            return tuple(sample_id, fastq, genome_size)
        }
}

// Main workflow
workflow {
    // Create input channel from samplesheet: [sample_id, fastq, genome_size]
    reads_gs_ch = parseSamplesheet(params.input)

    // Version tracking channel
    ch_versions = Channel.empty()

    // Subworkflow: Read QC
    // Extract just [sample_id, fastq] for Read QC
    READ_QC(reads_gs_ch.map { id, fastq, gs -> tuple(id, fastq) })
    ch_versions = ch_versions.mix(READ_QC.out.versions)

    // Subworkflow: Assembly and Polishing
    // ASSEMBLY needs [sample_id, fastq, genome_size]
    // We join filtered reads back with their genome size
    assembly_input_ch = READ_QC.out.filtered_reads
        .join(reads_gs_ch.map { id, fastq, gs -> tuple(id, gs) })
    
    ASSEMBLY(assembly_input_ch)
    ch_versions = ch_versions.mix(ASSEMBLY.out.versions)

    // Subworkflow: Post-Assembly QC
    // ASSEMBLY_QC needs [sample_id, fastq, assembly, genome_size], kraken2_db, mito_db
    // Prepare input by joining all pieces
    qc_input_ch = READ_QC.out.filtered_reads
        .join(ASSEMBLY.out.consensus)
        .join(reads_gs_ch.map { id, fastq, gs -> tuple(id, gs) })

    ASSEMBLY_QC(
        qc_input_ch,
        params.kraken2_db,
        params.mito_db
    )
    ch_versions = ch_versions.mix(ASSEMBLY_QC.out.versions)

    // Software versions aggregation
    CUSTOM_DUMP_SOFTWARE_VERSIONS(ch_versions.unique().collect())

    // Collect all QC reports for MultiQC
    multiqc_files = Channel.empty()
    multiqc_files = multiqc_files.mix(
        READ_QC.out.nanoplot_trimmed,
        READ_QC.out.nanoplot_filtered,
        READ_QC.out.jellyfish_summary,
        ASSEMBLY_QC.out.busco_summary,
        ASSEMBLY_QC.out.gfastats_stats,
        ASSEMBLY_QC.out.merqury_completeness,
        ASSEMBLY_QC.out.merqury_qv,
        ASSEMBLY_QC.out.kraken2_report,
        ASSEMBLY_QC.out.mosdepth_global_dist,
        ASSEMBLY_QC.out.mosdepth_summary,
        CUSTOM_DUMP_SOFTWARE_VERSIONS.out.mqc_yaml
    )

    // MultiQC
    MULTIQC(multiqc_files.collect())
}

// Workflow completion notification
workflow.onComplete {
    log.info "Pipeline completed at: $workflow.complete"
    log.info "Execution status: ${ workflow.success ? 'OK' : 'failed' }"
}
