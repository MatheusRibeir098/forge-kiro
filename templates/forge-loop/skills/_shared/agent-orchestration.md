# Skill: Orquestração de Agents via tmux

## Enviar mensagem para um agent

Triple Enter com delays para garantir que o agent recebe:
```bash
tmux send-keys -t <session>:<pane> "" Enter
sleep 0.5
tmux send-keys -t <session>:<pane> "" Enter
sleep 0.5
tmux send-keys -t <session>:<pane> "MENSAGEM" Enter
sleep 2
tmux send-keys -t <session>:<pane> "" Enter
```

## Verificar se agent terminou

```bash
tmux capture-pane -t <session>:<pane> -p | tail -5
```
O agent terminou quando aparece `!>` no final da saída.

Loop de espera:
```bash
while true; do
  output=$(tmux capture-pane -t <session>:<pane> -p | tail -3)
  if echo "$output" | grep -q '!>'; then break; fi
  sleep 8
done
```

Tempo mínimo de espera: 8 segundos entre checks. Não checar mais rápido.

## Briefing de qualidade para o dev

Um bom briefing SEMPRE inclui:
- **Arquivo(s)**: caminho completo dos arquivos a modificar
- **Problema**: comportamento atual vs esperado (com erro exato se houver)
- **Restrições**: o que NÃO pode ser alterado
- **Contexto**: interfaces, tipos, como o código é chamado
- **Exemplo**: se possível, mostrar input → output esperado

Briefing ruim → código ruim → loop infinito. Invista tempo no briefing.

## Briefing para o tester

Deve ser curto e direto:
- O que testar (qual fluxo/funcionalidade)
- Como testar (passos específicos)
- Resultado esperado
- Escopo: APENAS o que é relevante para a mudança

## Regras críticas

- NUNCA editar código diretamente — sempre delegar ao dev
- NUNCA usar `tmux kill-server` — mata tudo
- Sempre aguardar `!>` antes de enviar nova mensagem
- Se o loop repetir 3x o mesmo erro: reformular briefing completamente
- Capturar output do pane para entender o que o agent fez
