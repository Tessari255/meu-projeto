# Meu projeto DevOps

Laboratórios executados em uma VM **Linux Mint 22.3** com 8 GB de RAM, 4 CPUs e disco de 60 GB. Projeto: <https://github.com/Tessari255/meu-projeto>.

## Ferramentas

- Docker 29.1.3, Terraform 1.16.5 e provider `kreuzwerker/docker` 3.9.0, registrado em `.terraform.lock.hcl`.
- cAdvisor 0.55.1 e Grafana 13.2.3 verificados na execução local. As imagens `latest` podem mudar em instalações futuras.
- VS Code com as extensões HashiCorp Terraform e Docker.
- GitHub Actions para init, fmt, validate, plan, apply e verificações dentro do runner.

## Abrir no Mint

```bash
cd ~/meu-projeto
code .
source ~/.devops-env
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
docker ps
```

`~/.devops-env` contém a senha local aleatória do PostgreSQL, criada durante a preparação. Ela fica fora do repositório. Para uma instalação nova, informe sua própria senha com `TF_VAR_postgres_password` antes do plan/apply. State, tfvars e arquivos de ambiente são ignorados pelo Git.

## Endereços dentro da VM

| Serviço | Endereço |
| --- | --- |
| Nginx | <http://localhost:8080> |
| cAdvisor | <http://localhost:8081/containers/> |
| Prometheus | <http://localhost:9090/targets> |
| Grafana | <http://localhost:3000> |

Grafana: `admin` / `admin` para o laboratório local. O datasource usa `http://prometheus:9090` dentro da rede Docker. O dashboard **DevOps - CPU dos containers** e o alerta **CPU acima de 0.5 núcleo** são provisionados pelos arquivos em `grafana/`.

O contact point **Webhook local do laboratório** aponta para `http://alertas-local:8080/`. As notificações ficam no container local:

```bash
docker logs --timestamps alertas-local
bash verify-alertas.sh
```

## Banco e conteúdo do site

O volume `meu-projeto-db-data` preserva os dados quando somente o container do PostgreSQL é removido. `terraform destroy` também remove o volume declarado; não o use para testar a persistência.

```bash
docker exec meu-container-db psql -U postgres -c 'SELECT id,texto FROM mensagens ORDER BY id;'
```

A página foi preenchida com uma consulta ao banco e também contém o texto `Atualizado via pipeline`. O bind mount permite atualizar o HTML sem recriar a infraestrutura. O Nginx lê o diretório em modo somente leitura.

## Pipeline e exercícios

Push em `main`: init, fmt, validate, plan, apply, smoke test do HTML e demonstração do banco efêmero. Pull Request: somente validação e plan; apply e os testes pós-deploy são pulados. O [PR 1](https://github.com/Tessari255/meu-projeto/pull/1) registra o teste da porta 8081.

O endereço do smoke test vem de `terraform output -raw web_url`, acompanhando a porta declarada. A senha do banco do runner é gerada por execução e mascarada nos logs. A tabela `execucoes` registra o ID daquela execução e demonstra que a seguinte começa sem os dados anteriores.

Os containers criados pela pipeline vivem no runner temporário. A pipeline não atualiza diretamente a VM; nela, a atualização do código usa `git pull` seguido de `terraform apply`. A stack visitada no navegador é a da VM.

As falhas intencionais de formatação e de conflito de porta permanecem no histórico como evidências dos exercícios. Consulte a execução mais recente para conferir o estado final.

## Simular o incidente

```bash
docker run --rm --init --name estresse --network monitoring-net busybox timeout 60 md5sum /dev/zero
```

Na imagem BusyBox usada nesta VM, o comando acima continuou após 60 segundos, mesmo com `--init`. Para repetir com duração controlada e registrar as métricas, use:

```bash
python3 incident.py
python3 verify-stack.py
```

O script executa o comando do exercício e encerra o container externamente ao atingir 60 segundos, inclusive limpando a carga se a coleta falhar. A repetição verificada durou 60,8 segundos e chegou a 0,98 núcleo. Os registros ficam em `~/devops-evidencias/`. Para interromper uma carga iniciada manualmente: `docker stop --time 3 estresse`.

A consulta do painel é `rate(container_cpu_usage_seconds_total{name=~"meu-container-web|estresse"}[1m])`. A unidade é núcleo de CPU: `1` significa um núcleo ocupado. A regra usa o maior valor entre esses containers, limiar de `0.5` núcleo e avaliação a cada 10 segundos. O eixo do painel vai de 0 a 1,2 para esta simulação de um único núcleo; amplie-o para cargas que possam ocupar mais núcleos.

## Material de revisão

O pacote de entrega reúne logs reais, screenshots, postmortem e respostas comentadas. Revise as respostas e registre seu próprio entendimento antes da entrega individual, conforme as instruções gerais da disciplina.
