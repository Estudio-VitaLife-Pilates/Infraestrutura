# Infraestrutura e coleta de logs

## O que o Terraform prepara

`terraform apply` cria um volume EBS persistente para o MySQL, publica os
scripts de bootstrap no prefixo privado
`bootstrap/infra-pilates/` do bucket bronze e associa comandos do Systems
Manager às EC2 existentes:

- A EC2 `InstanciaApp-01` recebe Docker, Fluent Bit, o Compose do backend e o
  comando `/usr/local/bin/deploy-backend <tag>`.
- A EC2 `InstanciaBD-01` recebe Docker, Fluent Bit e um Compose do MySQL.
  Um volume EBS separado é montado em `/mnt/pilates-mysql`. O timer do systemd
  tenta iniciar o MySQL a cada minuto até o container subir.
- As duas EC2 web recebem um perfil IAM para publicar logs e iniciam Fluent Bit
  junto do Nginx. A alteração do `user_data` recria somente essas instâncias;
  o plano mantém as EC2 do backend e do banco.
- Todos os agentes enviam logs JSON Lines ao prefixo `s3://infra-pilates-bronze/logs/`.
  Os objetos são organizados por tipo de origem, host e data.

Os agentes coletam o journal do systemd; os arquivos tradicionais
`/var/log/auth.log`, `syslog`, `dpkg.log`, `kern.log` e `ufw.log`; os arquivos de
acesso e erro do Nginx; e os arquivos JSON de `stdout`/`stderr` de todos os
containers Docker nos hosts. Cada arquivo tem seu próprio banco de offsets do
Fluent Bit, e a coleta começa a partir de novas linhas após a instalação, sem
reenviar o histórico existente. Os arquivos tradicionais podem não existir até
que o serviço correspondente gere uma entrada. O Docker rotaciona seus arquivos
de log para limitar o uso de disco local.

`rsyslog` é instalado e habilitado para gerar os arquivos de sistema
tradicionais. O pacote UFW também é instalado e seu nível de log é configurado
como `low`, mas o firewall **não é habilitado** nem recebe regras; portanto,
`ufw.log` só terá eventos se o UFW for ativado e houver tráfego registrado.
O Fluent Bit roda com acesso aos grupos `adm` e `systemd-journal` para ler os
logs protegidos.

Parte dos eventos de `auth.log`, `syslog` e `kern.log` também aparece no
journal, então esses eventos podem ser coletados duas vezes, uma sob `systemd.*`
e outra sob `file.*`. Os prefixos e o campo `source_file` permitem distingui-los
e deduplicá-los em consultas. Os logs de autenticação e firewall podem conter
informações sensíveis.

Para atualizar instâncias existentes, execute `terraform apply` para publicar
os novos scripts no S3. Depois, execute novamente as associações de bootstrap
`<project>-app-bootstrap` e `<project>-database-bootstrap` no Systems Manager
(ou rode os respectivos scripts baixados do S3 nas instâncias). Alterações no
`user_data` substituem as instâncias web; revise o plano antes do apply e
aguarde a recriação/substituição delas.

O Terraform **não cria nem gerencia o repositório ECR**. A URL esperada é
`<ID_DA_CONTA>.dkr.ecr.us-east-1.amazonaws.com/backend/dev`; crie esse
repositório separadamente no ECR antes de publicar a primeira imagem. A saída
`ecr_backend_repository_url` apenas informa essa URL.

Os arquivos `.sh` em `cloud-init/` são scripts shell processados pelo
`templatefile()` do Terraform para preencher valores de infraestrutura. A
extensão `.tftpl` não é exigida: era apenas uma convenção para identificar
templates. O `web.sh` é passado às EC2 web como `user_data` e executado pelo
cloud-init do Ubuntu na inicialização. Já a configuração inicial das EC2 de
aplicação e banco é executada pelo Systems Manager (SSM), que baixa os scripts
publicados no S3. O arquivo `fluent-bit.yaml` usa a sintaxe YAML do Fluent Bit
(suportada a partir da versão 3.2); cada host recebe sua configuração
preenchida e a instala em `/etc/fluent-bit/fluent-bit.yaml`.

