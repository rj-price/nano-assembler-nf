#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// Import subworkflows
include { READ_QC } from './subworkflows/read_qc'
include { ASSEMBLY } from './subworkflows/assembly'
include { ASSEMBLY_QC } from './subworkflows/assembly_qc'

// Import modules
include { MULTIQC } from './modules/multiqc'
include { MQC_TABLES; MQC_MERQURY } from './modules/mqc_tables'
include { CUSTOM_DUMP_SOFTWARE_VERSIONS } from './modules/dump_software_versions'

// Function to parse samplesheet.
// Columns: sample,fastq,genome_size[,illumina]
// `illumina` is optional; give one path, or several separated by ';' (e.g. R1;R2).
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

            def illumina = []
            if (row.illumina?.trim()) {
                illumina = row.illumina.split(';').collect { it.trim() }.findAll { it }.collect { p ->
                    def f = file(p)
                    if (!f.exists()) {
                        error "Illumina FASTQ does not exist for ${sample_id}: ${p}"
                    }
                    return f
                }
            }

            return tuple(sample_id, fastq, genome_size, illumina)
        }
}

def validateParams() {
    // Medaka ships a fixed model set. Checking up front turns a bad --model
    // into an instant failure rather than a wget 404 an hour into the run.
    def medaka_models = [
        'r941_min_fast_g507', 'r941_min_hac_g507', 'r941_min_sup_g507',
        'r941_prom_fast_g507', 'r941_prom_hac_g507', 'r941_prom_sup_g507',
        'r1041_e82_400bps_fast_g615', 'r1041_e82_400bps_hac_g615', 'r1041_e82_400bps_sup_g615',
        'r1041_e82_400bps_hac_v4.2.0', 'r1041_e82_400bps_sup_v4.2.0',
        'r1041_e82_400bps_hac_v4.3.0', 'r1041_e82_400bps_sup_v4.3.0',
        'r1041_e82_400bps_hac_v5.0.0', 'r1041_e82_400bps_sup_v5.0.0',
    ]

    if (!params.input) {
        error "Missing required parameter: --input (samplesheet.csv)"
    }
    if (!(params.assembler in ['necat', 'flye'])) {
        error "--assembler must be 'necat' or 'flye', got '${params.assembler}'"
    }
    if (!(params.model in medaka_models)) {
        error "Unknown --model '${params.model}'. Known models:\n  ${medaka_models.join('\n  ')}"
    }
    // Both databases are optional -- the step that uses one is skipped when it
    // is not given. A path that IS given must exist, so a typo fails now rather
    // than silently disabling the check.
    [kraken2_db: params.kraken2_db, mito_db: params.mito_db].each { name, path ->
        if (path && !file(path).exists()) {
            error "--${name} does not exist: ${path}"
        }
    }
}

