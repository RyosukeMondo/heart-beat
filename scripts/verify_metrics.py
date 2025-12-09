#!/usr/bin/env python3
import os
import re
import sys

# Thresholds
MAX_FILE_LOC = 500
MAX_FUNC_LOC = 50
MAX_COMPLEXITY = 10

def remove_comments(text):
    def replacer(match):
        s = match.group(0)
        if s.startswith('/'):
            return " " # note: a space and not an empty string
        else:
            return s
    pattern = re.compile(
        r'//.*?$|/\*.*?\*/|\'(?:\\.|[^\\\'])*\'|"(?:\\.|[^\\"])*"',
        re.DOTALL | re.MULTILINE
    )
    return re.sub(pattern, replacer, text)

def count_file_loc(text):
    lines = text.split('\n')
    count = 0
    for line in lines:
        if line.strip():
            count += 1
    return count

def calculate_complexity(text):
    # This is a naive approximation
    score = 1 # Base complexity

    # Keyword based checks
    # match whole words only
    keywords = [
        r'\bif\b', r'\belse if\b', r'\bfor\b', r'\bwhile\b',
        r'\bdo\b', r'\bcase\b', r'\bcatch\b'
    ]

    for kw in keywords:
        score += len(re.findall(kw, text))

    # Operator based checks
    operators = [
        r'&&', r'\|\|', r'\?'
    ]
    for op in operators:
        score += len(re.findall(op, text))

    return score

def get_indentation(line):
    return len(line) - len(line.lstrip())

def analyze_functions(text, filename):
    lines = text.split('\n')
    violations = []

    # Naive function extractor based on braces
    # We assume functions start with a declaration and a {
    # and end with a matching }

    brace_balance = 0
    in_function = False
    func_start_line = 0
    func_content = []
    func_name = "unknown"

    # Regex to identify function definition
    # Look for: type name(args) { or name(args) {
    # Exclude typical control structures
    func_def_pattern = re.compile(r'^\s*(([\w<>?]+)\s+)?(\w+)\s*\(.*?\)\s*(async\s*)?\{')
    control_keywords = ['if', 'for', 'while', 'switch', 'catch', 'do']

    for i, line in enumerate(lines):
        clean_line = line.strip()

        # Count braces in the line (ignoring strings/chars ideally, but comments are already removed)
        # We need to be careful not to count braces in strings if we didn't remove strings properly.
        # remove_comments handles strings so they are preserved. We should probably mask strings for brace counting.

        # Mask strings for structural analysis
        line_no_strings = re.sub(r"'(?:\\.|[^\\\'])*'", "''", line)
        line_no_strings = re.sub(r'"(?:\\.|[^\\"])*"', '""', line_no_strings)

        open_braces = line_no_strings.count('{')
        close_braces = line_no_strings.count('}')

        if not in_function:
            # Check if this line starts a function
            # It must have an open brace and look like a function
            if open_braces > close_braces: # Net increase
                match = func_def_pattern.search(line_no_strings)
                if match:
                    name = match.group(3)
                    if name not in control_keywords:
                        in_function = True
                        brace_balance = 0 # Will add open braces below
                        func_start_line = i
                        func_name = name
                        func_content = []

        if in_function:
            func_content.append(line)
            brace_balance += open_braces
            brace_balance -= close_braces

            if brace_balance == 0:
                in_function = False
                # Function ended
                # Analyze function
                func_text = "\n".join(func_content)
                loc = 0
                for fl in func_content:
                    if fl.strip():
                        loc += 1

                # Exclude the wrapper { and } from complexity logic generally,
                # but our complexity calc just scans text.
                complexity = calculate_complexity(func_text)

                if loc > MAX_FUNC_LOC:
                    violations.append(f"  - Function '{func_name}' (line {func_start_line+1}): LOC {loc} > {MAX_FUNC_LOC}")

                if complexity > MAX_COMPLEXITY:
                    violations.append(f"  - Function '{func_name}' (line {func_start_line+1}): Complexity {complexity} > {MAX_COMPLEXITY}")

    return violations

def main():
    has_violations = False
    root_dir = 'lib'

    if len(sys.argv) > 1:
        root_dir = sys.argv[1]

    print(f"Analyzing Dart files in {root_dir}...")

    for root, dirs, files in os.walk(root_dir):
        for file in files:
            if file.endswith('.dart'):
                filepath = os.path.join(root, file)
                try:
                    with open(filepath, 'r', encoding='utf-8') as f:
                        content = f.read()

                    content_no_comments = remove_comments(content)
                    file_loc = count_file_loc(content_no_comments)

                    file_violations = []

                    if file_loc > MAX_FILE_LOC:
                        file_violations.append(f"  - File LOC {file_loc} > {MAX_FILE_LOC}")

                    func_violations = analyze_functions(content_no_comments, filepath)
                    file_violations.extend(func_violations)

                    if file_violations:
                        print(f"VIOLATION: {filepath}")
                        for v in file_violations:
                            print(v)
                        has_violations = True

                except Exception as e:
                    print(f"Error processing {filepath}: {e}")

    if has_violations:
        sys.exit(1)
    else:
        print("No violations found.")
        sys.exit(0)

if __name__ == "__main__":
    main()
