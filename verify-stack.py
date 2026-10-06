import base64
import json
from urllib.parse import urlencode
from urllib.request import Request, urlopen

def get(port, path, auth=False):
    headers = {'Authorization': 'Basic ' + base64.b64encode(b'admin:admin').decode()} if auth else {}
    with urlopen(Request(f'http://localhost:{port}{path}', headers=headers), timeout=10) as response:
        return json.load(response)

targets = get(9090, '/api/v1/targets')['data']['activeTargets']
assert any(t['labels'].get('job') == 'cadvisor' and t['health'] == 'up' for t in targets), targets
print('Prometheus targets:', [(t['labels']['job'], t['health']) for t in targets])
query = 'container_cpu_usage_seconds_total{name=~"meu-container-db|meu-container-web"}'
result = get(9090, '/api/v1/query?' + urlencode({'query': query}))['data']['result']
names = {r['metric']['name'] for r in result}
assert {'meu-container-db', 'meu-container-web'} <= names, names
print('CPU metrics:', sorted(names))
assert get(3000, '/api/health')['database'] == 'ok'
health = get(3000, '/api/datasources/uid/prometheus/health', True)
assert health['status'] == 'OK', health
print('Grafana datasource:', health)
dashboard = get(3000, '/api/dashboards/uid/devops-cpu', True)['dashboard']
print('Dashboard:', dashboard['title'])
rules = get(3000, '/api/v1/provisioning/alert-rules', True)
assert any(r['uid'] == 'devops-cpu-alta' for r in rules)
points = get(3000, '/api/v1/provisioning/contact-points', True)
assert any(p['settings'].get('url') == 'http://alertas-local:8080/' for p in points)
print('Alert rule and contact point:', [(r['uid'], r['title']) for r in rules], [(p['name'], p['type']) for p in points])
print('Stack checks passed')
