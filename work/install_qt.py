import os, sys, pathlib, hashlib
root = pathlib.Path(__file__).resolve().parent
os.environ['APPDATA'] = str(root)
os.environ['TEMP'] = os.environ['TMP'] = str(root/'temp')
sys.path.insert(0, str(root/'build-tools'))
import aqt.installer as ai
import requests, py7zr
def sequential(archives, base_dir, sevenzip, keep, archive_dest, dry_run=False):
    for arc in archives:
        url = 'https://ftp.fau.de/qtproject/' + arc.archive_path.lstrip('/')
        print('Downloading', arc.name, url, flush=True)
        path = root/'temp'/arc.archive
        if not path.exists():
            with requests.get(url, stream=True, timeout=120) as r:
                r.raise_for_status()
                with path.open('wb') as f:
                    for chunk in r.iter_content(1024*1024): f.write(chunk)
        from aqt.helper import get_hash, Settings
        expected = get_hash(arc.archive_path, Settings.hash_algorithm, (30,120))
        actual = hashlib.new(Settings.hash_algorithm, path.read_bytes()).digest()
        if isinstance(expected,str): actual = actual.hex()
        if actual != expected: raise RuntimeError('Archive checksum mismatch')
        print('Extracting', arc.name, flush=True)
        with py7zr.SevenZipFile(path) as z: z.extractall(path=pathlib.Path(base_dir)/arc.archive_install_path)
        path.unlink()
ai.run_installer = sequential
sys.exit(ai.Cli().run())
