<div align="center">

# 🔥 Forge

**Fábrica de projetos com agentes AI orquestrados via kiro-cli**

[![kiro-cli](https://img.shields.io/badge/kiro--cli-required-7c3aed?style=flat-square)](https://kiro.dev)
[![tmux](https://img.shields.io/badge/tmux-required-06b6d4?style=flat-square)](https://github.com/tmux/tmux)
[![Shell](https://img.shields.io/badge/Shell-bash-4B5563?style=flat-square&logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)

*Descreva uma ideia → o Forge gera a spec e constrói o projeto com 3 agentes trabalhando em paralelo*

</div>

---

## O que é

O Forge é um sistema de orquestração de agentes AI que automatiza a criação e manutenção de projetos de software. Ele tem dois modos:

- **forge-loop** — cria projetos do zero a partir de uma ideia
- **fix-loop** — implementa features ou corrige bugs em projetos existentes

Cada modo sobe 3 agentes especializados em uma sessão tmux:

| Agente | Papel |
|---|---|
| 👁 **monitor** | Lê a spec, coordena o trabalho, fala com o usuário |
| 👷 **dev** | Escreve o código |
| 🧪 **tester** | Roda testes e valida o resultado |

---

## Pré-requisitos

- [`kiro-cli`](https://kiro.dev) instalado e autenticado
- `tmux` instalado
- `bash`

---

## Instalação

```bash
git clone https://github.com/MatheusRibeir098/forge.git ~/forge
```

Pronto. Não há dependências adicionais.

---

## Como usar

### Ponto de entrada — Forge Master

```bash
cd ~/forge
kiro-cli chat --trust-all-tools --agent forge-master
```

O Forge Master pergunta o que você quer fazer:

```
🔥 Forge — Fábrica de Projetos

O que vamos fazer hoje?

1. 🆕 Criar um projeto do zero
2. 🔧 Fix/implementação em projeto existente
```

---

### Fluxo 1 — Criar projeto do zero

1. Escolha a opção `1` e descreva sua ideia
2. O Forge Master faz perguntas para refinar os requisitos (stack, funcionalidades, design)
3. Gera um `prompt.md` — a spec completa do projeto
4. Você aprova a spec
5. O Forge cria a pasta `~/forge/projects/<nome>/`, instala as dependências e sobe o **forge-loop**

```bash
# Para acessar a sessão criada:
tmux attach -t forge-<nome-do-projeto>
```

O monitor já leu o `prompt.md` e está construindo o projeto. Você pode acompanhar ou falar com ele.

---

### Fluxo 2 — Fix/implementação em projeto existente

1. Escolha a opção `2` e informe o caminho do projeto
2. O Forge sobe o **fix-loop** apontando para o projeto

```bash
# Para acessar:
tmux attach -t fix-<nome-do-projeto>
```

Fale com o monitor sobre o bug ou feature que precisa.

---

### Subir manualmente (sem o Forge Master)

```bash
# forge-loop (criar do zero)
bash ~/forge/templates/forge-loop/setup-forge.sh ~/forge/projects/meu-app

# fix-loop (projeto existente)
bash ~/forge/templates/fix-loop/setup-fix.sh ~/caminho/do/projeto
```

---

## Estrutura

```
forge/
├── .kiro/
│   └── agents/
│       └── forge-master.json      ← hub de entrada
├── templates/
│   ├── forge-loop/                ← agentes de criação
│   │   ├── agents/                ← configs dos agentes
│   │   ├── prompts/               ← instruções de cada agente
│   │   ├── skills/                ← conhecimento compartilhado
│   │   └── setup-forge.sh         ← sobe a sessão tmux
│   └── fix-loop/                  ← agentes de fix
│       ├── agents/
│       ├── prompts/
│       ├── skills/
│       └── setup-fix.sh
└── projects/                      ← projetos criados ficam aqui
    └── meu-app/
        ├── prompt.md              ← spec gerada pelo Forge Master
        └── ...
```

---

## Comandos úteis

```bash
# Ver sessões ativas
tmux list-sessions

# Acessar uma sessão
tmux attach -t forge-meu-app
tmux attach -t fix-meu-app

# Derrubar uma sessão
tmux kill-session -t forge-meu-app

# Ver o que cada agente está fazendo
tmux capture-pane -t forge-meu-app:0.0 -p | tail -5   # tester
tmux capture-pane -t forge-meu-app:0.1 -p | tail -5   # monitor
tmux capture-pane -t forge-meu-app:0.2 -p | tail -5   # dev
```

---

## Layout da sessão tmux

```
┌─────────────────────────────────────┐
│  🧪 tester  (barra fina no topo)    │
├──────────────────┬──────────────────┤
│                  │                  │
│   👁 monitor     │   👷 dev         │
│   (fale aqui)    │   (escreve kod)  │
│                  │                  │
└──────────────────┴──────────────────┘
```

O foco abre no **monitor** — é com ele que você conversa.

---

## Skills

Os agentes têm acesso a um conjunto de skills (conhecimento especializado) copiadas automaticamente para cada projeto:

- `no-deploy-no-push` — regras de segurança para git e deploy
- `clean-code` — padrões de código
- `safe-operations` — proteção de processos em andamento
- `ui-design`, `react-patterns`, `tailwind`, etc. — skills de frontend

---

## Projetos criados com o Forge

| Projeto | Descrição |
|---|---|
| [quadsolver](https://github.com/MatheusRibeir098/quadsolver) | Calculadora de função quadrática com gráfico interativo |

---

## Licença

MIT © [MatheusRibeir098](https://github.com/MatheusRibeir098)
