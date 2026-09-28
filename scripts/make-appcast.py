#!/usr/bin/env python3
"""Create a signed feed for the final DMG; run after notarization if used."""
import pathlib
import plistlib
import re
import subprocess
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parent.parent
ACCOUNT = 'org.stagebyscreen.StageByScreen'
NS = 'http://www.andymatuschak.org/xml-namespaces/sparkle'
ET.register_namespace('sparkle', NS)

def make_feed(info, signature, size):
    version = info['StageByScreenReleaseVersion']
    if not re.fullmatch(r'\d+\.\d+\.\d+', version):
        raise ValueError('The stable update feed requires a stable version')
    if not re.fullmatch(r'[1-9]\d*', info['CFBundleVersion']):
        raise ValueError('Build number must be a positive integer')
    root = ET.Element('rss', version='2.0')
    channel = ET.SubElement(root, 'channel')
    ET.SubElement(channel, 'title').text = '台前随屏更新'
    item = ET.SubElement(channel, 'item')
    ET.SubElement(item, 'title').text = '台前随屏 ' + version
    ET.SubElement(item, '{%s}version' % NS).text = info['CFBundleVersion']
    ET.SubElement(item, '{%s}shortVersionString' % NS).text = version
    ET.SubElement(item, '{%s}minimumSystemVersion' % NS).text = info['LSMinimumSystemVersion']
    ET.SubElement(item, 'description').text = '此版本的更新说明见 GitHub Release。安装会退出并重新启动台前随屏。'
    ET.SubElement(item, 'link').text = 'https://github.com/splwany/StageByScreen/releases/tag/v' + version
    ET.SubElement(item, 'enclosure', {
        'url': 'https://github.com/splwany/StageByScreen/releases/download/v' + version + '/StageByScreen-' + version + '-universal.dmg',
        'length': str(size), 'type': 'application/octet-stream', '{%s}edSignature' % NS: signature,
    })
    return ET.tostring(root, encoding='utf-8', xml_declaration=True)

def main():
    info = plistlib.loads((ROOT / '.build/台前随屏.app/Contents/Info.plist').read_bytes())
    source = plistlib.loads((ROOT / 'Resources/Info.plist').read_bytes())
    assert info == source, 'Rebuild the app before preparing its feed'
    tools = ROOT / '.build/Sparkle/bin'
    public = subprocess.check_output([str(tools / 'generate_keys'), '--account', ACCOUNT, '-p'], text=True).strip()
    assert public == info['SUPublicEDKey'], 'Signing key differs from the embedded public key'
    dmg = ROOT / ('dist/StageByScreen-' + info['StageByScreenReleaseVersion'] + '-universal.dmg')
    sign = [str(tools / 'sign_update'), '--account', ACCOUNT]
    signature = subprocess.check_output(sign + ['-p', str(dmg)], text=True).strip()
    feed = ROOT / 'dist/appcast.xml'
    feed.write_bytes(make_feed(info, signature, dmg.stat().st_size))
    subprocess.run(sign + [str(feed)], check=True)
    subprocess.run(sign + ['--verify', str(feed)], check=True)
    subprocess.run(sign + ['--verify', str(dmg), signature], check=True)
    print('Signed update archive and feed:', feed.name)

if __name__ == '__main__':
    main()
