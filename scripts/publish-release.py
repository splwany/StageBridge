#!/usr/bin/env python3
"""Publish one stable release with signed update assets. Never replace a release."""
import base64
import hashlib
import json
import os
import pathlib
import plistlib
import re
import subprocess
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
BASE = 'https://api.github.com/repos/splwany/StageByScreen'

def main():
    os.chdir(ROOT)
    assert not subprocess.check_output(['git', 'status', '--porcelain']).strip(), 'Commit all changes first'
    info = plistlib.loads((ROOT / 'Resources/Info.plist').read_bytes())
    version = info['StageByScreenReleaseVersion']
    assert re.fullmatch(r'\d+\.\d+\.\d+', version), 'Stable releases only'
    sha = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
    token = os.environ.get('GITHUB_TOKEN')
    if not token:
        result = subprocess.run(['git', 'credential', 'fill'], input='protocol=https\nhost=github.com\n\n', text=True, capture_output=True, check=True)
        token = dict(line.split('=', 1) for line in result.stdout.splitlines() if '=' in line)['password']
    def api(path, method='GET', payload=None, raw=None):
        headers = {'Authorization': 'Bearer ' + token, 'Accept': 'application/vnd.github+json', 'User-Agent': 'StageByScreen-release'}
        data = None
        if raw is not None:
            data = raw; headers['Content-Type'] = 'application/octet-stream'
        elif payload is not None:
            data = json.dumps(payload).encode(); headers['Content-Type'] = 'application/json'
        url = path if path.startswith('https://') else BASE + path
        with urllib.request.urlopen(urllib.request.Request(url, data=data, headers=headers, method=method), timeout=120) as response:
            return json.load(response)
    assert api('/commits/main')['sha'] == sha, 'Push this commit to main first'
    runs = api('/actions/runs?head_sha=' + sha + '&event=push&per_page=100')['workflow_runs']
    assert any(r['name'] == 'macOS checks' and r['conclusion'] == 'success' for r in runs), 'CI must pass for this commit'
    tag = 'v' + version
    releases = api('/releases?per_page=100')
    assert not any(r['tag_name'] == tag for r in releases), 'Release already exists; do not overwrite it'
    stable = [r for r in releases if not r['draft'] and not r['prerelease'] and re.fullmatch(r'v\d+\.\d+\.\d+', r['tag_name'])]
    if stable:
        previous = max(stable, key=lambda r: tuple(map(int, r['tag_name'][1:].split('.'))))
        assert tuple(map(int, version.split('.'))) > tuple(map(int, previous['tag_name'][1:].split('.'))), 'Version must increase'
        content = api('/contents/Resources/Info.plist?ref=' + previous['tag_name'])
        previous_info = plistlib.loads(base64.b64decode(content['content']))
        assert int(info['CFBundleVersion']) > int(previous_info['CFBundleVersion']), 'Build number must increase' 
    subprocess.run(['python3', 'scripts/make-appcast.py'], check=True)
    dmg = ROOT / ('dist/StageByScreen-' + version + '-universal.dmg')
    checksum = ROOT / 'dist/SHA256SUMS.txt'
    checksum.write_text(hashlib.sha256(dmg.read_bytes()).hexdigest() + '  ' + dmg.name + '\n')
    notes = (ROOT / 'CHANGELOG.md').read_text().split('## ' + version + '\n', 1)[1].split('\n## ', 1)[0].strip()
    notes += '\n\n下载 DMG 并拖入 Applications。附签名更新订阅及 SHA-256。当前未经 Apple 公证，签名与兼容性限制见 README。'
    release = api('/releases', 'POST', {'tag_name': tag, 'target_commitish': sha, 'name': '台前随屏 ' + version, 'body': notes, 'draft': True, 'prerelease': False})
    for file in [dmg, checksum, ROOT / 'dist/appcast.xml']:
        asset = api(release['upload_url'].split('{')[0] + '?name=' + file.name, 'POST', raw=file.read_bytes())
        assert asset['size'] == file.stat().st_size and asset['state'] == 'uploaded'
    published = api('/releases/' + str(release['id']), 'PATCH', {'draft': False, 'make_latest': 'true'})
    print(published['html_url'])

if __name__ == '__main__':
    main()
