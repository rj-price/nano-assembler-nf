//
// Subworkflow: Read QC
//

include { PORECHOP } from '../modules/porechop'
include { NANOPLOT as NANOPLOT_TRIMMED } from '../modules/nanoplot'
include { NANOPLOT as NANOPLOT_FILTERED } from '../modules/nanoplot'
include { FILTLONG } from '../modules/filtlong'
include { JELLYFISH } from '../modules/jellyfish'

workflow READ_QC {
    take:
    reads_ch // channel: [val(sample_id), path(fastq)]

    main:
    versions = Channel.empty()

    // Porechop. Skippable for reads that were already chopped, or basecalled
    // with dorado (which trims adapters itself).
    if (params.skip_porechop) {
        trimmed_ch = reads_ch
    }
    else {
        PORECHOP(reads_ch)
        versions = versions.mix(PORECHOP.out.versions)
        trimmed_ch = PORECHOP.out.porechopped
    }

    // NanoPlot trimmed reads
    NANOPLOT_TRIMMED(trimmed_ch, 'trimmed')
    versions = versions.mix(NANOPLOT_TRIMMED.out.versions)

    // Filtlong
    FILTLONG(trimmed_ch)
    versions = versions.mix(FILTLONG.out.versions)

    // NanoPlot filtered reads
    NANOPLOT_FILTERED(FILTLONG.out.filtered, 'filtered')
    versions = versions.mix(NANOPLOT_FILTERED.out.versions)

    // Jellyfish and GenomeScope2
    JELLYFISH(FILTLONG.out.filtered)
    versions = versions.mix(JELLYFISH.out.versions)

    emit:
    filtered_reads = FILTLONG.out.filtered
    nanoplot_trimmed = NANOPLOT_TRIMMED.out.plots.flatten()
    nanoplot_filtered = NANOPLOT_FILTERED.out.plots.flatten()
    jellyfish_summary = JELLYFISH.out.summary
    versions
}
