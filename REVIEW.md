# nano-assembler-nf — pipeline review

Review of the pipeline as a fungal ONT assembler, July 2026. Verified against
`nextflow lint` (NF 25.04.2), a two-sample `-stub-run`, and the gruffalo partition limits.

Part 1 lists what was fixed in this pass. Part 2 is the methodological critique — decisions
that need your judgement rather than a patch. Part 3 is the prioritised backlog.

---

## Part 1 — Defects found and fixed

| # | Defect | Impact |
|---|--------|--------|
| B1 | Wrapper never passed `--kraken2_db`/`--mito_db`, both defaulting to `null` and consumed as `path` inputs | The documented `sbatch` command could not run at all. Both databases are now **optional**: the step that needs one is skipped when it is absent, and no site-specific path is baked into the config |
| B2 | `sample_id` declared twice in five modules' inputs | Legal under the legacy parser, **an error under the strict syntax** that becomes default in NF 25.10 |
| B3 | SLURM queue selected from memory only | Any retry of a ≤10 GB process asked for 8 h on the 6 h `short` partition |
| B4 | Bare `grep -c ">"` in `MITO_CHECK` under `set -o pipefail` | Task died whenever an assembly had *no* mitochondrial contig |
| B5 | NanoPlot outputs prefixed by stage but not sample | Two samples ⇒ `trimmed_NanoStats.txt` collided in MultiQC's flat staging |
| B6 | gfastats / Merqury / GenomeScope2 have no MultiQC module | Those results were staged into the report and silently dropped |
| B7 | `params.prefix` required but unused; `params.results_dir` unused; `conda` profile with no `conda:` directive anywhere | Dead surface area; the profile actively misleads |
| B8 | Head job on `medium` (24 h cap), no `--time`, no `set -euo pipefail`, no shared image cache | Long runs outlived their head job; images re-pulled per output directory |
| **B9** | **Every module emits a file named `versions.yml`, all `collect()`ed into one process** | **Input filename collision — the version-tracking step failed on any real run.** Found by the stub run; not visible from reading the code |

B9 is the one worth noting: it is not a multi-sample edge case. `CUSTOM_DUMP_SOFTWARE_VERSIONS`
would have failed on a single-sample run too. It is now `collectFile`-based, which is what
nf-core does for exactly this reason.

### Also changed

- The five order-paired modules (`RACON`, `MEDAKA`, `COVERAGE`, `MERQURY`, `TAPESTRY`) plus the
  `genome_size` inputs of `NECAT`/`GFASTATS` now take a single joined tuple. Previously they
  took separate channels paired by **emission order**, so with more than one sample the
  pipeline could polish sample A's assembly with sample B's reads — silently, with no error.
  This fix and B2 are the same edit.
- `params.telomere` — Tapestry's motif was hardcoded to `TTAGGG`.
- `params.skip_porechop`, `params.assembler`, `params.purge_dups`.
- Up-front validation of `--model`, `--assembler` and database paths.
- `stub:` blocks in every module, and a `test` profile for SC5314.
- `NECAT` 4 → 16 cpus with a 12 h time budget.

---

## Part 2 — Methodological critique

### Merqury QV is circular as configured — RESOLVED

*Fixed: Merqury now builds its meryl database from an optional `illumina` samplesheet column
and is skipped entirely for samples without short reads. The four SC5314 runs below are what
motivated it — QV sat at 33.1–33.7 across assemblies ranging from 10 to 26 contigs, i.e. it did
not discriminate between them at all.*


`modules/merqury.nf` builds the meryl k-mer database from **the same ONT reads that produced the
assembly**. Merqury's QV assumes an independent, high-accuracy k-mer set; feeding it the assembly's
own reads means systematic basecalling errors appear in both the assembly and the truth set, so
they cancel. The reported QV is not an accuracy estimate — it mostly measures how faithfully the
consensus reproduces its own input.

This matters most for exactly the case the pipeline targets: a fungal genome where you want to
know whether the assembly is Q40 or Q50 before annotating it.

**Suggested fix:** add an optional `illumina` column to the samplesheet; build the meryl DB from
those reads when present and skip Merqury when absent. A short-read-free run should report *no*
QV rather than a flattering one. The MultiQC table now carries a caveat in its description, but
that is a mitigation, not a fix.

### GenomeScope2 on ONT k-mers

Same root cause, lower stakes. GenomeScope2's model assumes read errors are rare and random;
ONT error k-mers inflate the low-coverage tail and bias the heterozygosity and genome-size
estimates. Useful as a relative signal across samples from one run, not as an absolute. Also
flagged in the MultiQC description.

### Telomere motif was hardcoded

`--telomere TTAGGG` was baked into the module. The motif itself is a sound default — TTAGGG is
the canonical telomere repeat across most filamentous ascomycetes and basidiomycetes
(*Neurospora*, *Aspergillus*, *Fusarium*, *Magnaporthe*, *Cryptococcus*), so counts from
filamentous-fungal runs were fine.

