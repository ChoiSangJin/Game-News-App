"""Validate configured release secrets without exposing their values."""
import os
import subprocess
from pathlib import Path


def invoke(args):
    return subprocess.run(['keytool', *args], stdout=subprocess.PIPE, stderr=subprocess.STDOUT).returncode == 0


def fail(code):
    print('::error::' + code)
    raise SystemExit(1)


if __name__ == '__main__':
    source = 'android/app/release.jks'
    common = ['-keystore', source, '-storepass:env', 'ANDROID_KEYSTORE_PASSWORD']
    if not invoke(['-list', *common]):
        fail('SIGNING_KEYSTORE_INVALID: ANDROID_KEYSTORE_BASE64 파일 또는 ANDROID_KEYSTORE_PASSWORD를 확인하세요.')
    if not invoke(['-list', *common, '-alias', os.environ['ANDROID_KEY_ALIAS']]):
        fail('SIGNING_ALIAS_INVALID: ANDROID_KEY_ALIAS가 키스토어에 없습니다.')
    dest = Path('android/app/signing-preflight.p12')
    try:
        ok = invoke(['-importkeystore', '-noprompt', '-srckeystore', source,
                     '-srcstorepass:env', 'ANDROID_KEYSTORE_PASSWORD', '-srcalias', os.environ['ANDROID_KEY_ALIAS'],
                     '-srckeypass:env', 'ANDROID_KEY_PASSWORD', '-destkeystore', str(dest), '-deststoretype', 'PKCS12',
                     '-deststorepass:env', 'ANDROID_KEYSTORE_PASSWORD'])
        if not ok:
            fail('SIGNING_PRIVATE_KEY_INVALID: ANDROID_KEY_PASSWORD 또는 개인 키 항목을 확인하세요.')
    finally:
        dest.unlink(missing_ok=True)
    print('Release keystore, alias and private key validated (values hidden).')