## Credenciais nos Docker Compose

As credenciais são configuradas diretamente nos arquivos Compose, sem usar o
AWS Secrets Manager. A senha do banco permanece `root`, como no Compose
anterior; mantenha-a igual em `BackEnd/docker-compose.yml`,
`cloud-init/database-compose.yml` e `cloud-init/backend-compose.yml`. O
usuário da aplicação é `pilates_app`, e a senha do root do MySQL também está
definida como `root`. O Compose do backend usa o mesmo valor de JWT que já
estava configurado anteriormente. Se o MySQL já tiver inicializado seu
volume, mudar a senha no Compose não altera a senha gravada no banco: nesse
caso, altere a senha também no MySQL.

> **Atenção:** credenciais em Compose versionado ficam visíveis para quem tiver
> acesso ao repositório, ao histórico Git e aos arquivos de bootstrap no S3.
> Variáveis de ambiente também podem ser vistas por usuários com acesso ao
> Docker. Não reutilize senhas pessoais ou de outros ambientes; rotacione os
> valores se o repositório ou a instância for compartilhado.

O Compose em `BackEnd` sobe somente o backend; o banco não faz parte do projeto
Compose do backend e deve estar disponível separadamente. Configure `DB_HOST`
em `.env` para o host desse MySQL.

Para iniciar o backend local apontando para um MySQL separado:

```powershell
docker compose --env-file .env up --build -d
```

## Publicar e executar a imagem na EC2

Depois de criar o repositório ECR, atualizar as credenciais nos Compose e
aplicar a infraestrutura, faça push na branch `develop`. O workflow existente
compila a imagem, publica no ECR com o SHA do commit como tag e usa o Systems
Manager para executar `deploy-backend` na EC2 da aplicação. O backend conecta
ao IP privado da EC2 do banco.

A primeira publicação só ocorrerá quando o repositório já existir e a pipeline
estiver configurada com credenciais que permitam ECR e Systems Manager.

## Athena e Glue

O Terraform cria o banco Glue `infra_pilates_logs`, o crawler
`infra-pilates-logs` e o workgroup Athena `infra-pilates-logs`. O crawler usa a
role existente `LabRole` e aponta para `s3://infra-pilates-bronze/logs/`; não
cria nem altera roles IAM. O workgroup grava resultados em
`s3://infra-pilates-bronze/athena-results/` com criptografia SSE-S3.

Depois do `terraform apply`, inicie o crawler manualmente pelo console AWS
(Glue → Crawlers → `infra-pilates-logs` → Run crawler). Ele é intencionalmente
sob demanda para evitar cobranças recorrentes; rode-o de novo quando quiser
registrar novos arquivos e partições `dt`. O Fluent Bit publica NDJSON em
prefixos como `logs/container.app/dt=AAAA-MM-DD/` e
`logs/systemd.app/dt=AAAA-MM-DD/`.

No Athena, selecione o workgroup `infra-pilates-logs` e o database
`infra_pilates_logs`. Liste as tabelas e consulte uma delas:

```sql
SHOW TABLES IN infra_pilates_logs;

SELECT *
FROM infra_pilates_logs.pilates_container_app
WHERE dt = '2026-10-12'
LIMIT 20;
```

O crawler pode normalizar nomes de diretórios ao criar tabelas; use o nome
exato retornado por `SHOW TABLES`. Filtre pela partição `dt` para reduzir o
volume lido pelo Athena. O usuário do console ainda precisa ter permissões para
executar consultas no Athena e ler/gravar objetos nos prefixos `logs/` e
`athena-results/` do bucket bronze.

Os logs da aplicação e do sistema podem conter dados sensíveis; evite imprimir
senhas, tokens ou dados pessoais nos logs.

## Persistência e destruição

O volume EBS do MySQL tem `prevent_destroy` para evitar perda acidental dos
dados. Por isso, um `terraform destroy` completo para nesse recurso até que a
proteção seja removida intencionalmente. Preserve ou faça backup do volume antes
de qualquer destruição.
