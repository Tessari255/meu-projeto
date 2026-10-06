"""Registra início, métricas e fim da carga. A percepção no dashboard é anotada separadamente."""
import json
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import urlopen


def now():
    return datetime.now(timezone.utc).isoformat()


def cpu():
    query = 'max(rate(container_cpu_usage_seconds_total{name="estresse"}[1m]))'
    with urlopen('http://localhost:9090/api/v1/query?' + urlencode({'query': query}), timeout=3) as r:
        result = json.load(r)['data']['result']
    return float(result[0]['value'][1]) if result else None


if __name__ == '__main__':
    path = Path.home() / 'devops-evidencias' / 'incidente.json'
    t0 = time.monotonic()
    data = {'command_started_at': now(), 'threshold_cores': 0.5, 'samples': []}
    process = subprocess.Popen(['docker', 'run', '--rm', '--init', '--name', 'estresse',
                                '--network', 'monitoring-net', 'busybox',
                                'timeout', '60', 'md5sum', '/dev/zero'])
    print('INCIDENTE_INICIO', data['command_started_at'], flush=True)
    try:
        while process.poll() is None:
            if time.monotonic() - t0 >= 60:
                data['external_stop_at'] = now()
                break
            value = cpu()
            sample = {'at': now(), 'elapsed_seconds': round(time.monotonic() - t0, 3), 'cpu_cores': value}
            data['samples'].append(sample)
            if value is not None and value > 0.5 and 'first_above_threshold' not in data:
                data['first_above_threshold'] = sample
                print('METRICA_ACIMA_DO_LIMIAR', json.dumps(sample), flush=True)
            path.write_text(json.dumps(data, indent=2), encoding='utf-8')
            time.sleep(1)
    finally:
        if process.poll() is None:
            subprocess.run(['docker', 'stop', '--time', '3', 'estresse'], check=True, stdout=subprocess.DEVNULL)
            process.wait(timeout=10)
    data['command_finished_at'] = now()
    data['elapsed_total_seconds'] = round(time.monotonic() - t0, 3)
    data['exit_code'] = process.returncode
    data['peak_cores'] = max((s['cpu_cores'] or 0) for s in data['samples'])
    path.write_text(json.dumps(data, indent=2), encoding='utf-8')
    print('INCIDENTE_FIM', json.dumps({k: data[k] for k in ['command_finished_at', 'elapsed_total_seconds', 'exit_code', 'peak_cores']}), flush=True)
    assert data['peak_cores'] > 0.5, 'A carga não apareceu na métrica; investigar a coleta.'
    assert data['elapsed_total_seconds'] < 75, 'A carga ultrapassou a duração segura do teste.'
