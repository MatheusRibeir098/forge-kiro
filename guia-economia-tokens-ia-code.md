# Guia de Economia de Tokens para IA de Código

> Pesquisa compilada em Agosto/2026. Aplicável a Claude Code, Kiro CLI, Cursor, Copilot e qualquer ferramenta agentic de código.

---

## Por que tokens são caros em ferramentas agentic?

O mecanismo é simples: ferramentas como Claude Code, Kiro CLI e Cursor **reenviam o histórico completo da conversa + arquivos lidos + output de ferramentas a cada turno**. O consumo cresce quadraticamente com a duração da sessão.

Distribuição típica de tokens por turno:

| Categoria | % do total | O que causa |
|---|:---:|---|
| System prompt + skills + tool manifest | 30-50% | Boot overhead; carrega em todo turno |
| Tool calls (Read, Grep, Bash outputs) | 30-45% | Piora conforme sessão cresce |
| Reasoning (extended thinking) | 10-30% | Pode explodir para 64K tokens em tasks difíceis |
| Output visível do assistente | 1-10% | Prosa + código gerado |

A **auto-compactação** (quando chega em ~93% do contexto) custa 100-200K tokens extras cada vez que dispara, porque relê tudo para resumir.

---

## Técnicas Built-in (Custo Zero, Impacto Imediato)

### 1. Sessões curtas e focadas

**A técnica #1.** Uma task = uma sessão. Pesquisa de Stanford ("Lost in the Middle") mostra que LLMs perdem atenção no meio do contexto a partir de 50% de preenchimento.

| Uso do contexto | Situação | Ação |
|---|---|---|
| < 40% | Tudo funcionando | Continue |
| 40-60% | Começando a acumular ruído | Termine a task atual |
| 60-70% | "Lost in the Middle" ativo | `/compact` manual ou sessão nova |
| > 70% | Degradação ativa | Pare. Sessão nova. |
| Auto-compactação | 98% de perda de informação | Você esperou demais |

### 2. `/compact` manual com hints

Rode em **60-70% do contexto**, não espere a auto-compactação em 93%:

```
/compact Keep: estrutura atual, decisão X, arquivo Y que editamos, o erro Z
```

A versão manual é menor, direcionada e muito mais barata que a automática.

### 3. `/clear` entre tasks não relacionadas

Elimina todo o ruído de tarefas anteriores. Diferente de `/compact`, começa do zero.

### 4. Controle de esforço/reasoning

```bash
# Kiro CLI
/effort low      # respostas rápidas, sem reasoning profundo
/effort none     # desativa extended thinking (20-40% economia em tasks simples)

# Claude Code
export MAX_THINKING_TOKENS=8000   # limita de 64K para 8K
```

Para tarefas complexas que realmente precisam de reasoning, use `/effort high`. Para edições e debug simples, `low` ou `none`.

### 5. Plan Mode antes de implementar

No Claude Code: `Shift+Tab`. Faz o modelo explorar e propor abordagem ANTES de escrever código. Evita o erro mais caro: ir pelo caminho errado por 50K tokens antes de pivotar.

### 6. Subagentes para isolamento de contexto

Subagentes rodam em contexto próprio. Reads, greps e logs ficam lá dentro; só o resumo volta ao contexto principal.

```yaml
# .claude/agents/researcher.yaml (Claude Code)
name: researcher
model: haiku
tools: [Read, Grep, Glob, WebFetch]
```

```json
// Kiro CLI — .kiro/agents/scout.json
{
  "name": "scout",
  "model": "qwen3-coder-next",
  "tools": ["read", "grep", "glob", "shell"]
}
```

Economia: **40-70% no contexto principal**. Custo extra: quase zero se pinado em modelo barato.

### 7. Skills/CLAUDE.md enxutos

| Ferramenta | Regra |
|---|---|
| Claude Code | Tudo acima de 2KB sai do `CLAUDE.md` e vira skill em `.claude/skills/` (progressive disclosure) |
| Kiro CLI | Use `.kiro/skills/<nome>/SKILL.md` com frontmatter `name`/`description`; só metadata carrega no boot |

