import importlib.util
import pathlib
import unittest
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('make_appcast', ROOT / 'scripts/make-appcast.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class FeedChecks(unittest.TestCase):
    def setUp(self):
        self.info = {'StageByScreenReleaseVersion': '0.2.0', 'CFBundleVersion': '8', 'LSMinimumSystemVersion': '14.0'}

    def test_stable_feed_preserves_build_order_and_signed_asset(self):
        feed = ET.fromstring(module.make_feed(self.info, 'test-signature', 1234))
        item = feed.find('channel/item')
        self.assertEqual(item.find('{%s}version' % module.NS).text, '8')
        self.assertEqual(item.find('{%s}shortVersionString' % module.NS).text, '0.2.0')
        enclosure = item.find('enclosure')
        self.assertEqual(enclosure.get('url'), 'https://github.com/splwany/StageByScreen/releases/download/v0.2.0/StageByScreen-0.2.0-universal.dmg')
        self.assertEqual(enclosure.get('{%s}edSignature' % module.NS), 'test-signature')
        self.assertEqual(enclosure.get('length'), '1234')

    def test_prerelease_and_path_injection_never_enter_stable_feed(self):
        for value in ['0.2.0-beta.1', '../other', '0.2.0?redirect=bad', 'v0.2.0']:
            with self.subTest(value=value), self.assertRaises(ValueError):
                module.make_feed(dict(self.info, StageByScreenReleaseVersion=value), 'signature', 1)

    def test_invalid_build_number_is_rejected(self):
        for value in ['0', '-1', '8.beta', '']:
            with self.subTest(value=value), self.assertRaises(ValueError):
                module.make_feed(dict(self.info, CFBundleVersion=value), 'signature', 1)

if __name__ == '__main__':
    unittest.main()
