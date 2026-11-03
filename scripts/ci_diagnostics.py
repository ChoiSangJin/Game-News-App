"""Expose non-secret analysis/test/build diagnostics as GitHub annotations."""
import sys
from pathlib import Path

if __name__ == '__main__':
    text = Path(sys.argv[1]).read_text(errors='replace')
    lines = text.splitlines()[-85:]
    # Compiler output and fixture test failures only; never use for signing logs.
    for start in range(0, len(lines), 25):
        chunk = '\n'.join(lines[start:start + 25])
        escaped = chunk.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
        print(f'::error title=CI diagnostic::{escaped}')
