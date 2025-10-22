#!/usr/bin/env python3
"""Remove all SQLite code from app.py, keeping only PostgreSQL"""

import re

def cleanup_app_py():
    with open('backend/app.py', 'r') as f:
        content = f.read()
    
    # Pattern to match and remove the if/else blocks for BACKEND_TYPE
    # This is complex, so we'll do it in multiple passes
    
    # Pass 1: Remove conditional blocks - PostgreSQL first, then else
    patterns = [
        # Multi-line if BACKEND_TYPE blocks
        (r'if BACKEND_TYPE == [\'"]postgresql[\'"]:\s*\n((?:.*?\n)*?)(else:.*?(?=\n(?:@app\.|def |if [A-Z_]|# |async def )))', 
         lambda m: m.group(1)),
    ]
    
    # This is getting complex. Let's do a simpler approach - read and parse manually
    lines = content.split('\n')
    output = []
    i = 0
    skip_mode = False
    indent_level = 0
    
    while i < len(lines):
        line = lines[i]
        
        # Check if this is a conditional block
        if 'if BACKEND_TYPE ==' in line and "'postgresql'" in line:
            # Found PostgreSQL branch - keep indented content
            indent = len(line) - len(line.lstrip())
            i += 1
            # Collect the PostgreSQL code block
            pg_lines = []
            while i < len(lines):
                next_line = lines[i]
                if next_line.strip() == '':
                    pg_lines.append(next_line)
                    i += 1
                    continue
                
                next_indent = len(next_line) - len(next_line.lstrip())
                
                if next_indent > indent and not next_line.strip().startswith('else:'):
                    # Part of the PostgreSQL block
                    pg_lines.append(next_line)
                    i += 1
                elif next_line.strip().startswith('else:'):
                    # Found the else block - skip it
                    i += 1
                    else_indent = len(next_line) - len(next_line.lstrip())
                    while i < len(lines):
                        else_line = lines[i]
                        if else_line.strip() == '':
                            i += 1
                            continue
                        else_line_indent = len(else_line) - len(else_line.lstrip())
                        if else_line_indent > else_indent:
                            i += 1
                        else:
                            break
                    break
                else:
                    break
            
            # Add the PostgreSQL lines, dedented
            for pg_line in pg_lines:
                if pg_line.strip():
                    dedented = pg_line[4:] if pg_line.startswith('    ') else pg_line
                    output.append(dedented)
                else:
                    output.append(pg_line)
        else:
            output.append(line)
            i += 1
    
    new_content = '\n'.join(output)
    
    # Additional cleanups
    new_content = new_content.replace('from sqlite3 import', '# sqlite3 removed')
    
    with open('backend/app.py', 'w') as f:
        f.write(new_content)
    
    print("✅ Cleanup complete")

if __name__ == '__main__':
    cleanup_app_py()