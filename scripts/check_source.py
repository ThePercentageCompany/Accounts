"""Lightweight delimiter check when a Dart SDK is unavailable; NOT a compiler."""
from pathlib import Path
for p in Path('lib').rglob('*.dart'):
    s=p.read_text(); stack=[];i=0
    while i<len(s):
        if s.startswith('//',i):
            j=s.find('\n',i); i=len(s) if j<0 else j; continue
        if s.startswith('/*',i):
            i=s.index('*/',i)+2;continue
        if s[i] in "\"'":
            q=s[i];i+=1
            while i<len(s):
                if s[i]=='\\':i+=2;continue
                if s[i]==q:i+=1;break
                i+=1
            continue
        c=s[i]
        if c in '([{':stack.append((c,i))
        elif c in ')]}':
            if not stack or '([{'.index(stack[-1][0])!=')]}'.index(c):
                raise SystemExit(f'{p}:{s[:i].count(chr(10))+1}: unmatched {c}; stack={stack[-3:]}')
            stack.pop()
        i+=1
    if stack:raise SystemExit(f'{p}: unclosed {stack}')
print('Dart source delimiters checked (not a compile or analyzer run).')
