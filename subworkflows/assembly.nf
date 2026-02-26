//
// Subworkflow: Assembly and Polishing
//

include { NECAT } from '../modules/necat'
include { RACON } from '../modules/racon'
include { MEDAKA } from '../modules/medaka'
include { RENAME_CONTIGS } from '../modules/rename_contigs'

workflow ASSEMBLY {
    take:
    reads_ch    // channel: [val(sample_id), path(fastq)]
    genome_size // val: genome_size

    main:
    versions = Channel.empty()

    // NECAT
    NECAT(reads_ch, genome_size)
    versions = versions.mix(NECAT.out.versions)

    // Racon
    RACON(reads_ch, NECAT.out.assembly)
    versions = versions.mix(RACON.out.versions)

    // Medaka
    MEDAKA(reads_ch, RACON.out.polished)
    versions = versions.mix(MEDAKA.out.versions)

    // Rename and Sort Contigs
    RENAME_CONTIGS(MEDAKA.out.consensus)
    versions = versions.mix(RENAME_CONTIGS.out.versions)

    emit:
    consensus = RENAME_CONTIGS.out.renamed_assembly
    versions
}
