### python script for obtaining lines not checked as shown by forge coverage
###IMPORTANT###
### User must fist run make report (forge coverage --report debug >debug.txt) to ensure debug.txt has been created

import re

def parse_debug_file(file_path):
    with open(file_path, 'r') as file:
        content = file.read()

    uncovered_sections = re.findall(r'Uncovered for (.+?):\n((?:.*\n)*?)(?:\n|$)', content)

    summary = {}
    for section, details in uncovered_sections:
        if section not in summary:
            summary[section] = []
        
        uncovered_items = re.findall(r'- (.+): (.+), hits: 0\)', details)
        for item_type, item_content in uncovered_items:
            summary[section].append(f"{item_type}: {item_content}")

    return summary

def write_summary(summary, output_file):
    with open(output_file, 'w') as file:
        for contract, items in summary.items():
            if items:  # Only write data for contracts with uncovered elements
                file.write(f"Contract: {contract}\n")
                file.write(f"  Uncovered elements: {len(items)}\n")
                for item in items:
                    file.write(f"    - {item}\n")
                file.write("\n")

# Usage
debug_file = 'debug.txt'
output_file = 'debug-refined.txt'

summary = parse_debug_file(debug_file)
write_summary(summary, output_file)
print(f"Summary has been written to {output_file}")