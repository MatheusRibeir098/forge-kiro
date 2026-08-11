# Forge: orquestracao nativa do Kiro

O Forge e um conjunto de custom agents e skills locais. O usuario conversa apenas com `forge-master`; ele identifica o projeto, monta um DAG de trabalho, invoca subagentes nativos do Kiro em contextos isolados, agrega evidencias e entrega o resultado. Nao existe tmux, monitor pane, forge-loop ou fix-loop.

## Arquitetura

```text
usuario
  -> forge-master (entendimento, DAG, aprovacao, agregacao)
       -> forge-scout (investigacao read-only)
       -> forge-spec (requisitos/design)
       -> forge-dev (implementacao geral)
       -> forge-ui (frontend)
       -> forge-test (validacao)
       -> forge-review (auditoria read-only)
       -> forge-issue (mutacao GitHub aprovada)
       -> forge-epic-planner / forge-epic-decomposer
       -> quicksight-builder / quicksight-migrator / forge-pentest
```

Workers compartilham o workspace, mas cada um recebe contexto de conversa isolado. Somente o contrato final volta ao Master. Stages independentes podem rodar em paralelo; writers que tocam o mesmo arquivo sempre rodam em sequencia.

Pipeline padrao de feature:

```text
scout? -> spec? -> dev|ui -> test -> review
                           ^             |
                           | NEEDS_CHANGES (max 2)
                           +-------------+
```

## Roteamento de modelos

| Agente | Modelo | Motivo |
|---|---|---|
| forge-master | GPT-5.6 Terra | coordenacao forte com multiplicador Kiro 1.0x |
| forge-scout | Qwen3 Coder Next | exploracao de alto volume; 0.05x |
| forge-issue | Qwen3 Coder Next | transformacao estruturada e `gh` deterministico |
| forge-spec | Claude Haiku 4.5 | planejamento focado com custo baixo |
| forge-test | Claude Haiku 4.5 | execucao/diagnostico frequente e rapido |
| forge-epic-* | Claude Haiku 4.5 | planejamento read-only |
| forge-dev | Claude Sonnet 4.6 | implementacao onde erro custa caro |
| forge-review | Claude Sonnet 4.6 | julgamento de corretude/seguranca |
| forge-ui | Claude Sonnet 4.6 | codigo + julgamento visual |
| QuickSight/pentest | Claude Sonnet 4.6 | operacoes especializadas e sensiveis |

Para economia extrema, `forge-dev` e `forge-review` podem ser alterados para `qwen3-coder-next`; isso reduz creditos, mas nao e o padrao porque pode reduzir qualidade em refactors e auditorias. Para tarefas excepcionalmente dificeis, mude apenas o worker necessario, nao todo o pipeline.

## Economia de tokens aplicada

1. **Progressive disclosure:** procedimentos vivem em `.kiro/skills/<nome>/SKILL.md`. No startup entra apenas `name`/`description`; o corpo carrega sob demanda.
2. **Sem heranca implicita:** `.kiro/settings/cli.json` define `chat.disableInheritingDefaultResources=true`. Cada agente recebe somente skills explicitamente declaradas.
3. **Isolamento por subagente:** reads, greps, logs e pesquisa ficam no contexto do worker; o Master recebe apenas status/evidencia.
4. **Model routing:** modelos baratos cuidam de volume e modelos fortes ficam nas etapas com maior impacto de erro.
5. **Tools minimas:** nenhum `*`. Master usa sete categorias nativas. Workers gerais usam zero MCP.
6. **MCP podado:** apenas `forge-ui` carrega `forge-frontend`, com tools selecionadas. QuickSight e pentest usam CLI.
7. **CLI antes de MCP:** `gh`, `git`, AWS CLI e runners fazem coleta deterministica sem um turno LLM adicional.
8. **Output contracts:** workers retornam no maximo status, arquivos, checks, findings e blockers; sem narrativa, codigo ou logs repetidos.
9. **Leitura seletiva:** busca ampla barata, leitura por trecho/simbolo, sem reler arquivo inalterado e sem lockfiles/builds.
10. **Output limitado na fonte:** `--json`/`--jq`, `--query`, teste alvo, `head`/`tail`, logs em arquivo pesquisavel.
11. **Review loops limitados:** no maximo duas correcoes antes de reportar blocker, evitando loops descontrolados.
12. **QA sob demanda:** regras Playwright/screenshot sairam do steering always-on e carregam somente no `forge-test` para frontend.
13. **Context hygiene:** nova sessao ou `/clear` entre assuntos; `/compact` em checkpoints, preservando decisoes, arquivos, validacoes e blockers.

### Ferramentas externas nao instaladas deliberadamente

Headroom, Token Savior, RTK, Caveman e caches MCP tiveram resultados em workloads especificos, mas nao foram adicionados como dependencia global: Headroom nao tem integracao Kiro nativa verificada; servidores de navegacao/cache adicionam schemas MCP a cada turno; RTK ajuda apenas em comandos ruidosos. O Forge aplica os beneficios comprovados sem essa sobrecarga: navegacao por `code`/grep, filtros de output, linguagem densa, contexts isolados e tools podadas. Instale uma dessas ferramentas apenas depois de medir o workload real e comparar taxa de sucesso, tokens por chamada e latencia.

## Arquivos

```text
.kiro/
  agents/
    forge-master.json
    forge-{scout,spec,dev,test,review,ui,issue}.json
    forge-epic-{planner,decomposer}.json
    prompts/*.md
  skills/
    forge-orchestration/SKILL.md
    token-discipline/SKILL.md
    tester-rules/SKILL.md
    ...skills de dominio...
  settings/
    cli.json
    mcp.json
```

`settings/mcp.json` pode continuar disponível para agentes manuais, mas todos os agentes Forge centrais usam `includeMcpJson:false`; portanto esse manifesto nao entra em seus prompts.

## Uso

Inicie no diretorio Forge:

```bash
cd /home/math3us/forge
kiro-cli chat --agent forge-master
```

Descreva projeto e resultado. O Master pergunta somente informacao indispensavel, informa progresso curto e coordena todo o pipeline. Para acompanhar uma execucao longa de subagentes no CLI, use `Ctrl+G`; isso e opcional e nao exige interacao com workers.

## Operacoes remotas

Deploy, push, publish, exclusao, producao, IAM/permissoes e outras mudancas de alto impacto exigem confirmacao explicita. Issues/PRs exigem aprovacao do plano, salvo quando o pedido do usuario ja autoriza claramente a criacao. Workers nunca recebem segredos em prompts; usam perfis e variaveis do ambiente.

## Medicao recomendada

Compare por tipo de tarefa, nao apenas tokens brutos:

- taxa de conclusao correta;
- chamadas LLM por tarefa;
- tokens de input/output/cache por chamada;
- tempo total;
- numero de loops/retries;
- testes/criterios atendidos.

Uma otimizacao so permanece se reduzir custo mantendo ou melhorando a taxa de sucesso.

## Rollback

Backup anterior a esta migracao:

```text
/home/math3us/forge-kiro-backup-20260811-1144.tar.gz
```

Restaure somente com confirmacao, pois sobrescreve `.kiro` atual.
