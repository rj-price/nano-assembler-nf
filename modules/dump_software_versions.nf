process CUSTOM_DUMP_SOFTWARE_VERSIONS {
    publishDir "${params.outdir}/pipeline_info", mode: 'copy'
    container 'python:3.10-slim-buster'

    input:
    path 'versions_??.yml'

    output:
    path "software_versions.yml"    , emit: yaml
    path "software_versions_mqc.yml", emit: mqc_yaml
    path "versions.yml"             , emit: versions

    script:
    """
    python3 ${baseDir}/bin/dump_software_versions.py versions_??.yml

    # Create MultiQC compatible version
    cat <<-END_YAML > software_versions_mqc.yml
    id: 'software_versions'
    section_name: 'Software Versions'
    plot_type: 'html'
    description: 'Software versions used in the pipeline.'
    data: |
        <dl class="dl-horizontal">
    END_YAML

    # Parse and format YAML into HTML for MultiQC
    python3 -c "import yaml; d=yaml.safe_load(open('software_versions.yml')); [print(f'            <dt>{p}</dt><dd><samp>{v}</samp></dd>') for p, tools in d.items() for tool, v in tools.items()]" >> software_versions_mqc.yml

    echo "        </dl>" >> software_versions_mqc.yml

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //')
    END_VERSIONS
    """
}
