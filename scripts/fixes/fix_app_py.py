#!/usr/bin/env python3
import os
from pathlib import Path

# Get the backend/app.py path relative to this script
script_dir = Path(__file__).parent
root_dir = script_dir.parent.parent
file_path = root_dir / 'backend' / 'app.py'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the truncated line
old_text = '"created_at": row[7].isoforma'
new_text = '''"created_at": row[7].isoformat() if hasattr(row[7], 'isoformat') else str(row[7]),
                    "updated_at": row[8].isoformat() if hasattr(row[8], 'isoformat') else str(row[8])
                }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))'''

if old_text in content:
    content = content.replace(old_text, new_text)
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print('File fixed successfully')
else:
    print('Pattern not found')
    print(f'File size: {len(content)}')
    print(f'Last 200 chars: {content[-200:]}')