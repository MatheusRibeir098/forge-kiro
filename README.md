<div align="center">

# 🔥 Forge Kiro

**Orquestração multiagente nativa para Kiro CLI**

[![kiro-cli](https://img.shields.io/badge/kiro--cli_2.16+-required-7c3aed?style=flat-square)](https://kiro.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

*Descreva o que precisa → o Forge Master planeja um DAG, delega a subagentes especializados em paralelo, testa, revisa e entrega validado.*

</div>

---

## O que é

O Forge é um sistema de **custom agents** para Kiro CLI que automatiza criação, manutenção e auditoria de projetos de software.

Você fala apenas com o **Forge Master**. Ele entende o objetivo, escolhe workers, monta pipelines com dependências, executa review loops e agrega resultados — sem tmux, sem monitor pane, sem coordenação manual.

```
Você
  → forge-master (entende, planeja DAG, aprova, agrega)
       → forge-scout      (investigação read-only)
       → forge-spec       (requisitos e design)
       → forge-dev        (implementação geral)
       → forge-ui         (frontend visual)
       → forge-test       (validação e QA)
       → forge-review     (auditoria read-only)
       → forge-issue      (GitHub issues aprovadas)
       → forge-epic-planner / forge-epic-decomposer
       → forge-pentest    (segurança web)
       → quicksight-builder / quicksight-migrator
```

## Economia de tokens

O Forge foi projetado desde a base para **maximizar eficácia com mínimo de tokens**:

| Técnica | Impacto |
|---|---|
| Progressive disclosure (skill://) | Skills carregam só metadata no boot |
| Herança desativada | Workers não herdam steering/skills do workspace |
| Contextos isolados | Reads/logs ficam no worker; só status volta ao Master |
| Model routing | Usuário escolhe modelo por sessão (Qwen 0.05x → Opus 2.0x) |
| Tools mínimas | Nenhum agente usa `*`; zero MCP onde CLI resolve |
| Output contracts | Workers retornam apenas dados estruturados |
| Leitura seletiva | Proibido reler inalterado; proibido lockfiles/builds |
| CLI > MCP | `gh`, `git`, `aws` são determinísticos e não gastam turno LLM |
| Review loops limitados | Máximo 2 iterações antes de reportar blocker |

**Economia medida: 50-70% de tokens por sessão típica; 70-95% em créditos com modelo econômico.**

## Requisitos

- [Kiro CLI](https://kiro.dev) 2.16+
- Conta Kiro (Free ou Pro)
- `gh` CLI (para operações GitHub)
- `git`

## Instalação

```bash
# Clone o repo
git clone https://github.com/MatheusRibeir098/forge-kiro.git ~/forge

# Entre no diretório
cd ~/forge

# (Opcional) Crie seu skill de credenciais local
mkdir -p .kiro/skills/credenciais-ambiente
# Edite .kiro/skills/credenciais-ambiente/SKILL.md com seus perfis AWS/GitHub

# Inicie
kiro-cli chat --agent forge-master
```

## Uso

```bash
cd ~/forge
kiro-cli chat --agent forge-master
```

O Master vai:
1. Perguntar qual modelo usar nos subagentes (econômico → qualidade)
2. Entender seu objetivo
3. Montar o pipeline mínimo necessário
4. Executar e validar
5. Entregar com evidência

### Opções de modelo

| Modelo | Multiplicador | Quando usar |
|---|---|---|
| `qwen3-coder-next` | 0.05x | Máxima economia; tasks simples |
| `claude-haiku-4.5` | baixo | Planejamento e testes |
| `claude-sonnet-4.6` | 1.0x | Implementação equilibrada |
| `claude-opus-4.6+` | 2.0x+ | Qualidade máxima |
| `auto` | variável | Kiro decide por task |

## Estrutura

```
.kiro/
  agents/
    forge-master.json          # Orquestrador (model: auto)
    forge-{scout,spec,dev,test,review,ui,issue}.json
    forge-epic-{planner,decomposer}.json
    forge-pentest.json
    quicksight-{builder,migrator}.json
    prompts/*.md               # Prompts densos dos workers
  skills/
    forge-orchestration/       # Protocolo de DAG e review loops
    token-discipline/          # Regras de economia para workers
    tester-rules/              # QA visual (sob demanda)
    safe-operations/           # Operações destrutivas
    no-deploy-no-push/         # Proteção contra push acidental
    git-profiles/              # Seleção de conta GitHub
    spec-driven/               # Metodologia de specs
    meta-prompt/               # Extração de requisitos
    ...
  settings/
    cli.json                   # disableInheritingDefaultResources: true
```

## Configuração pessoal

Arquivos que você precisa criar localmente (não sobem no repo):

- `.kiro/skills/credenciais-ambiente/SKILL.md` — seus perfis AWS e contas GitHub
- `.kiro/settings/mcp.json` — MCPs locais que quiser (forge-frontend, aws-mcp, etc.)

## Pipeline padrão

```
scout? → spec? → dev|ui → test → review
                          ^            |
                          | NEEDS_CHANGES (max 2)
                          +------------+
```

## Pesquisa de economia de tokens

O arquivo [`guia-economia-tokens-ia-code.md`](./guia-economia-tokens-ia-code.md) contém toda a pesquisa compilada sobre técnicas e ferramentas de economia de tokens aplicáveis a qualquer ferramenta agentic (Claude Code, Kiro CLI, Cursor, Copilot).

## Versão anterior (tmux)

A versão baseada em tmux com `setup-forge.sh` e `fix-loop` foi descontinuada. Para a versão Claude Code com tmux, veja [forge-claude](https://github.com/MatheusRibeir098/forge-claude).

---

## Licença

MIT
