"""Report only fixed categories, task names and compiler diagnostics, never signing values."""
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text(errors='replace')
lower = text.lower()
if any(s in lower for s in ['password was incorrect', 'password is incorrect', 'cannot recover key', 'failed to read key', 'keystore was tampered', 'keystore password', 'tag number over 30']):
    print('::error::RELEASE_SIGNING_FAILED: 키스토어·비밀번호·별칭 조합을 확인하세요. 값은 로그에 출력하지 않습니다.')
for task in re.findall(r"Execution failed for task '(:[A-Za-z0-9_:]+)'", text):
    print('::error::Failed Gradle task: ' + task)
lines = [line for line in text.splitlines() if re.match(r'^\s*(?:e: file:|Missing class |ERROR: Missing class|.*\.java:\d+: error:)', line)]
for line in lines[-20:]:
    print('::error::' + line.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A'))
print('::error::Release build failed; inspect the authenticated GitHub Actions log for full details.')
