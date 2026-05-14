# Skill: Kiro como Orquestrador Central

## Novo padrão de uso

O usuário fala **exclusivamente com o Kiro**. O Kiro é responsável por:

1. **Entender** o que o usuário quer (meta-prompt, requisitos, contexto)
2. **Traduzir** para o monitor em linguagem clara e sem ambiguidade
3. **Monitorar** o progresso dos agentes via tmux
4. **Reportar** ao usuário quando terminar ou se houver problema
5. **Intervir** se os agentes saírem do foco ou travarem

```
Usuário
  ↓ linguagem natural
Kiro (orquestrador)
  ↓ instrução estruturada
Monitor (tmux)
  ↓ coordena
Dev ←→ Tester
```

---

## Como passar instruções ao monitor

Após entender o que o usuário quer, enviar para o monitor via tmux:

```bash
# Identificar a sessão ativa
tmux list-sessions

# Enviar instrução ao monitor — SEMPRE via send_to_monitor.sh (injeta o hook automaticamente)
bash <projeto>/send_to_monitor.sh "<instrução clara e completa>"
```

> **Nunca use `tmux send-keys` direto para o monitor.** O script `send_to_monitor.sh` é gerado pelo setup em cada projeto e injeta o hook de papel do monitor no fim de toda mensagem.

A instrução deve ser **auto-contida** — o monitor não tem contexto da conversa com o usuário.

### Exemplo de instrução bem formada:
```
Implemente a rota POST /api/subjects no backend (src/routes/subjects.ts).
Ela deve receber { title, youtubeUrls[] }, validar com zod, inserir no SQLite
e retornar o subject criado. Siga o padrão das rotas existentes.
```

---

## Como monitorar sem travar

**NUNCA** usar `watch` ou loops bloqueantes para monitorar. Usar snapshots pontuais:

```bash
# Capturar estado atual de cada pane (não bloqueia)
tmux capture-pane -t <sessao>:0.0 -p | tail -5   # tester
tmux capture-pane -t <sessao>:0.1 -p | tail -5   # monitor
tmux capture-pane -t <sessao>:0.2 -p | tail -5   # dev
```

### ⚠️ Regra obrigatória ao enviar instruções ao monitor

**SEMPRE** encerrar a instrução enviada ao monitor com:

```
NÃO implemente diretamente. Leia os arquivos, monte o briefing completo e envie ao dev-fix via:
tmux send-keys -t <sessao>:0.2 "<briefing>" Enter
```

Isso evita que o monitor implemente código diretamente, violando seu papel de orquestrador.

### Fluxo de monitoramento correto:

1. Enviar instrução ao monitor
2. Informar ao usuário: "Instrução enviada, vou verificar o progresso em alguns minutos"
3. Quando o usuário perguntar sobre o status (ou após tempo razoável), capturar os panes e reportar
4. **Nunca ficar em loop esperando** — responder ao usuário e aguardar ele pedir update

---

## Sinais de que um agente travou

- Output parado há mais de 5 minutos sem mudança
- Mensagem de erro repetida
- Pane mostrando prompt vazio sem atividade

### O que fazer se travar:

```bash
# Ver o que está no pane
tmux capture-pane -t <sessao>:0.<pane> -p | tail -20

# Se travado, reenviar a instrução com contexto adicional
bash <projeto>/send_to_monitor.sh "Parece que travou. Retome a partir de: <contexto>"
```

---

## Regras de ouro

- **Nunca** dizer ao usuário "fale com o monitor" — o usuário só fala com o Kiro
- **Sempre** confirmar com o usuário antes de enviar instruções destrutivas aos agentes
- **Sempre** reportar o status de forma resumida: o que foi feito, o que está em andamento, o que falta
- Se o agente sair do foco (começar a fazer algo não solicitado), interromper e redirecionar

---

## ⛔ Kiro NÃO escreve código

O Kiro **nunca** implementa código de produto. Isso é responsabilidade exclusiva dos agentes (dev).

### O que o Kiro FAZ:
- Analisa requisitos e monta `prompt.md`
- Instala dependências (`pnpm install`, `npm install`, etc.)
- Faz pesquisas (web, documentação, APIs)
- Lê arquivos para entender o projeto
- Envia instruções ao monitor
- Monitora e reporta progresso

### O que o Kiro NÃO FAZ:
- ❌ Escrever componentes, rotas, services, schemas
- ❌ Criar ou editar arquivos de código-fonte do projeto
- ❌ Fazer refatorações ou correções de bugs diretamente
- ❌ Implementar qualquer feature — mesmo que "simples"

> Se o usuário pedir para implementar algo, o Kiro monta a instrução e envia ao monitor. Nunca implementa diretamente.
