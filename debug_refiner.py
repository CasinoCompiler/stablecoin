### python script for obtaining lines not checked as shown by forge coverage
###IMPORTANT###
### User must fist run make report (forge coverage --report debug >debug.txt) to ensure debug.txt has been created

import re
from collections import defaultdict

def main():
    debug_file = 'debug.txt'
    output_file = 'debug-refined.txt'

    summary = parse_debug_file(debug_file)
    write_summary(summary, output_file)

def parse_debug_file(file_path):
    try:
        with open(file_path, 'r') as file:
            content = file.read()
    except FileNotFoundError:
        print("debug.txt not found. Ensure 'make report' has been run.")
        return None

    uncovered_sections = re.findall(r'Uncovered for (.+?):\n((?:.*\n)*?)(?:\n|$)', content)

    summary = {}
    for section, details in uncovered_sections:
        if section not in summary:
            summary[section] = defaultdict(list)
        
        uncovered_items = re.findall(r'- (.+): (.+), hits: 0\)', details)
        for item_type, item_content in uncovered_items:
            summary[section][item_type].append(item_content)

    return summary

def write_summary(summary, output_file):
    try:
        with open(output_file, 'w') as file:
            for contract, items in summary.items():
                if items:
                    total_uncovered = sum(len(group) for group in items.values())
                    file.write(f"Contract: {contract}\n")
                    file.write(f"  Uncovered elements: {total_uncovered}\n")
                    
                    for item_type, contents in items.items():
                        if contents:
                            file.write(f"  {item_type} ({len(contents)}):\n")
                            for content in contents:
                                file.write(f"    - {content}\n")
                    
                    file.write("\n")
        print(f"Summary has been written to {output_file}")
    except IOError as e:
        print(f"An error occurred while writing to {output_file}: {e}")

if __name__ == "__main__":
    main()