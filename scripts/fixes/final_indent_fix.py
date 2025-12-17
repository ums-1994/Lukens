#!/usr/bin/env python3
"""
Final comprehensive fix for indentation issues.
Fixes malformed dictionary returns and other indentation problems.
"""

import re

def fix_malformed_returns(content):
    """Fix lines like 'return {' that have wrong indentation"""
    lines = content.split('\n')
    result = []
    
    for i, line in enumerate(lines):
        # Check for the pattern where return dict starts wrong
        if 'return {' in line and line.strip().startswith('return {'):
            # Count spaces
            spaces = len(line) - len(line.lstrip())
            
            # If it has 16 spaces but should have 12 (for return in a try block)
            # Fix it
            if spaces > 16:
                line = '            ' + line.lstrip()
            elif spaces > 20:
                # Way too many spaces
                line = '            ' + line.lstrip()
        
        result.append(line)
    
    return '\n'.join(result)


def main():
    filepath = r'c:\Users\Unathi Sibanda\Documents\Lukens-Unathi-Test\backend\app.py'
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    print("Applying final indentation fixes...")
    fixed = fix_malformed_returns(content)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(fixed)
    
    print("✅ Final fixes applied!")
    
    # Quick syntax check
    try:
        compile(fixed, 'app.py', 'exec')
        print("✅ Python syntax is valid!")
    except SyntaxError as e:
        print(f"⚠️  Syntax error at line {e.lineno}: {e.msg}")
        return False
    
    return True


if __name__ == '__main__':
    main()