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

    // Porechop
    PORECHOP(reads_ch)
    versions = versions.mix(PORECHOP.out.versions)

    // NanoPlot trimmed reads
    NANOPLOT_TRIMMED(PORECHOP.out.porechopped, 'trimmed')
    versions = versions.mix(NANOPLOT_TRIMMED.out.versions)

    // Filtlong
    FILTLONG(PORECHOP.out.porechopped)
    versions = versions.mix(FILTLONG.out.versions)

    // NanoPlot filtered reads
    NANOPLOT_FILTERED(FILTLONG.out.filtered, 'filtered')
    versions = versions.mix(NANOPLOT_FILTERED.out.versions)
    
    // Jellyfish and GenomeScope2
    JELLYFISH(FILTLONG.out.filtered)
    versions = versions.mix(JELLYFISH.out.versions)

    emit:
    filtered_reads = FILTLONG.out.filtered
    nanoplot_trimmed = NANOPLOT_TRIMMED.out.flatten()
    nanoplot_filtered = NANOPLOT_FILTERED.out.flatten()
    versions
}
