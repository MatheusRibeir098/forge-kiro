---
name: safe-operations
description: Regras de operacao segura antes de comandos destrutivos ou irreversiveis. Use antes de rm, drop, delete, truncate, force push, reset --hard, alteracao de IAM/permissoes, ou qualquer acao em ambiente de producao.
---

# Skill: Operações Seguras — Proteção de Processos em Andamento

## Regra OBRIGATÓRIA (todos os agents)

ANTES de qualquer ação que possa derrubar ou afetar servidores/processos rodando:

1. **Verifique se há processos ativos:**
```bash
# Verificar se backend está rodando
tmux list-sessions 2>/dev/null | grep servers && echo "⚠️ SERVIDORES ATIVOS"
lsof -i :3001 2>/dev/null && echo "⚠️ Backend rodando na porta 3001"
lsof -i :5173 2>/dev/null && echo "⚠️ Frontend rodando na porta 5173"
```

2. **Se houver processos ativos, PERGUNTE ao usuário antes de continuar:**
```
⚠️ Detectei processos em andamento:
- Backend rodando na porta 3001
- Frontend rodando na porta 5173

Posso continuar? Isso pode derrubar os processos acima.
Aguardando confirmação...
```

3. **Só prossiga após confirmação explícita do usuário.**

## Ações que EXIGEM essa verificação

- Reiniciar servidores (`tmux kill-session -t servers`)
- Modificar arquivos do backend que causam hot-reload (`src/**/*.ts`)
- Rodar `pnpm install` (pode travar o processo)
- Alterar `package.json` ou `tsconfig.json`
- Qualquer `kill`, `pkill`, `killall`
- Rodar migrations ou scripts que alteram o banco de dados
- `tmux kill-session` de qualquer session que não seja a sua

## Ações que NÃO precisam de verificação

- Ler arquivos (fs_read, cat, grep)
- Modificar arquivos de frontend (hot-reload não derruba backend)
- Criar arquivos novos
- Rodar testes em session separada

---

## Regra OBRIGATÓRIA: Pull antes de analisar branch

**SEMPRE** fazer `git pull` de uma branch antes de analisá-la ou compará-la. Nunca trabalhar com código local desatualizado.

```bash
# ANTES de qualquer análise ou diff
git checkout <branch> && git pull origin <branch>
```

Isso evita comparações incorretas e conclusões erradas baseadas em código que já foi atualizado no remote.
