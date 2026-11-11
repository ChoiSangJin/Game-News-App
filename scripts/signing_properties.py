"""Write ignored Android signing configuration from CI secrets without logging values."""
import os
from pathlib import Path


def escape(value):
    return value.replace('\\', '\\\\').replace('\n', '\\n').replace('\r', '\\r').replace('=', '\\=').replace(':', '\\:').replace(' ', '\\ ')


if __name__ == '__main__':
    values = {
        'storeFile': str(Path('android/app/release.jks').resolve()),
        'storePassword': os.environ['ANDROID_KEYSTORE_PASSWORD'],
        'keyAlias': os.environ['ANDROID_KEY_ALIAS'],
        'keyPassword': os.environ['ANDROID_KEY_PASSWORD'],
    }
    target = Path('android/key.properties')
    target.write_text(''.join(f'{key}={escape(value)}\n' for key, value in values.items()))
    target.chmod(0o600)
