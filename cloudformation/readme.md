rodar:

```
aws cloudformation create-stack `
  --stack-name infra-pilates-data-lake `
  --template-body file://cloudformation/data-lake.yml `
  --capabilities CAPABILITY_AUTO_EXPAND
```

para criar
