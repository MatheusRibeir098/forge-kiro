---
name: git-profiles
description: Escolha da conta GitHub correta (matheuspribeiro-dati de trabalho vs MatheusRibeir098 pessoal) antes de operacoes gh. Use antes de gh issue create, gh pr create, gh repo create, ou clone de repo privado.
---

# Skill: Perfis Git/GitHub

## Perfis disponíveis

### pessoal
- **GitHub user:** MatheusRibeir098
- **Email:** matheusprfh098@gmail.com
- **Nome:** MatheusRibeir098
- **gh account:** MatheusRibeir098

### dati (empresa)
- **GitHub user:** matheuspribeiro-dati
- **Email:** matheus.pribeiro@dati.com.br
- **Nome:** Matheus Ribeiro
- **gh account:** matheuspribeiro-dati

---

## Regra OBRIGATÓRIA

Antes de qualquer operação git ou GitHub, **perguntar ao usuário qual perfil usar** se ele não especificou:

```
Qual conta usar?
1. pessoal (MatheusRibeir098)
2. dati (matheuspribeiro-dati)
```

Se o usuário já informou na mensagem (ex: "cria na dati", "commita como pessoal"), use diretamente sem perguntar.

---

## Como aplicar o perfil

### Criar repositório com gh CLI
```bash
# Trocar para a conta correta antes de criar
gh auth switch --user matheuspribeiro-dati   # dati
gh auth switch --user MatheusRibeir098       # pessoal

gh repo create <nome> --public/--private
```

### Configurar commits (por repositório)
```bash
git config user.email "matheus.pribeiro@dati.com.br"   # dati
git config user.name "Matheus Ribeiro"

# ou pessoal:
git config user.email "matheusprfh098@gmail.com"
git config user.name "MatheusRibeir098"
```

### Fluxo completo (criar repo + configurar commits)
1. `gh auth switch --user <conta>`
2. `gh repo create ...`
3. `git config user.email <email-do-perfil>`
4. `git config user.name <nome-do-perfil>`
