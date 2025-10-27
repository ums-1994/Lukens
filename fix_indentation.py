#!/usr/bin/env python3
"""
Fix the broken indentation from the previous cleanup script.
This script will:
1. Remove 4 spaces from over-indented PostgreSQL code
2. Remove all else: blocks with SQLite code
3. Remove all get_sqlite_conn() calls
"""

import re

def fix_indentation_and_remove_sqlite(content):
    lines = content.split('\n')
    result = []
    i = 0
    
    while i < len(lines):
        line = lines[i]
        
        # Check if this is an else: block (indicates we still have SQLite code)
        if line.strip().startswith('else:'):
            # Find the indentation of this else
            else_indent = len(line) - len(line.lstrip())
            
            # Skip this else line and all lines in its block
            i += 1
            while i < len(lines):
                next_line = lines[i]
                if not next_line.strip():  # Empty line
                    i += 1
                    continue
                    
                next_indent = len(next_line) - len(next_line.lstrip())
                
                # If we find a line at or before the else indentation, we're out of the block
                if next_indent <= else_indent:
                    break
                
                i += 1
            continue
        
        # Check if line has over-indentation (starts with 12+ spaces after try:)
        # Over-indented lines are those that should be dedented by 4 spaces
        if line.startswith('            ') and not line.strip().startswith(('#', 'try:', 'except', 'finally')):
            # Check if this is inside a function/try block that needs dedenting
            # We need to be careful not to break legitimate nested structures
            
            # Check if the next few lines also have this over-indentation
            # This is likely a side effect of removing the if statement
            if i + 1 < len(lines) and not lines[i].strip().startswith('return'):
                # Dedent by 4 spaces
                dedented = line[4:] if line.startswith('            ') else line
                result.append(dedented)
                i += 1
                continue
        
        # Check for get_sqlite_conn calls and skip those lines
        if 'get_sqlite_conn' in line:
            i += 1
            continue
        
        result.append(line)
        i += 1
    
    return '\n'.join(result)


def main():
    with open(r'c:\Users\Unathi Sibanda\Documents\Lukens-Unathi-Test\backend\app.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Count before
    before_else = content.count('else:')
    before_sqlite = content.count('get_sqlite_conn')
    
    print(f"Before: {before_else} else blocks, {before_sqlite} get_sqlite_conn calls")
    
    fixed = fix_indentation_and_remove_sqlite(content)
    
    # Count after
    after_else = fixed.count('else:')
    after_sqlite = fixed.count('get_sqlite_conn')
    
    print(f"After: {after_else} else blocks, {after_sqlite} get_sqlite_conn calls")
    
    # Save
    with open(r'c:\Users\Unathi Sibanda\Documents\Lukens-Unathi-Test\backend\app.py', 'w', encoding='utf-8') as f:
        f.write(fixed)
    
    print("✅ Fixed indentation and removed SQLite code!")


if __name__ == '__main__':
    main()