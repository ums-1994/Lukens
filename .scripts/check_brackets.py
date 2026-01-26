from pathlib import Path
p=Path('frontend_flutter/lib/pages/creator/proposal_wizard.dart')
s=p.read_text(encoding='utf-8')
lines=s.splitlines()
ops={'(':0,')':0,'[':0,']':0,'{':0,'}':0}
for i,l in enumerate(lines[:1950],start=1):
    for ch in l:
        if ch in ops:
            ops[ch]+=1
    if i in (1900,1910,1920,1930,1940,1950):
        print(f'Line {i}: counts { {k:ops[k] for k in ops} }')

print('\nFinal counts up to line 1950:')
print(ops)
