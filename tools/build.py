"""Rebuild from user-owned game files; UndertaleModTool CLI is not bundled."""
from pathlib import Path
import argparse,hashlib,json,os,shutil,subprocess,sys
from urllib.request import urlopen
from make_delta import create_delta,apply_delta

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game-dir',required=True,type=Path)
    parser.add_argument('--data-file',type=Path,help='Optional source data.win override; language resources still come from --game-dir')
    parser.add_argument('--utmt',required=True,type=Path)
    parser.add_argument('--font',type=Path)
    args=parser.parse_args()
    repo=Path(__file__).resolve().parents[1]
    manifest=json.loads((repo/'manifest.json').read_text(encoding='utf-8-sig'))
    build=repo/'_local'/'build';build.mkdir(parents=True,exist_ok=True)
    for p in (repo/'src').iterdir():
        if p.is_file():shutil.copy2(p,build/p.name)
    source=(args.data_file or args.game_dir/'data.win').resolve()
    digest=hashlib.sha256(source.read_bytes()).hexdigest()
    if manifest['kind']=='localization' and digest!=manifest.get('build_base_sha256',manifest['targets'][0]['base_sha256']):
        raise SystemExit('Rebuilding localization requires original game data.win; use --data-file to select a clean backup')
    if digest not in {t['base_sha256'] for t in manifest['targets']}:
        raise SystemExit('Source data.win version does not match manifest')
    env=os.environ.copy();env['CTP_BUILD_DIR']=str(build.resolve());env['CTP_GAME_DIR']=str(args.game_dir.resolve())
    cli=str(args.utmt.resolve())
    def run(script,output=None,input_file=source):
        cmd=[cli,'load',str(input_file),'-s',str(build/script)]
        if output:cmd.extend(['-o',str(output),'-f'])
        subprocess.run(cmd,env=env,check=True)
    if manifest['kind']=='localization':
        subprocess.run([sys.executable,str(build/'translate.py')],env=env,check=True)
        run('export_fonts.csx')
        font=args.font
        if font is None:
            font=repo/'_local'/'fonts'/'NotoSansCJKsc-Regular.otf'
            font.parent.mkdir(parents=True,exist_ok=True)
            spec=json.loads((repo/'font_source.json').read_text())
            if not font.exists():
                with urlopen(spec['url'],timeout=60) as response:font.write_bytes(response.read())
            if hashlib.sha256(font.read_bytes()).hexdigest()!=spec['sha256']:
                raise SystemExit('Upstream font checksum changed; download the documented version or use --font')
        env['CTP_FONT_PATH']=str(font.resolve())
        subprocess.run([sys.executable,str(build/'build_fonts.py')],env=env,check=True)
    output=build/'data_patched.win'
    run('patch.csx',output)
    if manifest['kind']=='localization':run('verify.csx',input_file=output)
    base,target=source.read_bytes(),output.read_bytes()
    patch=create_delta(base,target)
    if apply_delta(base,patch)!=target:raise RuntimeError('Delta verification failed')
    (build/'data_generated.ctpdelta').write_bytes(patch)
    (build/'build_result.json').write_text(json.dumps({
        'base_sha256':digest,'target_sha256':hashlib.sha256(target).hexdigest(),
        'patch_sha256':hashlib.sha256(patch).hexdigest(),
    },indent=2),encoding='utf-8')
    print(f'Build complete: {build}')

if __name__=='__main__':main()
