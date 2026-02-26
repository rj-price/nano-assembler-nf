//
// Subworkflow: Assembly and Polishing
//

include { NECAT } from '../modules/necat'
include { RACON } from '../modules/racon'
include { MEDAKA } from '../modules/medaka'

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

    emit:
    consensus = MEDAKA.out.consensus
    versions
}