The yeasts are where it breaks: *C. albicans* uses a 23-bp unit
(`ACGGATGTCTAACTTCTTGGTGT`), *S. cerevisiae* an irregular TG(1-3), and for those the count was
meaningless. Now `params.telomere`, defaulting to TTAGGG and overridden in the test profile.
Only yeast projects need to revisit past telomere numbers.

### No haplotig purging on a diploid organism

*C. albicans* is a heterozygous diploid, and many target fungi are diploid or aneuploid. Without
purging, heterozygous regions assemble as separate contigs, inflating assembly size and showing
up as elevated BUSCO **Duplicated**. `purge_dups` is now available via `--purge_dups`, defaulting
off so nothing changes for existing projects.

Worth checking on the SC5314 run: assembly size meaningfully above 14.3 Mb, or BUSCO duplication
above a few percent, both point at unpurged haplotigs.

### The polishing chain is one generation behind

- **Racon before Medaka.** ONT's guidance for R10.4.1 sup basecalls is that Medaka's models are
  trained on assemblies polished from the raw reads; an intervening Racon round can *reduce*
  final accuracy. Only one Racon round runs here, where the historical recommendation was 2–4 —
  so the current setup gets the cost of Racon without the benefit.
- **Medaka is being sunset** in favour of `dorado polish` / `dorado correct`. Gruffalo has an
  A100 `gpu` partition, so this is practical here, though it means a GPU-partition process and a
  wider change than this pass.
- **The model is fetched by `wget` per task** from GitHub `master`. Compute nodes need internet,
  the URL is unversioned, and a bad model name previously failed at the download rather than at
  validation. Validation is now up front; pre-staging the model directory would remove the
  network dependency entirely.

### NECAT

Frozen at `0.0.1_update20200803` and effectively unmaintained. It was a strong R9 assembler and
still produces good fungal assemblies, but it predates R10.4.1 chemistry and gets no fixes.
Flye 2.9.6 is now selectable with `--assembler flye`; it is actively maintained, handles
`--nano-hq` sup basecalls, and emits an assembly graph (useful for judging whether contig ends
are genuinely resolved). Worth benchmarking on SC5314 before switching the default.

### Version audit

| Tool | Pinned | Current | Note |
|------|--------|---------|------|
| BUSCO | 5.2.2 | 5.8.x | Four years of lineage and metaeuk fixes missed |
| Porechop | 0.2.4 | — | Unmaintained since 2018; adapter set predates LSK114 |
| NECAT | 2020 update | — | Unmaintained |
| Tapestry | `nanozoo/tapestry:1.0.0` | — | Unmaintained community image |
| Medaka | 2.0.1 | — | Superseded by `dorado polish` |
| Flye | 2.9.6 | 2.9.6 | Added this pass |
| Kraken2 | 2.1.3 | 2.1.3 | Current |
| MultiQC | 1.25.1 | — | Fine |

Two specific hazards:

- `modules/merqury.nf` hardcodes `MERQURY=/opt/conda/pkgs/merqury-1.3-hdfd78af_3/share/merqury`.
  Any container bump changes that path and breaks the module with a confusing error.
- **Porechop is the weakest link.** It is slow, memory-hungry (30 GB requested), and its adapter
  database no longer matches current kits. For dorado-basecalled data it is redundant — dorado
  trims adapters itself. `porechop_abi`, which infers adapters from the data, is the better
  successor. `--skip_porechop` now exists as the immediate escape hatch.

### Per-task database downloads

BUSCO downloads its lineage on every task and Medaka fetches its model on every task. Both need
outbound internet from compute nodes, both re-download per sample, and both fail late. BUSCO
supports `--offline` with a pre-populated `--download_path`; you already have a `busco` conda env
that likely has the lineages cached.

### Aneuploidy goes unreported

*Candida* strains are frequently aneuploid, and whole-chromosome copy-number change is a real
biological result, not an artefact. `mosdepth` already writes per-contig mean depth in
`*.mosdepth.summary.txt` — plotting depth per contig against the genome-wide median would surface
aneuploidy for nearly no extra compute. Currently only the global distribution reaches MultiQC.

### errorStrategy ends the run on optional QC failures

`errorStrategy` retries only OOM/kill codes and otherwise uses `finish`. A single BUSCO lineage
download failure therefore takes down a whole multi-sample run after the expensive assembly work
has completed. QC processes that do not feed downstream steps (`BUSCO`, `TAPESTRY`, `MITO_CHECK`,
`KRAKEN2`, `MERQURY`) would be better as `errorStrategy 'ignore'`.

**Observed in practice.** During variant testing, a transient SLURM prolog failure hit two
unrelated compute nodes simultaneously. The tasks reported *no* exit status, which was not in the
retry list, so `finish` discarded two entire runs at their first task. The retry condition now
also covers a missing/unknown exit status (characteristic of node-side infrastructure failure)
and `maxRetries` is 2 — but the `ignore`-on-optional-QC change above is still outstanding, and
matters more once a run has hours of assembly behind it.

