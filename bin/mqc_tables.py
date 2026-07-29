#!/usr/bin/env python3
"""Convert pipeline outputs MultiQC has no module for into custom-content tables.

MultiQC silently ignores files it cannot parse, so gfastats, Merqury and
GenomeScope2 results were being staged into the report and dropped. Each
converter here emits a `*_mqc.tsv` with the custom-content header MultiQC needs.

Usage:
    mqc_tables.py gfastats   <sample> <genome_stats.tsv>
    mqc_tables.py merqury    <sample> <sample.qv> <sample.completeness.stats>
    mqc_tables.py genomescope <sample> <summary.txt>
"""

import re
import sys


def write_mqc(out_path, mqc_id, section_name, description, headers, rows):
    """Write a MultiQC custom-content table.

    Filenames are sample-prefixed because MultiQC stages every input flat, but
    the `id` is shared so rows from all samples merge into one table.
    """
    with open(out_path, "w") as fh:
        fh.write(f"# id: '{mqc_id}'\n")
        fh.write(f"# section_name: '{section_name}'\n")
        fh.write(f"# description: '{description}'\n")
        fh.write("# format: 'tsv'\n")
        fh.write("# plot_type: 'table'\n")
        fh.write("Sample\t" + "\t".join(headers) + "\n")
        for row in rows:
            fh.write("\t".join(str(v) for v in row) + "\n")


def gfastats(sample, stats_file):
    """gfastats --tabular emits `key<TAB>value` lines; keep the headline metrics."""
    wanted = [
        ("# contigs", "Contigs"),
        ("Total contig length", "Total length"),
        ("Contig N50", "N50"),
        ("Contig L50", "L50"),
        ("Largest contig", "Largest contig"),
        ("GC content %", "GC %"),
        ("# gaps in scaffolds", "Gaps"),
    ]
    values = {}
    with open(stats_file) as fh:
        for line in fh:
            parts = line.rstrip("\n").split("\t")
            if len(parts) >= 2:
                values[parts[0].strip()] = parts[1].strip()

    headers = [label for _, label in wanted]
    row = [sample] + [values.get(key, "NA") for key, _ in wanted]
    write_mqc(
        f"{sample}_gfastats_mqc.tsv",
        "gfastats",
        "Assembly statistics (gfastats)",
        "Contiguity metrics for the final polished assembly.",
        headers,
        [row],
    )


def merqury(sample, qv_file, completeness_file):
    """Merqury writes whole-assembly QV and k-mer completeness as short TSVs."""
    qv = "NA"
    with open(qv_file) as fh:
        for line in fh:
            fields = line.rstrip("\n").split("\t")
            # Header row was prepended by the module; data row has QV in col 4.
            if len(fields) >= 4 and not line.startswith("seq"):
                qv = fields[3]
                break

    completeness = "NA"
    with open(completeness_file) as fh:
        for line in fh:
            fields = line.rstrip("\n").split("\t")
            if len(fields) >= 5 and not line.startswith("assembly"):
                completeness = fields[4]
                break

    write_mqc(
        f"{sample}_merqury_mqc.tsv",
        "merqury",
        "Merqury k-mer QV",
        "Consensus quality and k-mer completeness, computed from the sample's "
        "Illumina reads.",
        ["QV", "K-mer completeness (%)"],
        [[sample, qv, completeness]],
    )


def genomescope(sample, summary_file):
    """Scrape the headline estimates out of GenomeScope2's text summary."""
    # GenomeScope2 labels the heterozygosity row "Heterozygous (ab)".
    patterns = {
        "Heterozygosity (%)": r"Heterozygous \(ab\)\s+([\d.]+)%",
        "Genome haploid length (bp)": r"Genome Haploid Length\s+([\d,]+) bp",
        "Genome repeat length (bp)": r"Genome Repeat Length\s+([\d,]+) bp",
        "Model fit (%)": r"Model Fit\s+([\d.]+)%",
        "Read error rate (%)": r"Read Error Rate\s+([\d.]+)%",
    }
    text = open(summary_file).read()

    headers, row = [], [sample]
    for label, pattern in patterns.items():
        match = re.search(pattern, text)
        headers.append(label)
        row.append(match.group(1).replace(",", "") if match else "NA")

    write_mqc(
        f"{sample}_genomescope_mqc.tsv",
        "genomescope",
        "GenomeScope2 k-mer profile",
        "Genome size and heterozygosity estimated from read k-mers. NOTE: "
        "GenomeScope2 assumes accurate reads; ONT estimates are indicative only.",
        headers,
        [row],
    )


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)

    mode, sample, args = sys.argv[1], sys.argv[2], sys.argv[3:]
    converters = {"gfastats": gfastats, "merqury": merqury, "genomescope": genomescope}

    if mode not in converters:
        sys.exit(f"Unknown mode '{mode}'. Expected one of {sorted(converters)}.")

    converters[mode](sample, *args)


if __name__ == "__main__":
    main()