// Main workflow
workflow {
    validateParams()

    log.info """\

         N A N O   A S S E M B L E R
    =====================================
    ${workflow.manifest.name} v${workflow.manifest.version}
    =====================================
               INPUT PARAMETERS
    Samplesheet         : ${params.input}
    Output Folder       : ${params.outdir}
    =====================================
            ADDITIONAL PARAMETERS
    Skip Porechop       : ${params.skip_porechop}
    Minimum Read Length : ${params.min_length}
    Minimum Mean Q      : ${params.min_mean_q}
    Assembler           : ${params.assembler}
    Assembly Coverage   : ${params.coverage}
    Purge Duplicates    : ${params.purge_dups}
    Basecalling Model   : ${params.model}
    BUSCO lineage       : ${params.lineage}
    Telomere Repeat     : ${params.telomere}
    Kraken2 DB          : ${params.kraken2_db ?: 'not set - contamination screening skipped'}
    Mito BLAST DB       : ${params.mito_db ?: 'not set - organelle check skipped'}
    =====================================
            RUN INFORMATION
    Container Engine    : ${workflow.containerEngine ?: 'none'}
    Profile             : ${workflow.profile}
    Nextflow version    : ${nextflow.version}
    Launch dir          : ${workflow.launchDir}
    =====================================
    """.stripIndent()

    // Bound to a local first: inside the handler closure `workflow` resolves
    // against the closure delegate and comes back null.
    def wf = workflow
    workflow.onComplete {
        log.info "Pipeline completed at: ${wf.complete}"
        log.info "Execution status: ${ wf.success ? 'OK' : 'failed' }"
    }

    // Create input channel from samplesheet: [sample_id, fastq, genome_size, illumina]
    samplesheet_ch = parseSamplesheet(params.input)

    reads_gs_ch = samplesheet_ch.map { id, fastq, gs, _ill -> tuple(id, fastq, gs) }

    // Only samples that declared short reads reach this channel, so joining
    // against it is what gates Merqury -- samples without them drop out.
    illumina_ch = samplesheet_ch
        .filter { _id, _fastq, _gs, ill -> ill }
        .map { id, _fastq, _gs, ill -> tuple(id, ill) }

    // Version tracking channel
    ch_versions = Channel.empty()

    // Subworkflow: Read QC
    // Extract just [sample_id, fastq] for Read QC
    READ_QC(reads_gs_ch.map { id, fastq, _gs -> tuple(id, fastq) })
    ch_versions = ch_versions.mix(READ_QC.out.versions)

    // Subworkflow: Assembly and Polishing
    // ASSEMBLY needs [sample_id, fastq, genome_size]
    // We join filtered reads back with their genome size
    assembly_input_ch = READ_QC.out.filtered_reads
        .join(reads_gs_ch.map { id, _fastq, gs -> tuple(id, gs) })

    ASSEMBLY(assembly_input_ch)
    ch_versions = ch_versions.mix(ASSEMBLY.out.versions)

    // Subworkflow: Post-Assembly QC
    // ASSEMBLY_QC needs [sample_id, fastq, assembly, genome_size], kraken2_db, mito_db
    // Prepare input by joining all pieces
    qc_input_ch = READ_QC.out.filtered_reads
        .join(ASSEMBLY.out.consensus)
        .join(reads_gs_ch.map { id, _fastq, gs -> tuple(id, gs) })

    ASSEMBLY_QC(
        qc_input_ch,
        illumina_ch,
        params.kraken2_db,
        params.mito_db
    )
    ch_versions = ch_versions.mix(ASSEMBLY_QC.out.versions)

    // Turn the outputs MultiQC cannot parse natively into custom-content tables.
    // Channels are keyed on sample_id, so join() keeps them aligned.
    MQC_TABLES(
        ASSEMBLY_QC.out.gfastats_stats
            .join(READ_QC.out.jellyfish_summary)
    )
    ch_versions = ch_versions.mix(MQC_TABLES.out.versions)

    // Empty for runs without short reads, in which case no Merqury table appears.
    MQC_MERQURY(
        ASSEMBLY_QC.out.merqury_qv
            .join(ASSEMBLY_QC.out.merqury_completeness)
    )
    ch_versions = ch_versions.mix(MQC_MERQURY.out.versions)

    // Software versions aggregation. Every module emits a file literally named
    // versions.yml, so collect() would stage N identical names into one task
    // and fail on the collision. collectFile concatenates them first -- each
    // versions.yml is a standalone YAML mapping, so the result is still valid.
    CUSTOM_DUMP_SOFTWARE_VERSIONS(
        ch_versions.collectFile(name: 'collated_versions.yml', sort: true)
    )

    // Collect all QC reports for MultiQC
    multiqc_files = Channel.empty()
    multiqc_files = multiqc_files.mix(
        READ_QC.out.nanoplot_trimmed,
        READ_QC.out.nanoplot_filtered,
        MQC_TABLES.out.tables,
        MQC_MERQURY.out.tables,
        ASSEMBLY_QC.out.busco_summary,
        ASSEMBLY_QC.out.kraken2_report,
        ASSEMBLY_QC.out.mosdepth_global_dist,
        ASSEMBLY_QC.out.mosdepth_summary,
        CUSTOM_DUMP_SOFTWARE_VERSIONS.out.mqc_yaml
    )

    // MultiQC
    MULTIQC(multiqc_files.collect())
}
