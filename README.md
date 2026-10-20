# Infraestrutura e coleta de logs

## O que o Terraform prepara

`terraform apply` cria um volume EBS persistente para o MySQL, publica os
scripts de bootstrap no prefixo privado
`bootstrap/infra-pilates/` do bucket bronze e associa comandos do Systems
Manager às EC2 existentes:

- A EC2 `InstanciaApp-01` recebe Docker, Fluent Bit, o Compose do backend e o
  comando `/usr/local/bin/deploy-backend <tag> [database-ip]`.
- A EC2 `InstanciaBD-01` recebe Docker, Fluent Bit e um Compose do MySQL.
  Um volume EBS separado é montado em `/mnt/pilates-mysql`. O timer do systemd
  tenta iniciar o MySQL a cada minuto até o container subir.
- As duas EC2 web recebem um perfil IAM para publicar logs e iniciam Fluent Bit
  junto do Nginx. A alteração do `user_data` recria somente essas instâncias;
  o plano mantém as EC2 do backend e do banco.
- Todos os agentes enviam logs JSON Lines ao prefixo
  `s3://infra-pilates-bronze-${AWS_ACCOUNT_ID}/logs/`.
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
O Fluent Bit roda como `root` para ler os arquivos protegidos, os logs dos
containers Docker e o journal sem depender de uma conta de serviço que pode não
ser criada pelo pacote da distribuição.

Parte dos eventos de `auth.log`, `syslog` e `kern.log` também aparece no
journal, então esses eventos podem ser coletados duas vezes, uma sob `systemd.*`
e outra sob `file.*`. Os prefixos e o campo `source_file` permitem distingui-los
e deduplicá-los em consultas. Os logs de autenticação e firewall podem conter
informações sensíveis.

Para atualizar instâncias existentes, execute `terraform apply` para publicar
os novos scripts no S3. Uma mudança no bootstrap da aplicação atualiza sua
associação SSM e reaplica o script na EC2 do backend. Para reaplicar o bootstrap
do banco, execute a associação `<project>-database-bootstrap` no Systems
Manager (ou rode o script baixado do S3 na instância). Alterações no
`user_data` substituem as instâncias web; revise o plano antes do apply e
aguarde a recriação/substituição delas.

O Terraform cria os repositórios ECR `backend/dev` e `frontend/dev`; suas URLs
estão disponíveis nas saídas `ecr_backend_repository_url` e
`ecr_frontend_repository_url`. Ambos usam tags mutáveis e varredura de imagem
ao publicar.

Se algum desses repositórios já existir na conta AWS, importe-o para o state
antes de aplicar, em vez de tentar criá-lo novamente. Por exemplo:

```powershell
terraform import aws_ecr_repository.backend backend/dev
terraform import aws_ecr_repository.frontend frontend/dev
```

Os arquivos `.sh` em `cloud-init/` são scripts shell processados pelo
`templatefile()` do Terraform para preencher valores de infraestrutura. A
extensão `.tftpl` não é exigida: era apenas uma convenção para identificar
templates. O `web.sh` é passado às EC2 web como `user_data` e executado pelo
cloud-init do Ubuntu na inicialização. Já a configuração inicial das EC2 de
aplicação e banco é executada pelo Systems Manager (SSM), que baixa os scripts
publicados no S3. O arquivo `fluent-bit.yaml` usa a sintaxe YAML do Fluent Bit
(suportada a partir da versão 3.2); cada host recebe sua configuração
preenchida e a instala em `/etc/fluent-bit/fluent-bit.yaml`.

## Pipeline de infraestrutura

O workflow `.github/workflows/terraform-apply.yml` roda em push para `main` ou
por `workflow_dispatch`. Primeiro, o job `Deploy CloudFormation data lake`
instala o AWS SAM CLI e cria ou atualiza a stack `infra-pilates-data-lake`;
`--resolve-s3` cria e usa um bucket para os artefatos da Lambda. Só depois o
workflow executa `fmt`, `init`, `validate` e `plan`, e aplica automaticamente
exatamente o plano salvo, sem aprovação manual.

