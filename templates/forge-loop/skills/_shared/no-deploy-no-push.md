# Skill: Regras de Deploy e Git — PROIBIÇÕES ABSOLUTAS

## ⛔ NUNCA FAZER (sem exceção, mesmo com confirmação do usuário)

### Deploy
- **NUNCA** executar `cdk deploy`, `cdk destroy`
- **NUNCA** executar `terraform apply`, `terraform destroy`
- **NUNCA** executar `aws` CLI que crie, modifique ou delete recursos (S3, EC2, Lambda, IAM, RDS, etc.)
- **NUNCA** executar `serverless deploy`, `sam deploy`
- **NUNCA** executar `docker push` para registries remotos
- **NUNCA** executar `kubectl apply` em clusters remotos
- **NUNCA** fazer deploy em qualquer provedor cloud (AWS, GCP, Azure, Vercel, Netlify, etc.)

### Git Push
- **NUNCA** executar `git push` (nenhuma variação: `--force`, `--tags`, nada)
- **NUNCA** executar `git push origin`, `git push --all`, etc.

## ✅ O QUE DEVE FAZER NO LUGAR

### Git — Apenas local
```bash
# Permitido
git init
git add .
git commit -m "mensagem"
git branch <nome>
git checkout <branch>
git merge <branch>
git log
git status

# OBRIGATÓRIO antes de declarar tarefa concluída
git diff                    # mostra mudanças não commitadas
git diff --staged           # mostra mudanças staged
git diff HEAD~1             # mostra último commit
git log --oneline -5        # mostra últimos commits
```

### Deploy — Apenas preparar e mostrar diff
- Criar arquivos de configuração (Dockerfile, CDK stacks, terraform files) → OK
- Rodar `docker build` localmente → OK
- Gerar artefatos de build (`pnpm build`, `npm run build`) → OK

## ✅ OBRIGATÓRIO: Mostrar diff antes de finalizar

### Git diff
```bash
git diff
git diff --staged
git log --oneline -5
```

### AWS diff (PRINCIPAL — sempre rodar quando houver infra)
```bash
# CDK — mostra o que seria criado/alterado/deletado na AWS
cdk diff

# CDK com stack específica
cdk diff <StackName>

# CDK synth — gera o CloudFormation template pra revisão
cdk synth

# Terraform — mostra plano de execução
terraform plan
```

### O que cada diff mostra
- `cdk diff` → lista recursos que seriam Added/Changed/Removed na AWS
- `cdk synth` → gera o template CloudFormation completo (JSON/YAML)
- `terraform plan` → mostra plano detalhado com + (criar), ~ (alterar), - (deletar)

### Fluxo obrigatório quando há infra AWS
1. Fazer as alterações no código CDK/Terraform
2. Rodar `cdk diff` ou `terraform plan`
3. Mostrar o resultado ao usuário
4. **PARAR** — o usuário decide se faz deploy manualmente

Isso permite ao usuário revisar TODAS as mudanças (código + infra) antes de decidir fazer push/deploy manualmente.
