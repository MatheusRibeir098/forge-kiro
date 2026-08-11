---
name: token-discipline
description: Regras obrigatorias de economia de contexto para workers Forge: leitura seletiva, outputs de shell limitados, zero repeticao, CLI deterministico em vez de MCP, respostas densas e parada imediata ao concluir. Use em toda execucao de subagente.
---

# Disciplina de tokens dos workers

Objetivo: maximizar trabalho correto por token. Contexto menor melhora custo e qualidade. Siga todas as regras.

## Explorar

1. Comece com uma busca ampla barata (`glob`, `grep`, mapa de simbolos), depois estreite.
2. Leia somente arquivos relevantes e apenas os trechos necessarios. Prefira simbolo, intervalo de linhas ou match com contexto a arquivo inteiro.
3. Antes de ler, use `wc -l`/tamanho quando houver risco de arquivo grande. Nao leia binarios, lockfiles, artefatos, snapshots ou arquivos >100 KB sem necessidade explicita.
4. Nao releia arquivo inalterado. Depois de editar, leia somente o trecho modificado ou use diff.
5. Nao varra `node_modules`, `.git`, `dist`, `build`, caches, cobertura ou dependencias vendorizadas.
6. Quando o caminho/simbolo e conhecido, va direto a ele; nao redescubra a estrutura.

## Shell e ferramentas

1. Prefira tools nativas de `read`, `grep`, `glob` e `code`; use shell apenas quando a tool dedicada nao resolve.
2. Para GitHub use `gh`; para AWS use AWS CLI; para git use `git`; para testes use o runner do projeto. Nao use MCP para operacoes deterministicas que uma CLI executa em uma chamada.
3. Solicite dados estruturados e campos minimos: `gh ... --json <campos> --jq ...`, `aws ... --query ... --output json`, `git diff --stat` antes do diff completo.
4. Limite output na fonte: filtros do proprio comando, arquivo/teste alvo, `--max-count`, `--quiet`, `--short`, `tail -n`, `head -n`. Nunca despeje logs sem limite.
5. Se um comando gerar muito output, salve localmente e pesquise/resuma; nao devolva o blob ao contexto.
6. Rode o teste mais estreito primeiro. Amplie para suite, lint, typecheck ou build somente quando necessario para a conclusao.
7. Nao repita comando cujo resultado continua valido.
8. Nao instale ferramenta/dependencia para economizar poucos tokens. Use o que ja existe; adicao de dependencia exige justificativa e versao fixa.

## Contexto e raciocinio

1. Trate cada subagente como uma tarefa unica. Nao execute melhorias adjacentes.
2. Planeje internamente, aja e pare. Nao exponha chain-of-thought ou diario de trabalho.
3. Preserve numeros, caminhos, simbolos, erros, decisoes e constraints; remova introducoes, transicoes, elogios e conhecimento obvio.
4. Nao copie prompt, issue, codigo ou output recebido na resposta final.
5. Quando bloqueado, pare cedo. Informe evidencia e o unico dado necessario para destravar; nao tente variantes especulativas sem limite.
6. Pesquisa web so quando uma versao/API externa ou fato atual for indispensavel. Uma busca ampla; buscas adicionais apenas se faltar fato necessario.

## Escrita

1. Edite em vez de reescrever arquivos completos.
2. Agrupe alteracoes logicas por arquivo; evite multiplas escritas no mesmo arquivo.
3. Mude o menor conjunto que satisfaz criterios. Sem refactor oportunista, comentarios redundantes, docs nao solicitadas ou novas abstracoes prematuras.
4. Nao mostre codigo completo na resposta; reporte caminhos e validacao.

## Saida

Use o contrato pedido pelo orquestrador. Frases curtas, sem emoji, saudacao, tabela decorativa ou recapitulacao. Limites sao maximos, nao metas. Se concluiu, pare imediatamente.

## Qualidade nao negociavel

Economia nunca autoriza: pular teste relevante; omitir blocker; adivinhar API; ignorar seguranca; declarar sucesso sem evidencia; truncar erro antes da causa. Se houver trade-off, reduza exploracao/prosa, nao verificacao.
