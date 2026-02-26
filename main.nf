#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// Input validation
if (!params.input || !params.outdir || !params.genome_size || !params.prefix ) {
    error "Missing required parameters. Please provide --input (samplesheet.csv), --genome_size, --prefix, and --outdir."
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
Genome Size         : ${params.genome_size}
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
            if (!fastq.exists()) {
                error "FASTQ file does not exist: ${row.fastq}"
            }
            return tuple(sample_id, fastq)
        }
}

// Main workflow
workflow {
    // Create input channel from samplesheet
    reads_ch = parseSamplesheet(params.input)

    // Version tracking channel
    ch_versions = Channel.empty()

    // Subworkflow: Read QC
    READ_QC(reads_ch)
    ch_versions = ch_versions.mix(READ_QC.out.versions)

    // Subworkflow: Assembly and Polishing
    ASSEMBLY(READ_QC.out.filtered_reads, params.genome_size)
    ch_versions = ch_versions.mix(ASSEMBLY.out.versions)

    // Subworkflow: Post-Assembly QC
    ASSEMBLY_QC(
        READ_QC.out.filtered_reads,
        ASSEMBLY.out.consensus,
        params.genome_size,
        params.kraken2_db,
        params.mito_db
    )
    ch_versions = ch_versions.mix(ASSEMBLY_QC.out.versions)

    // Software versions aggregation
    CUSTOM_DUMP_SOFTWARE_VERSIONS(ch_versions.unique().collectFile(name: 'collated_versions.yml'))

    // Collect all QC reports for MultiQC
    multiqc_files = Channel.empty()
    multiqc_files = multiqc_files.mix(
        READ_QC.out.nanoplot_trimmed,
        READ_QC.out.nanoplot_filtered,
        ASSEMBLY_QC.out.busco_summary,
        ASSEMBLY_QC.out.gfastats_stats,
        ASSEMBLY_QC.out.merqury_completeness,
        ASSEMBLY_QC.out.merqury_qv,
        ASSEMBLY_QC.out.kraken2_report,
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