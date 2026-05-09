# Skill: Regras de Deploy e Git

## ⛔ NUNCA FAZER por conta própria (sem o usuário mandar explicitamente)

### Deploy
- **NUNCA** executar `cdk deploy`, `cdk destroy` por iniciativa própria
- **NUNCA** executar `terraform apply`, `terraform destroy` por iniciativa própria
- **NUNCA** executar `aws` CLI que crie, modifique ou delete recursos (S3, EC2, Lambda, IAM, RDS, etc.) por iniciativa própria
- **NUNCA** executar `serverless deploy`, `sam deploy` por iniciativa própria
- **NUNCA** executar `docker push` para registries remotos por iniciativa própria
- **NUNCA** executar `kubectl apply` em clusters remotos por iniciativa própria

### Git Push
- **NUNCA** executar `git push` por iniciativa própria (nenhuma variação: `--force`, `--tags`, nada)

## ✅ QUANDO O USUÁRIO MANDAR EXPLICITAMENTE

Se o usuário disser **"faça o push"**, **"faça o deploy"**, **"faça commit, push e deploy"** — execute sem pedir confirmação extra.

Exemplos de comandos explícitos que autorizam a ação:
- "Faça o push" → executa `git push`
- "Faça o deploy" → executa `cdk deploy`
- "Faça commit, push e deploy" → executa os três em sequência

## ✅ O QUE DEVE FAZER SEM PRECISAR DE AUTORIZAÇÃO

### Git — Operações locais sempre permitidas
```bash
git init
git add .
git commit -m "mensagem"
git branch <nome>
git checkout <branch>
git merge <branch>
git log
git status
git diff
git diff --staged
git diff HEAD~1
git log --oneline -5
```

### Deploy — Sempre mostrar diff antes
- Criar arquivos de configuração (Dockerfile, CDK stacks, terraform files) → OK
- Rodar `docker build` localmente → OK
- Gerar artefatos de build (`pnpm build`, `npm run build`) → OK
- Rodar `cdk diff` / `terraform plan` → OK (apenas leitura)

## ✅ OBRIGATÓRIO: Mostrar diff antes de deploy

### Git diff
```bash
git diff
git diff --staged
git log --oneline -5
```

### AWS diff
```bash
cdk diff <StackName>   # mostra o que seria criado/alterado/deletado na AWS
terraform plan         # mostra plano de execução
```

### Fluxo obrigatório quando há infra AWS
1. Fazer as alterações no código
2. Rodar `cdk diff` ou `terraform plan` e mostrar ao usuário
3. Aguardar o usuário mandar executar o deploy
