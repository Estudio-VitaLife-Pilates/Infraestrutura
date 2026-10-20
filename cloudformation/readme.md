Na pasta `Infraestrutura`, rode com o AWS SAM CLI instalado e credenciais AWS
configuradas. O SAM empacota o código local da Lambda em `lambda/` e publica
os artefatos em um bucket S3. Os nomes dos buckets da stack incluem o ID da
conta AWS para serem únicos globalmente:

```powershell
sam deploy --guided --resolve-s3 --template-file cloudformation/data-lake.yml --stack-name infra-pilates-data-lake --region us-east-1
```

No GitHub Actions, essa etapa é executada automaticamente antes do `terraform
init`. O workflow usa `--no-confirm-changeset` e
`--no-fail-on-empty-changeset` para permitir deploys não interativos e
idempotentes.