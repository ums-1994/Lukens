#!/usr/bin/env python3
"""
Final SQLite removal script - removes all conditional branches from app.py
This handles the remaining ~50 conditional blocks that weren't cleaned up yet.
"""

import re

def remove_sqlite_branches(content):
    """
    Remove all if BACKEND_TYPE == 'postgresql': blocks and keep only the PostgreSQL code.
    Also removes the else: SQLite branches.
    """
    
    # Pattern to match if BACKEND_TYPE == 'postgresql': blocks with their else counterparts
    # This is complex because we need to handle nested indentation properly
    
    lines = content.split('\n')
    result = []
    i = 0
    
    while i < len(lines):
        line = lines[i]
        
        # Check if this line is the start of a PostgreSQL conditional
        if "if BACKEND_TYPE == 'postgresql':" in line:
            # Get the indentation level of the if statement
            indent = len(line) - len(line.lstrip())
            pg_indent = indent + 4  # PostgreSQL block indentation
            
            # Collect the PostgreSQL code block
            i += 1
            pg_lines = []
            
            while i < len(lines):
                current_line = lines[i]
                
                # Check for else: at the same indentation level
                if current_line.strip() and not current_line.startswith(' ' * (pg_indent + 1)) and not current_line.startswith(' ' * pg_indent):
                    # We've exited the if block
                    if current_line.startswith(' ' * indent + 'else:'):
                        # Skip the else block
                        i += 1
                        while i < len(lines):
                            next_line = lines[i]
                            next_indent = len(next_line) - len(next_line.lstrip())
                            
                            # Check if we're back to the original indentation level (or less)
                            if next_line.strip() and next_indent <= indent:
                                # Don't increment i, we'll process this line normally in the next iteration
                                break
                            i += 1
                        break
                    else:
                        # No else block, we're done with this if
                        break
                
                # This line is part of the PostgreSQL block
                if current_line.startswith(' ' * (pg_indent + 1)):
                    # Remove the PostgreSQL block indentation to dedent
                    dedented = current_line[4:]  # Remove 4 spaces
                    pg_lines.append(dedented)
                elif current_line.strip() == '':
                    # Empty line
                    pg_lines.append('')
                else:
                    # Line is at or above our expected indentation - we've exited the block
                    break
                
                i += 1
            
            # Add the dedented PostgreSQL lines to result
            result.extend(pg_lines)
            continue
        
        result.append(line)
        i += 1
    
    return '\n'.join(result)


def main():
    with open(r'c:\Users\Unathi Sibanda\Documents\Lukens-Unathi-Test\backend\app.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Count occurrences before
    before_count = content.count("if BACKEND_TYPE == 'postgresql':")
    print(f"Found {before_count} conditional blocks to clean")
    
    # Remove SQLite branches
    cleaned = remove_sqlite_branches(content)
    
    # Count occurrences after
    after_count = cleaned.count("if BACKEND_TYPE == 'postgresql':")
    print(f"After cleanup: {after_count} conditional blocks remaining")
    
    # Save the cleaned file
    with open(r'c:\Users\Unathi Sibanda\Documents\Lukens-Unathi-Test\backend\app.py', 'w', encoding='utf-8') as f:
        f.write(cleaned)
    
    print("✅ SQLite branches removed successfully!")
    print(f"Removed {before_count - after_count} conditional blocks")


if __name__ == '__main__':
    main()