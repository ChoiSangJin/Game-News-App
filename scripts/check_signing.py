"""Validate configured release secrets without exposing their values."""
import os
import subprocess
import zipfile
from pathlib import Path


def invoke(args):
    return subprocess.run(['keytool', *args], stdout=subprocess.PIPE, stderr=subprocess.STDOUT).returncode == 0


def fail(code):
    print('::error::' + code)
    raise SystemExit(1)


if __name__ == '__main__':
    source = 'android/app/release.jks'
    # Accept the private backup ZIP as well as the raw keystore. Only read the key file;
    # never extract password JSON or archive paths onto the runner filesystem.
    if zipfile.is_zipfile(source):
        with zipfile.ZipFile(source) as archive:
            keys = [i for i in archive.infolist() if not i.is_dir() and i.filename.lower().endswith(('.jks', '.keystore', '.p12')) and i.file_size <= 1024 * 1024]
            if len(keys) != 1:
                fail('SIGNING_ARCHIVE_INVALID: 백업 ZIP에는 키스토어 파일이 하나만 있어야 합니다.')
            content = archive.read(keys[0])
        Path(source).write_bytes(content)
        print('Keystore loaded from backup ZIP; other backup files were ignored.')
    common = ['-keystore' , source, '-storepass:env', 'ANDROID_KEYSTORE_PASSWORD']
    check = subprocess.run(['keytool', '-list', *common], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if check.returncode:
        detail = check.stdout.decode(errors='replace').lower()
        if any(word in detail for word in ['password was incorrect', 'password is incorrect', 'keystore was tampered', 'password verification failed', 'integrity check failed']):
            fail('SIGNING_STORE_PASSWORD_MISMATCH: ANDROID_KEYSTORE_PASSWORD가 등록된 키스토어 비밀번호와 일치하지 않습니다.')
        if any(word in detail for word in ['invalid keystore format', 'unrecognized keystore format', 'toderinputstream', 'tag number over']):
            fail('SIGNING_KEYSTORE_FORMAT_INVALID: ANDROID_KEYSTORE_BASE64에 release.jks 원본 또는 백업 ZIP을 인코딩해 등록하세요.')
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
