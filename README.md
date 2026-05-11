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

O Forge é um sistema de orquestração de agentes AI que automatiza a criação e manutenção de projetos de software.

**Você fala apenas com o Kiro.** O Kiro entende o que você quer, monta a spec, instala dependências, passa as instruções para os agentes e monitora o progresso — você nunca precisa abrir o tmux ou falar diretamente com os agentes.

```
Você
  ↓ linguagem natural
Kiro (orquestrador)
  ↓ instrução estruturada
Monitor
  ↓ coordena
Dev ←→ Tester
```

### Divisão de responsabilidades

| Quem | Faz |
|---|---|
| **Kiro** | Entende requisitos, monta prompt, instala deps, pesquisa, monitora agentes |
| **Monitor** | Coordena dev e tester, mantém o foco no objetivo |
| **Dev** | Escreve todo o código |
| **Tester** | Roda testes E2E, tira prints, analisa visualmente cada tela |

> O Kiro **nunca** escreve código de produto. Desenvolvimento é sempre responsabilidade dos agentes.

---

## Pré-requisitos

- [`kiro-cli`](https://kiro.dev) instalado e autenticado
- `tmux` instalado
- `bash`

---

## Instalação

```bash
git clone https://github.com/MatheusRibeir098/forge-framework.git ~/forge
```

---

## Como usar

### Ponto de entrada

```bash
cd ~/forge
kiro-cli chat --trust-all-tools --agent forge-master
```

O Forge Master pergunta o que você quer fazer:

```
🔥 Forge — Fábrica de Projetos

1. 🆕 Criar um projeto do zero
2. 🔧 Fix/implementação em projeto existente
```

---

### Fluxo 1 — Criar projeto do zero

1. Descreva sua ideia em linguagem natural
2. O Kiro faz perguntas para refinar requisitos (stack, funcionalidades, design)
3. Gera e apresenta o `prompt.md` para aprovação
4. Após aprovação: cria a pasta, instala dependências e sobe o **forge-loop**
5. O Kiro monitora o progresso e te avisa quando terminar

```
~/forge/projects/<nome>/
├── prompt.md    ← spec gerada
└── ...          ← código construído pelos agentes
```

---

### Fluxo 2 — Fix/implementação em projeto existente

1. Informe o que precisa ser feito e o projeto
2. O Kiro sobe o **fix-loop** e passa a instrução ao monitor
3. Monitora e reporta quando concluído

---

### Subir manualmente

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
│   ├── agents/
│   │   ├── forge-master.json          ← agente de entrada
│   │   └── prompts/forge-master.md    ← instruções do orquestrador
│   ├── skills/_shared/
│   │   ├── orchestrator.md            ← regras de orquestração
│   │   ├── no-deploy-no-push.md       ← regras de git/deploy
│   │   └── ...
│   └── steering/
│       └── tester-rules.md            ← testes E2E obrigatórios com prints
├── templates/
│   ├── forge-loop/                    ← agentes de criação (setup-forge.sh)
│   └── fix-loop/                      ← agentes de fix (setup-fix.sh)
└── projects/                          ← projetos criados ficam aqui
```

---

## Testes E2E — padrão obrigatório

O tester sempre roda testes E2E com Playwright e **tira prints de todas as telas** antes de aprovar qualquer implementação. Prints são analisados visualmente para detectar:

- Layout quebrado ou desalinhado
- Erros em mobile (375px) e desktop (1280px)
- Estados de erro, loading e vazio
- Contraste e legibilidade

Nenhuma feature é aprovada sem análise visual dos prints.

---

## Layout da sessão tmux

```
┌─────────────────────────────────────┐
│  🧪 tester  (barra fina no topo)    │
├──────────────────┬──────────────────┤
│   👁 monitor     │   👷 dev         │
│                  │                  │
└──────────────────┴──────────────────┘
```

Você não precisa acessar essa sessão — o Kiro monitora por você.

---

## Projetos criados com o Forge

| Projeto | Descrição |
|---|---|
| [quadsolver](https://github.com/MatheusRibeir098/quadsolver) | Calculadora de função quadrática com gráfico interativo |

---

## Licença

MIT © [MatheusRibeir098](https://github.com/MatheusRibeir098)
