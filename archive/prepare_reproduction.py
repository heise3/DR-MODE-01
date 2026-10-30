"""Create a disposable, independent working copy without changing archived outputs."""
from pathlib import Path
import shutil, argparse, json, time
ROOT=Path(__file__).resolve().parents[1]
ap=argparse.ArgumentParser();ap.add_argument('destination');args=ap.parse_args();out=Path(args.destination).expanduser().resolve()
assert not out.exists(), 'Destination must not exist'
assert ROOT not in out.parents, 'Use a destination outside the archive'
shutil.copytree(ROOT,out,ignore=shutil.ignore_patterns('.git','__pycache__'))
for x in ['work','outputs/DR-MODE-01/A_access/data','outputs/DR-MODE-01/A_access/codebooks','outputs/DR-MODE-01/A_access/codebook_text','outputs/S1_writing/provenance','outputs/S1_writing/software/Rlib','DR-MODE-01/X1/data']:(out/x).mkdir(parents=True,exist_ok=True)
reps=out/'outputs/S2_uncertainty/replicates'
if reps.exists():shutil.rmtree(reps)
reps.mkdir()
now=time.time();p=out/'outputs/S2_uncertainty/provenance/runtime_control.json'
old=json.loads(p.read_text());new={**old,'start_unix':now,'deadline_unix':now+36*3600,'reproduction_only':True,'original_runtime_record':'archive source unchanged'};p.write_text(json.dumps(new,indent=2)+'\n')
(out/'REPRODUCTION_WORKING_COPY.json').write_text(json.dumps({'created_unix':now,'not_a_new_scientific_release':True,'full_MCMC_run':'NOT_RUN','original_archived_outputs_must_not_be_interpreted_as_newly_fitted':True},indent=2)+'\n')
print(out)
