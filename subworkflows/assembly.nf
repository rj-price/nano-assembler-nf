//
// Subworkflow: Assembly and Polishing
//

include { NECAT } from '../modules/necat'
include { FLYE } from '../modules/flye'
include { PURGE_DUPS } from '../modules/purge_dups'
include { RACON } from '../modules/racon'
include { MEDAKA } from '../modules/medaka'
include { RENAME_CONTIGS } from '../modules/rename_contigs'

workflow ASSEMBLY {
    take:
    reads_gs_ch    // channel: [val(sample_id), path(fastq), val(genome_size)]

    main:
    versions = Channel.empty()

    reads_ch = reads_gs_ch.map { id, fq, _gs -> tuple(id, fq) }

    // Assembler is selected by param, so only one branch is ever instantiated.
    if (params.assembler == 'flye') {
        FLYE(reads_gs_ch)
        versions = versions.mix(FLYE.out.versions)
        draft = FLYE.out.assembly
    }
    else {
        NECAT(reads_gs_ch)
        versions = versions.mix(NECAT.out.versions)
        draft = NECAT.out.assembly
    }

    // Optional haplotig purging for heterozygous diploids
    if (params.purge_dups) {
        PURGE_DUPS(reads_ch.join(draft))
        versions = versions.mix(PURGE_DUPS.out.versions)
        draft = PURGE_DUPS.out.purged
    }

    // Racon. join() pairs on sample_id; the previous two-channel form paired on
    // emission order, which mispairs as soon as there is more than one sample.
    RACON(reads_ch.join(draft))
    versions = versions.mix(RACON.out.versions)

    // Medaka
    MEDAKA(reads_ch.join(RACON.out.polished))
    versions = versions.mix(MEDAKA.out.versions)

    // Rename and Sort Contigs
    RENAME_CONTIGS(MEDAKA.out.consensus)
    versions = versions.mix(RENAME_CONTIGS.out.versions)

    emit:
    consensus = RENAME_CONTIGS.out.renamed_assembly
    versions
}