**Dica:** 5 arquivos pequenos com escopos diferentes > 1 arquivo gigante always-on.

### 8. Steering/Context condicional (Kiro)

| Modo | Quando carrega |
|---|---|
| `always` (default) | Todo turno — use só para regras universais (<5K tokens) |
| `fileMatch` (Kiro 3.0+) | Quando um arquivo do glob está em contexto |
| `manual` | Só quando invocado por slash command |

### 9. Monitorar uso do contexto

**Claude Code** — adicione ao `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "echo \"ctx $(jq -r '.context_window.remaining_percentage // 100' < $CLAUDE_STATUS_INPUT)%\""
  }
}
```

**Kiro CLI** — use `/context show` para ver breakdown por categoria.

---

## Ferramentas Open-Source Testadas

Resultados de benchmark real (ComputingForGeeks, Abril 2026) num repo TypeScript de 52 arquivos, 17.461 LOC:

| Ferramenta | Economia | O que faz | Instalação |
|---|:---:|---|---|
| **[token-savior](https://github.com/Mibayy/token-savior)** | 43% | MCP de navegação por símbolos; substitui file reads por queries pontuais | `pip install 'token-savior-recall[mcp]'` |
| **[claude-token-efficient](https://github.com/drona23/claude-token-efficient)** | 40% | CLAUDE.md com 11 regras comportamentais (619 bytes) | `curl -o CLAUDE.md <url>` |
| **[Caveman](https://github.com/JuliusBrussee/caveman)** | 38% | Skill que faz o modelo responder em linguagem densa | `bash <(curl -sL .../install.sh)` |
| **[token-optimizer-mcp](https://github.com/ooples/token-optimizer-mcp)** | 23% | Cache Brotli de tool outputs em SQLite local | `npm i -g @ooples/token-optimizer-mcp` |
| **[token-optimizer](https://github.com/alexgreensh/token-optimizer)** | 18% | Plugin com hooks: delta-reads e AST skeletons | `git clone && bash install.sh` |
| **[RTK](https://github.com/rtk-ai/rtk)** | 0-90%* | Binário Rust que filtra output de comandos shell ruidosos | `curl ... \| sh && rtk init -g` |
| **[Headroom](https://github.com/headroomlabs-ai/headroom)** | 20-95% | Proxy local de compressão reversível (logs, RAG, tool output) | `pip install "headroom-ai[all]"` |
| **[Graphify](https://github.com/safishamsi/graphify)** | variável | Knowledge graph do codebase via tree-sitter (28 linguagens) | `pip install graphify` |
| **[code-review-graph](https://github.com/tirth8205/code-review-graph)** | 5-49x* | AST graph com "blast radius" de mudanças | `uv tool install code-review-graph` |

\* RTK brilha em outputs grandes (npm install, terraform plan, git log longo). Em outputs limpos, economia é zero.
\* code-review-graph compensa apenas em monorepos com milhares de arquivos.

### Tier de recomendação

**Instale primeiro (esforço mínimo, retorno alto):**
1. `claude-token-efficient` — apenas um CLAUDE.md de 619 bytes
2. `Caveman` — comprime output do modelo em 38-65%
3. `RTK` — se seus comandos geram output ruidoso

**Instale depois (setup mais envolvido):**
4. `Headroom` — proxy transparente, comprime tudo antes do LLM
5. `Token Savior` — ótimo para TypeScript/Go/Rust com muitos símbolos
6. `Graphify` — para repos grandes ou desconhecidos

**Para monorepos gigantes:**
7. `code-review-graph` — reduz scans de arquivos drasticamente
8. `claude-context` (Zilliz) — RAG vetorial do codebase (requer OpenAI embeddings)

---

## Model Routing (Usar Modelo Certo por Tarefa)

Não precisa usar Opus/Sonnet para tudo. Roteie por complexidade:

| Tipo de tarefa | Modelo recomendado | Economia vs Opus |
|---|---|---|
| Investigação, grep, listar | Haiku 4.5 / Qwen3 Coder | 10-30x mais barato |
| Planejamento, specs | Haiku 4.5 | ~10x |
| Implementação | Sonnet 4.6 | ~3x |
| Review, segurança, debug difícil | Sonnet 4.6 / Opus | baseline |

**Ferramentas de routing:**
- **[claude-code-router](https://github.com/musistudio/claude-code-router)** (32K★) — proxy que roteia por complexidade
- **[LiteLLM](https://github.com/BerriAI/litellm)** — gateway open-source para 100+ LLMs

**No Kiro CLI:** cada agente em `.kiro/agents/*.json` aceita campo `"model"`:

```json
{
  "name": "meu-scout",
  "model": "qwen3-coder-next",
  "tools": ["read", "grep", "glob", "shell"]
}
```

Multiplicadores de crédito Kiro:
- Qwen3 Coder Next: **0.05x**
- Claude Haiku 4.5: baixo
- Claude Sonnet 4.6: **1.0x** (baseline)
- Claude Opus 4.6+: **2.0x+**
- GPT-5.6 Luna: **0.1x**

---

## Técnicas de Prompt e Comportamento

### CLAUDE.md eficiente (regras do drona23, adaptadas)

```markdown
# Convenções do projeto

- Pense antes de agir. Leia arquivos antes de escrever código.
- Seja conciso no output, profundo no raciocínio.
- Prefira editar ao invés de reescrever arquivos inteiros.
- Não releia arquivos que não mudaram.
- Pule arquivos >100KB salvo se explicitamente necessário.
- Sem aberturas bajuladoras ou encerramento floreado.
- Teste antes de declarar pronto.
- Instruções do usuário sobrescrevem este arquivo.
```

### Contratos de saída para subagentes

Force workers a retornar APENAS dados estruturados:

```
STATUS: DONE|PARTIAL|BLOCKED
CHANGED: caminhos (max 20)
VALIDATION: comando => PASS|FAIL (max 10)
BLOCKERS: none ou itens (max 5)
```

Isso impede que o subagente despeje logs, código inteiro ou narrativa de volta ao contexto principal.

### CLI em vez de MCP para operações determinísticas

| Operação | Em vez de (MCP) | Use (CLI) |
|---|---|---|
| GitHub | MCP get_issues, get_pr_diff | `gh issue view`, `gh pr diff` |
| AWS | use_aws, call_aws | `aws ... --query ... --output json` |
| Git | MCP git_status | `git status`, `git diff --stat` |

Cada chamada MCP é um turno LLM adicional (schema + argumentação + resposta). CLI é determinística e não consome tokens de raciocínio.

### Limitar output na fonte

```bash
# Em vez de: git log (500 commits no contexto)
git log --oneline -20

# Em vez de: npm install (pages de warnings)
npm install 2>&1 | tail -5

# Em vez de: find / (10K arquivos)
find src -name "*.ts" -not -path "*/node_modules/*"

# AWS com filtro
aws ec2 describe-instances --query 'Reservations[].Instances[].{Id:InstanceId,State:State.Name}' --output table
```

---

## Prompt Caching (API Level)

Se você usa a API diretamente (não apenas CLI):

| Provider | Desconto | Como |
|---|---|---|
| Anthropic | **90%** em cached tokens | `cache_control: {"type": "ephemeral"}` no system prompt |
| OpenAI | 50% automático | Prefixos >1024 tokens cacheiam sozinhos |
| Google Gemini | 90% | Implicit + explicit caching |

Para workflows repetitivos, cache hit rates >70% são fáceis de manter.

### Token-Efficient Tool Use (Anthropic)

Header: `anthropic-beta: token-efficient-tool-use-2026-04-05`

Resultado: **70% menos output tokens** em tool calls (JSON compacto em vez de XML verboso).

---

## Eliminar MCP Tools Não Usados

O GitHub mediu que 40 tools MCP adicionam **10-15KB de schema por turno**. Se o agente usa apenas 2-3 tools, as outras 37 são overhead puro.

Resultado do GitHub ao podar: **8-12KB a menos por chamada**, economia de 43-62% em workflows reais.

**Ação:** declare tools específicas no agente em vez de `"tools": ["*"]`:

```json
{
  "tools": ["read", "grep", "glob", "shell"],
  "mcpServers": {}
}
```

---

## Ferramentas de Monitoramento

| Ferramenta | O que faz |
|---|---|
| **[ccusage](https://github.com/ryoppippi/ccusage)** | CLI que reporta tokens e custo de 14+ coding agents offline |
| **[agenttrace](https://github.com/luoyuctl/agenttrace)** | TUI local para Claude Code/Codex/Gemini: tokens, cache, retries |
| **[Langfuse](https://github.com/langfuse/langfuse)** | Observabilidade open-source com cost tracking |
| `/cost` (Claude Code) | Mostra custo da sessão atual |
| `/context show` (Kiro) | Breakdown por categoria de contexto |

---

## Checklist Rápido (Aplique Hoje)

- [ ] Uma task por sessão; `/clear` entre assuntos
- [ ] `/compact` manual em 60% do contexto com hints
- [ ] `/effort low` ou `MAX_THINKING_TOKENS=8000` para tasks simples
- [ ] CLAUDE.md/steering com <500 bytes de regras universais
- [ ] Docs extensas em skills (progressive disclosure)
- [ ] Subagentes em modelo barato para investigação
- [ ] Declarar tools específicas, nunca `*`
- [ ] Zero MCP onde CLI resolve (`gh`, `git`, `aws`)
- [ ] Filtros de output na fonte (`--json --jq`, `head`, `--query`)
- [ ] Não reler arquivos inalterados
- [ ] Não ler lockfiles, builds, node_modules, binários
- [ ] Editar trechos em vez de reescrever arquivos
- [ ] Instalar `claude-token-efficient` ou equivalente
- [ ] Instalar `Caveman` para comprimir output do modelo
- [ ] Instalar `RTK` se comandos geram output grande

---

## Stack Recomendado por Perfil

### Dev solo, uso moderado
1. CLAUDE.md eficiente (drona23)
2. `MAX_THINKING_TOKENS=8000`
3. Subagente em Haiku para research
4. Sessões curtas

**Economia esperada: 50-60%**

### Power user, codebase TypeScript/Go grande
1. Token Savior (profile `core`)
2. CLAUDE.md eficiente
3. Caveman (mode `full`)
4. Subagentes + `/compact` a 60%

**Economia esperada: 55-65%**

### Monorepo 10K+ arquivos
1. code-review-graph para navegação
2. Headroom como proxy de compressão
3. Graphify ou claude-context (RAG vetorial)
4. claude-mem para memória cross-session

**Economia esperada: 60-80%**

---

## Referências

- [ComputingForGeeks — 10 Tested Tools](https://computingforgeeks.com/reduce-claude-code-token-usage-tools/) — benchmark real com números
- [Pinggy — 8 Open Source Tools](https://pinggy.io/blog/tools_to_reduce_ai_coding_agent_token_usage/) — Headroom, Graphify, Caveman
- [GitHub Blog — Token Efficiency in Agentic Workflows](https://github.blog/ai-and-ml/github-copilot/improving-token-efficiency-in-github-agentic-workflows/) — como o GitHub cortou 43-62%
- [dev.to — Kiro CLI Gets Worse After an Hour](https://dev.to/aws-builders/kiro-cli-gets-worse-after-an-hour-heres-how-i-fixed-it-1l7g) — context management prático
- [Medium — Efficient Token Usage on Kiro](https://pjay1010.medium.com/efficient-token-usage-on-kiro-a-practical-guide-7c2da8d1070b) — steering, skills, powers
- [awesome-llm-token-optimization](https://github.com/pleasedodisturb/awesome-llm-token-optimization) — curated list com papers, tools, pricing
- [claude-code-tips](https://github.com/sgaabdu4/claude-code-tips) — stack completo: Headroom + Caveman + RTK + hooks
- [Anthropic — Token-Efficient Tool Use](https://docs.anthropic.com/en/docs/agents-and-tools/tool-use/token-efficient-tool-use)
- [Anthropic — Context Engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

---

*Compilado em 11/08/2026. Ferramentas e preços mudam rápido; verifique versões antes de instalar.*