### `check_max()` blocks the same upgrade as B2 — RESOLVED

*Fixed: replaced by the built-in `resourceLimits` directive. `def trace_timestamp` was the same
problem and moved into `params`. `nextflow.config` now lints clean, so nothing in the repo
blocks the strict-syntax upgrade. Requires Nextflow >= 24.04, and the manifest floor was raised
from 21.10.3 to match.*


`nextflow.config` defines `def check_max(obj, type)` and calls it from every resource directive.
Functions are not permitted in config files under the strict config syntax — `nextflow lint`
reports `Unexpected input: '('` at that definition. Nextflow 25.04 still accepts it, so nothing
is broken today, but it will fail on the same upgrade that would have broken the duplicate
`sample_id` declarations (B2).

The modern replacement is the built-in `resourceLimits` directive, which removes `check_max`
entirely:

```groovy
process {
    resourceLimits = [ cpus: 16, memory: 128.GB, time: 240.h ]
}
```

This is a mechanical change across every `withName:` block and should be done as its own commit.

### Contamination screening only sees the assembly

Kraken2 runs on contigs, which finds contaminant contigs that assembled but misses low-level
contamination that never assembled. Screening the filtered reads as well is cheap with the 16 GB
database already in use.

### Not evaluated

No `nf-test` suite, no CI, and no assembly-level comparison against a reference. The `stub:`
blocks added here make the DAG testable in seconds, which is the precondition for adding
`nf-test` cases — but they check plumbing, not results.

---

## Part 2b — Resource sizing, measured

Peak RSS across the four SC5314 runs (14.3 Mb genome), against the original requests:

| Process | Was | Peak RSS | Now | Note |
|---|---|---|---|---|
| RACON | 40 GB | 5.1 GB | 12 GB | was 8x over |
| MEDAKA | 40 GB | 8.2 GB | 16 GB | was 5x over |
| JELLYFISH | 20 GB | 3.5 GB | 8 GB | was 6x over |
| FILTLONG | 10 GB | 0.3 GB | 4 GB | was 33x over |
| MERQURY | 16 GB | 4.6 GB | 10 GB | |
| FLYE | 40 GB | 13.1 GB | 24 GB | |
| PURGE_DUPS | 16 GB | 1.1 GB | 8 GB | |
| BUSCO | 3 GB | 1.7 GB | 4 GB | was slightly under |
| NECAT | 40 GB | 25.0 GB | 40 GB | already right |
| KRAKEN2 | 18 GB | 13.6 GB | 18 GB | set by the database, cpus 4 -> 2 (only ~1 used) |
| COVERAGE | default 4 GB / 1 cpu | 2.3 GB | 6 GB / 4 cpu | minimap2 was pinned to one core |
| NANOPLOT | default 4 GB / 1 cpu | 2.3 GB | 6 GB / 4 cpu | |
| PORECHOP | 30 GB | **not measured** | 30 GB | skipped in every run; confirm with `seff` when it first runs |

Sized at ~2x observed peak. **These are for a 14.3 Mb genome** — a 60 Mb assembly will need more,
so re-check against the execution trace rather than assuming these carry over.

Partition effects: JELLYFISH and MERQURY drop under 10 GB and so move to `short` (6 h cap), which
is comfortable at this genome size but worth watching on larger ones. RACON and MEDAKA stay on
`medium`. NECAT is unchanged.

## Part 3 — Prioritised backlog

| Priority | Item | Why |
|---|---|---|
| ~~1~~ | ~~Gate Merqury on short reads~~ | **Done** — optional `illumina` column |
| 2 | Override `params.telomere` for yeast projects (default TTAGGG suits filamentous fungi) | Silently wrong results, not an error |
| ~~3~~ | ~~`errorStrategy 'ignore'` on non-essential QC~~ | **Done** — `optional_qc` label |
| ~~3=~~ | ~~Replace `check_max()` with `resourceLimits`~~ | **Done** |
| 4 | BUSCO `--offline` + shared lineage path; pre-stage the Medaka model | Removes the compute-node internet dependency |
| 5 | Benchmark Flye vs NECAT on SC5314 | Decides whether to move the default |
| 6 | Bump BUSCO to 5.8.x | Four years of fixes |
| 7 | Replace Porechop with `porechop_abi`, or default `skip_porechop = true` | Wrong adapter set, and slow |
| 8 | Per-contig coverage plot | Aneuploidy is a real result for *Candida* |
| 9 | Evaluate dropping Racon for R10.4.1 sup data | May be actively harmful before Medaka |
| 10 | Kraken2 on reads as well as contigs | Catches unassembled contamination |
| 11 | `nf-test` cases over the samplesheet parser and channel wiring | Stubs make this cheap now |
| 12 | Migrate to `dorado polish` | Medaka is end-of-life; needs the `gpu` partition |