Configure os secrets `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` e
`AWS_SECRET_SESSION_TOKEN` no environment `development`. A credencial precisa
criar/atualizar a stack CloudFormation, os buckets definidos no template, a
Lambda e sua Function URL, além de criar e usar o bucket de artefatos do SAM.
Também precisa ler/gravar o state e lock em
`s3://infra-pilates-bronze-${AWS_ACCOUNT_ID}/terraform/infraestrutura/` e ter
permissões para os recursos AWS gerenciados pelo Terraform. Cada push em `main`
pode alterar recursos reais, incluindo substituir ou remover recursos conforme
o plano; revise o resumo do job `Terraform plan` e proteja a branch `main` com
revisão de pull request antes do merge.

O template CloudFormation nomeia os buckets com o ID da conta AWS, evitando
colisão com nomes globais usados por outras contas. O Terraform usa o mesmo
nome para logs, bootstrap e backend remoto. A role `LabRole` ainda precisa
existir na conta. Não rode Terraform local em paralelo com esse pipeline.

O backend Terraform é configurado parcialmente em `backend.tf`; o workflow
descobre o ID da conta e fornece o nome do bucket durante `terraform init`.
Para inicializar localmente, use credenciais da mesma conta:

```powershell
terraform init "-backend-config=bucket=infra-pilates-bronze-$(aws sts get-caller-identity --query Account --output text)"
```

Se houver state local nessa cópia, inclua `-migrate-state` e confirme a
migração somente depois de verificar o destino. Restrinja o acesso ao prefixo
do state, pois o state do Terraform pode conter dados sensíveis.

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

Depois de aplicar a infraestrutura e atualizar as credenciais nos Compose,
faça push na branch `develop` do `BackEnd`. O workflow compila a imagem,
publica no ECR com o SHA do commit como tag e usa o Systems Manager para
executar `deploy-backend` na EC2 da aplicação. A cada deploy, o workflow
consulta o IP privado atual da EC2 do banco e o passa ao script; se o endereço
configurado no container mudar, o Compose recria o backend usando o novo destino.
O script também compara o `DB_URL` real do container para manter o deploy
idempotente quando imagem e banco já estiverem corretos.

A pipeline precisa de credenciais que permitam publicar no ECR e usar Systems
Manager.

## Publicar e executar o frontend

O workflow em `FrontEnd/.github/workflows/aws-deploy-dev.yml` é acionado em push
para `develop`: instala dependências, gera o build Vite, publica a imagem no
ECR `frontend/dev` com o SHA do commit e atualiza as duas EC2 web via SSM. O
workflow envia o script de deploy junto ao comando SSM; esse script instala
Docker, Docker Compose, Nginx, AWS CLI e curl caso estejam ausentes, configura
o proxy e executa o container. Portanto, o arquivo
`/usr/local/bin/deploy-frontend` não precisa existir previamente nas instâncias.
O Terraform ainda precisa ter criado o repositório ECR antes do push.
Configure no repositório GitHub `FrontEnd` os secrets
`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` e `AWS_SECRET_SESSION_TOKEN`, além
do environment `development` usado pelo workflow. As credenciais precisam
permitir push ao ECR, localizar as EC2 e executar/comprovar comandos SSM. O
instance profile associado às EC2 web também precisa permitir autenticação e
pull de imagens desse repositório (`ecr:GetAuthorizationToken`,
`ecr:BatchGetImage`, `ecr:GetDownloadUrlForLayer` e `ecr:BatchCheckLayerAvailability`);
o Terraform não altera a role/profile IAM existente.

O Nginx da EC2 encaminha `/` para o container frontend local e `/api/` para a
EC2 do backend; o código frontend usa a URL relativa `/api`, mantendo o tráfego
da API no mesmo host do ALB. Se `user_data` mudou, aplique o Terraform e aguarde
a substituição das instâncias web antes de fazer push para `develop`.

## Athena e Glue

O Terraform cria o banco Glue `infra_pilates_logs`, o crawler
`infra-pilates-logs` e o workgroup Athena `infra-pilates-logs`. O crawler usa a
role existente `LabRole` e aponta para
`s3://infra-pilates-bronze-${AWS_ACCOUNT_ID}/logs/`; não cria nem altera roles
IAM. O workgroup grava resultados em
`s3://infra-pilates-bronze-${AWS_ACCOUNT_ID}/athena-results/` com criptografia
SSE-S3.

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
