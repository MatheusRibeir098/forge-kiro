# 🔥 Forge — Fábrica de Projetos

Sistema de criação e manutenção de projetos com agentes AI orquestrados.

## Como usar

```bash
cd ~/forge
kiro-cli chat --trust-all-tools --agent forge-master
```

O Forge Master vai perguntar o que você quer fazer:

### 🆕 Criar projeto do zero
1. Descreva sua ideia
2. O agente faz perguntas para refinar os requisitos
3. Gera um `prompt.md` estruturado (spec completa)
4. Cria a pasta do projeto em `~/forge/projects/<nome>/`
5. Sobe o **forge-loop** (3 agentes) que lê o prompt e constrói o projeto

### 🔧 Fix/Implementação em projeto existente
1. Informe o caminho do projeto
2. Sobe o **fix-loop** (3 agentes) apontando pro projeto
3. Fale com o monitor sobre o bug/feature

## Arquitetura

### Dois modos de operação

| Modo | Sessão tmux | Agentes | Propósito |
|------|-------------|---------|-----------|
| **forge-loop** | `forge-<nome>` | monitor-forge, dev-forge, tester-forge | Criar do zero |
| **fix-loop** | `fix-<nome>` | monitor-fix, dev-fix, tester-fix | Fix/implementação |

### Estrutura

```
~/forge/
├── .kiro/agents/              ← forge-master (hub)
├── templates/
│   ├── forge-loop/            ← agentes de criação
│   │   ├── agents/
│   │   ├── prompts/
│   │   ├── skills/
│   │   └── setup-forge.sh
│   └── fix-loop/              ← agentes de fix (copiado do multi-agents)
│       ├── agents/
│       ├── prompts/
│       ├── skills/
│       └── setup-fix.sh
└── projects/                  ← projetos criados ficam aqui
    └── meu-app/
        ├── prompt.md          ← spec gerada pelo forge-master
        └── ...                ← código do projeto
```

## Acessar sessões

```bash
# Listar sessões ativas
tmux list-sessions

# Acessar
tmux attach -t forge-<nome>
tmux attach -t fix-<nome>

# Derrubar uma sessão
tmux kill-session -t forge-<nome>
```

## Verificar se agents carregaram

```bash
for i in 0 1 2; do
  echo "=== PANE $i ==="
  tmux capture-pane -t <sessao>:0.$i -p | tail -3
done
```

Deve mostrar `[monitor-forge]`, `[dev-forge]`, `[tester-forge]` (ou os equivalentes fix).
