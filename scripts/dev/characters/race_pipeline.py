"""Resume-safe Hyper3D race asset workflow. Never retries a paid submission.

Examples: python race_pipeline.py plan
          python race_pipeline.py generate --model orc_male
          python race_pipeline.py status --model orc_male
          python race_pipeline.py rig --model orc_male
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[3]
MANIFEST = ROOT / 'resources/characters/race_models.json'
STATE = ROOT / 'logs/race_build/jobs.json'
CLI = Path(os.environ.get('APPDATA', '')) / 'npm/node_modules/@hyper3d/cli/dist/index.js'
TRANSPORT = ROOT / 'scripts/dev/characters/curl_fetch.mjs'


def read(path, default):
    return json.loads(path.read_text(encoding='utf-8-sig')) if path.is_file() else default


def save(data):
    STATE.parent.mkdir(parents=True, exist_ok=True)
    temporary = STATE.with_suffix('.tmp')
    temporary.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')
    temporary.replace(STATE)


def call(arguments):
    result = subprocess.run(['node', '--import', TRANSPORT.as_uri(), str(CLI), '--output', 'json', *arguments],
                            capture_output=True, text=True, encoding='utf-8', cwd=ROOT, timeout=110)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or 'Hyper3D operation failed.')
    return json.loads(result.stdout)


def generation_id(result):
    for key in ('generation_id', 'task_uuid', 'task_id', 'uuid'):
        if result.get(key): return result[key]
    raise RuntimeError('No generation ID returned. Inspect the saved response before resubmitting.')


def prompt(model):
    return (f"One original adult {model['gender'].lower()} {model['race']} fantasy MMO base character. "
            "Classic Lineage 2 inspired proportions; match the reference identity and silhouette. "
            "High-fidelity PBR textures, request 4K albedo with fine natural skin detail. "
            "Remove baked lighting/shadows. Continuous connected head, neck, shoulders and body; "
            "no neck seam. Rounded symmetric skull, accurate eyes/lips/jaw/ears from all sides. "
            "Neutral A pose, separated fingers, straight legs, bare feet. Preserve opaque charcoal "
            "undergarments; adult females keep athletic top and modest shorts. Preserve racial "
            "ears/tusks/hair/beard and proportions. No armor, weapons, base or background. "
            "Clean shoulder/elbow/hip/knee/neck deformation topology, no fused limbs or sculpted "
            "lighting artifacts. One fixed healthy build, 20k-200k exported vertices, humanoid rig ready.")



def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['plan', 'generate', 'status', 'result', 'download', 'rig'])
    parser.add_argument('--model')
    parser.add_argument('--stage', choices=['geometry', 'rig'])
    args = parser.parse_args()
    manifest = read(MANIFEST, {})
    models = manifest['models']
    if args.command == 'plan':
        print(json.dumps([dict(id=m['id'], race=m['race'], gender=m['gender'], status=m['status'],
                               reference_exists=(ROOT / m['concept'].removeprefix('res://')).is_file(),
                               prompt=prompt(m)) for m in models], indent=2))
        return
    model = next((m for m in models if m['id'] == args.model), None)
    if not model: parser.error('--model must name an entry from plan')
    jobs = read(STATE, {})
    job = jobs.setdefault(model['id'], {})
    if args.command in ['generate', 'rig']:
        stage = 'geometry' if args.command == 'generate' else 'rig'
        if stage in job:
            raise RuntimeError(f'{stage} already submitted or uncertain; inspect jobs.json instead of creating a duplicate.')
        reference = ROOT / model['concept'].removeprefix('res://')
        if not reference.is_file(): raise RuntimeError('Reference image is missing.')
        if stage == 'geometry':
            quality = manifest['generation']
            arguments = ['generate', '--image', str(reference), '--prompt', prompt(model),
                         '--tier', quality['tier'], '--mesh-mode', quality['mesh_mode'],
                         '--quality', str(quality['quality']), '--texture-delight', '--format', 'glb']
        else:
            if 'geometry' not in job or not job['geometry'].get('id'):
                raise RuntimeError('Generate and inspect geometry before rigging.')
            arguments = ['rigging', job['geometry']['id'], '--bone-template', 'human', '--skinning-method', 'core', '--format', 'glb']
        job[stage] = dict(state='submission_started', prompt=prompt(model) if stage == 'geometry' else None)
        save(jobs)
        try:
            result = call(arguments)
            job[stage].update(id=generation_id(result), state='submitted', response=result)
        except Exception:
            job[stage]['state'] = 'uncertain_do_not_resubmit'
            save(jobs)
            raise
        save(jobs)
        print(json.dumps(job[stage], indent=2))
    else:
        stage_name = args.stage or ('rig' if 'rig' in job else 'geometry')
        stage = job.get(stage_name, {})
        if not stage.get('id'): raise RuntimeError('No confirmed generation ID; inspect jobs.json.')
        result = call(['result' if args.command == 'download' else args.command, stage['id']])
        stage['result' if args.command == 'download' else args.command] = result
        if args.command == 'download':
            candidates = [item for item in result.get('files', []) if item.get('name', '').endswith('.glb') and 'pbr' in item.get('name', '').lower()]
            if not candidates: raise RuntimeError('No PBR GLB in provider result; inspect result metadata.')
            selected = candidates[0]
            url = urllib.parse.urlparse(selected['url'])
            if url.scheme != 'https' or not (url.hostname == 'hyper3d.com' or url.hostname.endswith('.hyper3d.com')):
                raise RuntimeError('Unexpected model download host')
            directory = ROOT / 'assets/models/characters/races' / model['id']
            directory.mkdir(parents=True, exist_ok=True)
            output = directory / ('source_pbr.glb' if stage_name == 'geometry' else 'provider_rig.glb')
            with urllib.request.urlopen(selected['url'], timeout=90) as response:
                blob = response.read()
            if blob[:4] != b'glTF': raise RuntimeError('Downloaded file is not a GLB')
            output.write_bytes(blob)
            stage['download'] = str(output.relative_to(ROOT))
            save(jobs)
            print(json.dumps(dict(model=model['id'], stage=stage_name, path=stage['download'], bytes=len(blob)), indent=2))
            return
        save(jobs)
        if args.command == 'result':
            print(json.dumps(dict(files=[{key: value for key, value in item.items() if key != 'url'} for item in result.get('files', [])]), indent=2))
        else: print(json.dumps(result, indent=2))


if __name__ == '__main__':
    try: main()
    except Exception as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
