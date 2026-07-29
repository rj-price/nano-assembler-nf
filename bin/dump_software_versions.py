#!/usr/bin/env python3

import yaml
import sys

def dump_software_versions(versions_list):
    """
    Merge multiple versions.yml files into a single YAML file.
    """
    all_versions = {}
    for f in versions_list:
        with open(f, 'r') as yaml_file:
            versions = yaml.safe_load(yaml_file)
            for process, version_info in versions.items():
                if process not in all_versions:
                    all_versions[process] = {}
                for tool, version in version_info.items():
                    all_versions[process][tool] = version

    # Sort by process name for consistency
    sorted_versions = {k: all_versions[k] for k in sorted(all_versions)}

    with open('software_versions.yml', 'w') as f:
        yaml.dump(sorted_versions, f, default_flow_style=False)

if __name__ == "__main__":
    dump_software_versions(sys.argv[1:])
