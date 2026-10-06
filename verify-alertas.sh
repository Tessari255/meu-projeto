#!/usr/bin/env bash
set -euo pipefail
# Uma verificação executável do contact point, incluindo rejeição de JSON inválido.
docker exec -i alertas-local python - <<'PY'
import json
from urllib.error import HTTPError
from urllib.request import Request, urlopen

url='http://localhost:8080/'
with urlopen(Request(url, data=json.dumps({'status':'test','alerts':[]}).encode(),
                     headers={'Content-Type':'application/json'}), timeout=5) as r:
    assert r.status == 200 and r.read() == b'ok'
try:
    urlopen(Request(url, data=b'nao-json'), timeout=5)
except HTTPError as e:
    assert e.code == 400
else:
    raise AssertionError('JSON inválido deveria ser rejeitado')
print('Contact point: JSON válido aceito; JSON inválido rejeitado.')
PY
