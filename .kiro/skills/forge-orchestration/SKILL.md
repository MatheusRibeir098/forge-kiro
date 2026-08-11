---
name: forge-orchestration
description: Protocolo do Forge Master para decompor trabalho, escolher workers, montar DAGs paralelos seguros, executar review loops e agregar resultados de subagentes sem tmux. Use sempre que uma solicitacao exigir investigacao, planejamento, implementacao, teste, revisao, frontend ou criacao de issues.
---

# Orquestracao nativa do Forge

O Forge Master e o unico interlocutor do usuario. Workers nunca conversam diretamente com o usuario. Use a tool `subagent`; nunca abra tmux, outra sessao de chat ou processo `kiro-cli` para simular agentes.

## Workers

| Worker | Uso | Pode escrever |
|---|---|---|
| `forge-scout` | localizar simbolos, mapear arquitetura, pesquisar docs | nao |
| `forge-spec` | requisitos, design, plano, dependencias, criterios | somente artefatos de spec solicitados |
| `forge-dev` | implementar backend, infra ou codigo geral | sim |
| `forge-test` | executar testes, diagnosticar falhas, validar criterios | somente correcoes triviais quando autorizado |
| `forge-review` | revisar diff, seguranca, escopo e qualidade | nao |
| `forge-ui` | implementar e validar frontend visual | sim, somente frontend |
| `forge-issue` | criar/editar issues via `gh` | somente GitHub, apos aprovacao |

## Decisao de delegacao

Nao delegue tarefas triviais que custam menos que preparar o handoff. Delegue quando houver pelo menos um: exploracao ampla; especialidade; trabalho independente paralelo; isolamento de output volumoso; implementacao seguida de auditoria.

Escolha o menor pipeline suficiente:

- pergunta sobre repo: `scout`
- feature clara: `dev -> test -> review`
- feature ambigua: `scout -> spec -> dev -> test -> review`
- frontend: `scout? -> spec? -> ui -> test -> review`
- bug: `scout -> dev -> test -> review`
- planejamento GitHub: `spec -> issue`
- EPIC com tarefas independentes: `spec -> dev-* em ondas -> test -> review`

## Preparar cada stage

O prompt deve ser autocontido e curto. Inclua apenas:

1. objetivo e criterio de conclusao;
2. caminho absoluto do repositorio;
3. arquivos/simbolos conhecidos, sem colar conteudo que o worker pode ler;
4. restricoes e comandos de validacao relevantes;
5. contrato de saida abaixo.

Nao envie historico da conversa, elogios, justificativas longas, output bruto, conteudo integral de issues ou arquivos quando uma referencia/caminho basta. Para GitHub, prefira numero da issue e repositorio; o worker usa `gh issue view`.

## DAG e concorrencia

Planeje o grafo inteiro antes da chamada. Stages sem `depends_on` executam em paralelo.

Pode paralelizar: pesquisa independente, auditorias read-only, issues diferentes, implementacoes em conjuntos de arquivos disjuntos.

Nao pode paralelizar: dois writers no mesmo arquivo/modulo; migrations dependentes; implementacao e teste da mesma mudanca; mutacoes no mesmo recurso remoto. Se houver duvida de conflito, execute sequencialmente.

Para EPICs, ordene dependencias por topological sort. Ciclo e blocker: pare e reporte. Cada onda deve produzir codigo validado antes da proxima.

## Review loop

Para implementacao relevante, use no maximo 2 retornos:

1. implementador emite `STATUS: DONE`;
2. tester/reviewer emite `VERDICT: PASS` ou `VERDICT: NEEDS_CHANGES`;
3. configure `loop_to` para retornar ao implementador quando houver `NEEDS_CHANGES`, `max_iterations: 2`.

O feedback deve listar somente falhas acionaveis com arquivo/linha, evidencia e correcao esperada. Nao crie loop para preferencias cosmeticas.

## Contratos de saida

Todo worker deve terminar exatamente com um contrato compacto. Nao aceitar narrativa livre.

Worker de leitura/planejamento:

```text
STATUS: DONE|BLOCKED
SUMMARY: <=5 linhas
EVIDENCE: caminho:linha ou comando; <=8 itens
DECISIONS: <=5 itens
RISKS: <=5 itens
NEXT: acao unica ou none
```

Worker de escrita:

```text
STATUS: DONE|PARTIAL|BLOCKED
CHANGED: caminhos; <=20 itens
VALIDATION: comando => PASS|FAIL; <=10 itens
NOTES: <=5 linhas
BLOCKERS: none ou <=5 itens
```

Reviewer/tester:

```text
VERDICT: PASS|NEEDS_CHANGES|BLOCKED
CHECKS: criterio => PASS|FAIL; <=12 itens
FINDINGS: severidade caminho:linha evidencia correcao; <=10 itens
VALIDATION: comando => PASS|FAIL; <=10 itens
```

## Agregacao do Master

Retenha do retorno apenas: status, arquivos, comandos/evidencias, blockers e decisoes. Nao repita logs ou explicacoes dos workers. Informe ao usuario resultado, verificacao e pendencias. O Master assume responsabilidade final: sucesso de subagente nao substitui evidencia de teste.

## Falhas

- timeout/erro transitório: repetir uma vez com prompt menor;
- falta de contexto: enviar somente o dado ausente;
- permissao/credencial: parar e pedir a menor intervencao necessaria;
- conflito de escrita: interromper a onda, inspecionar diff, serializar;
- worker fora do escopo: descartar resultado e reenviar escopo explicito;
- validacao falhou apos 2 loops: reportar bloqueio com evidencia, sem continuar gastando tokens.
