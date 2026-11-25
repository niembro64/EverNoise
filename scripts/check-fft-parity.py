import array, math, json
from pathlib import Path
read = lambda name: array.array('f', Path('artifacts', name+'.f32').read_bytes())
a, b = read('spectrum-apple'), read('spectrum-portable')
delta = [abs(x-y) for x,y in zip(a,b) if math.isfinite(x) and x > -100]
result = {'portable_vs_accelerate_max_db_difference_above_minus_100_db':max(delta), 'rows_compared':len(delta), 'host_pcm_identical':read('pcm-apple')==read('pcm-portable')}
print(json.dumps(result)); Path('artifacts/portable-parity.json').write_text(json.dumps(result,indent=2)+'\n')
assert max(delta) < .005
assert result['host_pcm_identical']
