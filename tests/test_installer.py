"""Portable Windows installer checks using synthetic bytes, no game assets."""
from pathlib import Path
import hashlib,json,shutil,subprocess,sys,tempfile,unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from make_delta import create_delta
ROOT=Path(__file__).resolve().parents[1]
SHA=lambda b:hashlib.sha256(b).hexdigest()

@unittest.skipUnless(sys.platform=='win32','Windows PowerShell installer')
class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        root=Path(self.temp.name);self.package=root/'package';self.game=root/'game'
        self.package.mkdir();self.game.mkdir()
        for n in ['Install.ps1','Restore.ps1','PatchCore.ps1']:shutil.copy2(ROOT/n,self.package/n)
        self.base=bytes(range(256))*100
        self.target=b'new bytes'+self.base[100:]+b'end'
        (self.game/'CrackThePack.exe').write_bytes(b'test fixture, never executed')
        (self.game/'data.win').write_bytes(self.base)
        (self.game/'game_stats.json').write_text('{"money":123,"money_max":1000}')
        (self.game/'options.json').write_text('{"lang":"en","volume_music":0.5}')
        asset=b'{"hello":"translation"}'
        patch=create_delta(self.base,self.target)
        (self.package/'data.ctpdelta').write_bytes(patch)
        (self.package/'zh.json').write_bytes(asset)
        manifest={'title':'Installer test','backup_directory':'PatchBackup_test','kind':'localization','set_language':'zh',
                  'targets':[{'base_sha256':SHA(self.base),'target_sha256':SHA(self.target),'patch_file':'data.ctpdelta','patch_sha256':SHA(patch)}],
                  'assets':[{'name':'zh.json','sha256':SHA(asset),'overwrite':True}]}
        (self.package/'manifest.json').write_text(json.dumps(manifest))
    def run_script(self,name,success=True):
        p=subprocess.run(['powershell.exe','-NoProfile','-ExecutionPolicy','Bypass','-File',str(self.package/name),'-GameDir',str(self.game)],capture_output=True)
        if success:self.assertEqual(p.returncode,0,p.stdout.decode(errors='replace')+p.stderr.decode(errors='replace'))
        else:self.assertNotEqual(p.returncode,0)
    def test_roundtrip_and_idempotency(self):
        stats=(self.game/'game_stats.json').read_bytes()
        self.run_script('Install.ps1');self.run_script('Install.ps1')
        self.assertEqual((self.game/'data.win').read_bytes(),self.target)
        self.assertEqual(json.loads((self.game/'options.json').read_text())['lang'],'zh')
        options=json.loads((self.game/'options.json').read_text());options['volume_music']=.25
        (self.game/'options.json').write_text(json.dumps(options))
        self.run_script('Restore.ps1')
        self.assertEqual((self.game/'data.win').read_bytes(),self.base)
        self.assertEqual(json.loads((self.game/'options.json').read_text()),{'lang':'en','volume_music':.25})
        self.assertEqual((self.game/'game_stats.json').read_bytes(),stats)
        self.assertFalse((self.game/'zh.json').exists())
    def test_wrong_version_rejected_without_writes(self):
        (self.game/'data.win').write_bytes(b'wrong version')
        self.run_script('Install.ps1',False)
        self.assertEqual((self.game/'data.win').read_bytes(),b'wrong version')
        self.assertFalse((self.game/'PatchBackup_test').exists())
    def test_corrupt_patch_rejected_without_writes(self):
        (self.package/'data.ctpdelta').write_bytes(b'corrupt')
        self.run_script('Install.ps1',False)
        self.assertEqual((self.game/'data.win').read_bytes(),self.base)
    def test_later_patch_cannot_be_overwritten_by_restore(self):
        self.run_script('Install.ps1')
        (self.game/'data.win').write_bytes(b'a later patch')
        self.run_script('Restore.ps1',False)
        self.assertEqual((self.game/'data.win').read_bytes(),b'a later patch')
    def test_existing_translation_is_restored(self):
        original=b'{"hello":"old translation"}'
        (self.game/'zh.json').write_bytes(original)
        self.run_script('Install.ps1');self.run_script('Restore.ps1')
        self.assertEqual((self.game/'zh.json').read_bytes(),original)
    def test_custom_qol_config_preserved(self):
        manifest=json.loads((self.package/'manifest.json').read_text())
        manifest['set_language']=None
        manifest['assets'][0]['overwrite']=False
        (self.package/'manifest.json').write_text(json.dumps(manifest))
        custom=b'{"animation_speed":5}'
        (self.game/'zh.json').write_bytes(custom)
        self.run_script('Install.ps1')
        self.assertEqual((self.game/'zh.json').read_bytes(),custom)
        self.assertEqual(json.loads((self.game/'options.json').read_text())['lang'],'en')
        self.run_script('Restore.ps1')
        self.assertEqual((self.game/'zh.json').read_bytes(),custom)
    def test_corrupt_backup_cannot_replace_game(self):
        self.run_script('Install.ps1')
        (self.game/'PatchBackup_test'/'data.win').write_bytes(b'corrupt backup')
        self.run_script('Restore.ps1',False)
        self.assertEqual((self.game/'data.win').read_bytes(),self.target)

if __name__=='__main__':unittest.main()
