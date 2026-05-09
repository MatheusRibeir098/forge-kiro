#!/bin/bash
# run.sh v4.3 — Orquestrador: grafo + N reviewers + tester + documenter
# Gerado pelo Orchestrator. NÃO editar manualmente.
# EXECUTAR EM TERMINAL SEPARADO, FORA DO TMUX.

PROJECT_DIR="__PROJECT_DIR__"
TASKS_FILE="$PROJECT_DIR/orchestration/tasks.json"
SESSION="__SESSION__"
TIMEOUT=9999
POLL=3
LOG="$PROJECT_DIR/orchestration/run.log"
NUM_REVIEWERS=__NUM_REVIEWERS__
HAS_TESTER=__HAS_TESTER__
HAS_DOCUMENTER=__HAS_DOCUMENTER__
MIN_WAIT=8
DOCS_DIR="$PROJECT_DIR/__DOCS_DIR__"
echo "" > "$LOG"

if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "❌ Sessão '$SESSION' não existe. Rode setup.sh primeiro." | tee -a "$LOG"; exit 1
fi

PANE_COUNT=$(jq '.panes | length' "$TASKS_FILE")
TASK_COUNT=$(jq '.tarefas | length' "$TASKS_FILE")

# Calcular panes de tester e documenter
NEXT_SPECIAL=$((PANE_COUNT + NUM_REVIEWERS))
TESTER_PANE=-1
DOCUMENTER_PANE=-1
if [ "$HAS_TESTER" = true ]; then
  TESTER_PANE=$NEXT_SPECIAL
  ((NEXT_SPECIAL++))
fi
if [ "$HAS_DOCUMENTER" = true ]; then
  DOCUMENTER_PANE=$NEXT_SPECIAL
fi

# Reviewer panes (0-based tmux index)
declare -A REV_PANE REV_CURRENT REV_DISPATCH
for r in $(seq 1 "$NUM_REVIEWERS"); do
  REV_PANE[$r]=$((PANE_COUNT + r - 1))
  REV_CURRENT[$r]=""
  REV_DISPATCH[$r]=0
done

# --- Carregar tarefas ---
declare -A T_PANE T_PROMPT T_STATUS T_DEPS T_START T_END T_DIR
declare -A P_CURRENT P_NOME P_QUEUE
IDS=()

for i in $(seq 0 $((TASK_COUNT - 1))); do
  ID=$(jq -r ".tarefas[$i].id" "$TASKS_FILE")
  IDS+=("$ID")
  T_PANE[$ID]=$(jq -r ".tarefas[$i].pane" "$TASKS_FILE")
  T_PROMPT[$ID]=$(jq -r ".tarefas[$i].prompt" "$TASKS_FILE")
  T_STATUS[$ID]="pending"
  T_DEPS[$ID]=$(jq -r ".tarefas[$i].deps[]?" "$TASKS_FILE" 2>/dev/null | tr '\n' ' ')
  T_START[$ID]=0
  T_END[$ID]=0
  p="${T_PANE[$ID]}"
  T_DIR[$ID]=$(jq -r ".panes.\"$p\".dir" "$TASKS_FILE")
done

for p in $(seq 1 "$PANE_COUNT"); do
  P_NOME[$p]=$(jq -r ".panes.\"$p\".nome" "$TASKS_FILE")
  P_CURRENT[$p]=""
  P_QUEUE[$p]=""
  for ID in "${IDS[@]}"; do
    [ "${T_PANE[$ID]}" = "$p" ] && P_QUEUE[$p]="${P_QUEUE[$p]} $ID"
  done
  P_QUEUE[$p]=$(echo "${P_QUEUE[$p]}" | xargs)
done

# --- Review state ---
REVIEW_QUEUE=()
REVIEW_DONE_LIST=()

# --- Tester state ---
TESTER_PHASE=0
TESTER_DISPATCH_TIME=0

# --- Documenter state ---
DOC_DEV_DONE=false
DOC_REVIEW_DONE=false
DOC_TESTER_DONE=false
DOC_GERAL_DONE=false
DOC_CURRENT=""
DOC_DISPATCH_TIME=0
DOC_CTX_DEV_QUEUE=()
DOC_CTX_DEV_CURRENT=""
DOC_CTX_DEV_DISPATCH=0
DOC_CTX_REVIEW_QUEUE=()
DOC_CTX_REVIEW_CURRENT=""
DOC_CTX_REVIEW_DISPATCH=0

has_prompt() {
  tmux capture-pane -t "$SESSION:0.$1" -p 2>/dev/null | grep -v '^$' | tail -5 | grep -q '!>'
}

tmux_pane() {
  echo $(($1 - 1))
}

deps_ok() {
  local dep
  for dep in ${T_DEPS[$1]}; do
    [ "${T_STATUS[$dep]}" != "done" ] && return 1
  done
  return 0
}

safe_send() {
  local pane=$1 text=$2
  tmux send-keys -t "$SESSION:0.$pane" "$text" Enter
  sleep 0.5
  tmux send-keys -t "$SESSION:0.$pane" Enter
  sleep 2
  tmux send-keys -t "$SESSION:0.$pane" Enter
}

show() {
  local elapsed=$1 done_n=0 run_n=0 rev_q=${#REVIEW_QUEUE[@]} rev_done=${#REVIEW_DONE_LIST[@]}
  for ID in "${IDS[@]}"; do
    [ "${T_STATUS[$ID]}" = "done" ] && ((done_n++))
    [[ "${T_STATUS[$ID]}" == "running" || "${T_STATUS[$ID]}" == "dispatched" ]] && ((run_n++))
  done

  printf "\033c"
  echo "╔══════════════════════════════════════════════════════════════════╗"
  printf "║  🔄 Orquestrador v4.3 (%d reviewers)  ⏱ %-5s                  ║\n" "$NUM_REVIEWERS" "${elapsed}s"
  printf "║  Dev: ✅ %d/%d  ⏳ %d  Review: ✅ %d 📝 %d fila  Tester: F%d    ║\n" "$done_n" "$TASK_COUNT" "$run_n" "$rev_done" "$rev_q" "$TESTER_PHASE"
  echo "╚══════════════════════════════════════════════════════════════════╝"
  echo ""

  echo "── DEV ──────────────────────────────────────────"
  for p in $(seq 1 "$PANE_COUNT"); do
    local curr="${P_CURRENT[$p]}"
    if [ -n "$curr" ]; then
      local dur=$(( $(date +%s) - ${T_START[$curr]} ))
      printf "  Pane %d [%-8s] ⏳ %s (%ds)\n" "$p" "${P_NOME[$p]}" "$curr" "$dur"
    else
      printf "  Pane %d [%-8s] 💤\n" "$p" "${P_NOME[$p]}"
    fi
    for ID in ${P_QUEUE[$p]}; do
      local st="${T_STATUS[$ID]}"
      if [ "$st" = "done" ]; then
        printf "    ✅ %s %ds\n" "$ID" "$(( ${T_END[$ID]} - ${T_START[$ID]} ))"
      elif [ "$st" = "running" ]; then
        printf "    ⏳ %s %ds\n" "$ID" "$(( $(date +%s) - ${T_START[$ID]} ))"
      elif [ "$st" = "dispatched" ]; then
        printf "    🚀 %s\n" "$ID"
      elif deps_ok "$ID"; then
        printf "    🟡 %s\n" "$ID"
      else
        printf "    ⬜ %s ← %s\n" "$ID" "${T_DEPS[$ID]}"
      fi
    done
  done

  echo ""
  echo "── REVIEWERS ($NUM_REVIEWERS) ───────────────────────────"
  for r in $(seq 1 "$NUM_REVIEWERS"); do
    if [ -n "${REV_CURRENT[$r]}" ]; then
      local w=$(( $(date +%s) - ${REV_DISPATCH[$r]} ))
      printf "  R%d: ⏳ %s (%ds)\n" "$r" "${REV_CURRENT[$r]}" "$w"
    else
      printf "  R%d: 💤\n" "$r"
    fi
  done
  if [ ${#REVIEW_QUEUE[@]} -gt 0 ]; then
    printf "  Fila: %s\n" "${REVIEW_QUEUE[*]}"
  fi
  if [ ${#REVIEW_DONE_LIST[@]} -gt 0 ]; then
    printf "  Feitas: %s\n" "${REVIEW_DONE_LIST[*]}"
  fi

  if [ "$HAS_TESTER" = true ]; then
    echo ""
    echo "── TESTER ───────────────────────────────────────"
    case $TESTER_PHASE in
      0) echo "  💤 Aguardando reviews terminarem" ;;
      1) echo "  ⏳ FASE 1 — integridade" ;;
      2) echo "  ⏳ FASE 2 — API" ;;
      3) echo "  ⏳ FASE 3 — E2E" ;;
      4) echo "  ✅ Concluído" ;;
    esac
  fi

  if [ "$HAS_DOCUMENTER" = true ]; then
    echo ""
    echo "── DOCUMENTER ───────────────────────────────────"
    if [ -n "$DOC_CURRENT" ]; then
      echo "  📝 Documentando: $DOC_CURRENT"
    elif [ -n "$DOC_CTX_DEV_CURRENT" ]; then
      echo "  📖 Lendo código dev: $DOC_CTX_DEV_CURRENT"
    elif [ -n "$DOC_CTX_REVIEW_CURRENT" ]; then
      echo "  📖 Lendo review: $DOC_CTX_REVIEW_CURRENT"
    else
      echo "  💤 Idle"
    fi
    if [ ${#DOC_CTX_DEV_QUEUE[@]} -gt 0 ]; then
      printf "  📋 Fila dev: %s\n" "${DOC_CTX_DEV_QUEUE[*]}"
    fi
    printf "  Dev:"
    [ "$DOC_DEV_DONE" = true ] && printf " ✅ dev.md" || printf " aguardando"
    echo ""
    printf "  Reviews:"
    [ "$DOC_REVIEW_DONE" = true ] && printf " ✅ reviews.md" || printf " aguardando"
    echo ""
    printf "  Tester:"
    [ "$DOC_TESTER_DONE" = true ] && printf " ✅ testes.md" || printf " aguardando"
    echo ""
    printf "  Geral:"
    [ "$DOC_GERAL_DONE" = true ] && printf " ✅ README.md" || printf " aguardando"
    echo ""
  fi
}

echo "=== Orquestrador v4.3: $TASK_COUNT tarefas, $PANE_COUNT dev + $NUM_REVIEWERS reviewers ===" | tee -a "$LOG"
T0=$(date +%s)

while true; do
  NOW=$(date +%s)
  ELAPSED=$((NOW - T0))
  [ $ELAPSED -ge $TIMEOUT ] && echo "⚠️ TIMEOUT" | tee -a "$LOG" && break

  # --- Checar dev panes ---
  for p in $(seq 1 "$PANE_COUNT"); do
    CURR="${P_CURRENT[$p]}"
    [ -z "$CURR" ] && continue
    tp=$(tmux_pane "$p")
    if [ "${T_STATUS[$CURR]}" = "dispatched" ]; then
      if ! has_prompt "$tp"; then
        T_STATUS[$CURR]="running"
        echo "[${ELAPSED}s] 🔄 $CURR processando (pane $p)" | tee -a "$LOG"
      fi
    elif [ "${T_STATUS[$CURR]}" = "running" ]; then
      if has_prompt "$tp"; then
        T_STATUS[$CURR]="done"
        T_END[$CURR]=$NOW
        P_CURRENT[$p]=""
        dur=$(( ${T_END[$CURR]} - ${T_START[$CURR]} ))
        echo "[${ELAPSED}s] ✅ $CURR concluída (pane $p, ${dur}s)" | tee -a "$LOG"
        REVIEW_QUEUE+=("$CURR")
        [ "$HAS_DOCUMENTER" = true ] && DOC_CTX_DEV_QUEUE+=("$CURR")
      fi
    fi
  done

  # --- Disparar tarefas de dev ---
  for ID in "${IDS[@]}"; do
    if [ "${T_STATUS[$ID]}" = "pending" ]; then
      p="${T_PANE[$ID]}"
      if [ -z "${P_CURRENT[$p]}" ] && deps_ok "$ID"; then
        T_STATUS[$ID]="dispatched"
        T_START[$ID]=$NOW
        P_CURRENT[$p]="$ID"
        tp=$(tmux_pane "$p")
        safe_send "$tp" "${T_PROMPT[$ID]}"
        echo "[${ELAPSED}s] ✉ $ID → pane $p (${P_NOME[$p]})" | tee -a "$LOG"
      fi
    fi
  done

  # --- Checar reviewers ---
  for r in $(seq 1 "$NUM_REVIEWERS"); do
    if [ -n "${REV_CURRENT[$r]}" ]; then
      pane=${REV_PANE[$r]}
      waited=$(( NOW - ${REV_DISPATCH[$r]} ))
      if [ "$waited" -ge "$MIN_WAIT" ] && has_prompt "$pane"; then
        echo "[${ELAPSED}s] 📝 Review ${REV_CURRENT[$r]} concluída (R$r)" | tee -a "$LOG"
        REVIEW_DONE_LIST+=("${REV_CURRENT[$r]}")
        [ "$HAS_DOCUMENTER" = true ] && DOC_CTX_REVIEW_QUEUE+=("${REV_CURRENT[$r]}")
        REV_CURRENT[$r]=""
      fi
    fi
  done

  # Despachar reviews
  for r in $(seq 1 "$NUM_REVIEWERS"); do
    if [ -z "${REV_CURRENT[$r]}" ] && [ ${#REVIEW_QUEUE[@]} -gt 0 ]; then
      NEXT="${REVIEW_QUEUE[0]}"
      REVIEW_QUEUE=("${REVIEW_QUEUE[@]:1}")
      REV_CURRENT[$r]="$NEXT"
      REV_DISPATCH[$r]=$NOW
      pane=${REV_PANE[$r]}
      prompt="Review incremental da tarefa $NEXT. Revise os arquivos criados/modificados por esta tarefa: ${T_PROMPT[$NEXT]}. Corrija lint, formatação, tipagem fraca, nomes pouco claros. NÃO altere assinaturas de exports. APENAS execute, ZERO texto, sem resumo."
      safe_send "$pane" "$prompt"
      echo "[${ELAPSED}s] 📝 Review $NEXT → R$r" | tee -a "$LOG"
    fi
  done

  # --- Contar ---
  DONE_N=0
  for ID in "${IDS[@]}"; do [ "${T_STATUS[$ID]}" = "done" ] && ((DONE_N++)); done

  ALL_REVIEWS_DONE=true
  [ ${#REVIEW_QUEUE[@]} -gt 0 ] && ALL_REVIEWS_DONE=false
  for r in $(seq 1 "$NUM_REVIEWERS"); do
    [ -n "${REV_CURRENT[$r]}" ] && ALL_REVIEWS_DONE=false
  done

  # --- Tester fases (ativa quando TODAS as reviews terminaram) ---
  if [ "$HAS_TESTER" = true ]; then
    if [ "$DONE_N" -eq "$TASK_COUNT" ] && [ "$ALL_REVIEWS_DONE" = true ] && [ "$TESTER_PHASE" -eq 0 ]; then
      TESTER_PHASE=1
      TESTER_DISPATCH_TIME=$NOW
      safe_send "$TESTER_PANE" "[FASE-1] Leia os arquivos em $PROJECT_DIR/backend/src/ e $PROJECT_DIR/frontend/src/ pra entender o projeto. Depois rode 'cd $PROJECT_DIR/backend && npx tsc --noEmit' e 'cd $PROJECT_DIR/frontend && npx tsc --noEmit'. Verifique imports cruzados, rotas registradas no index.ts, endpoints do frontend vs backend. Se encontrar erros, corrija. APENAS execute, ZERO texto."
      echo "[${ELAPSED}s] 🧪 FASE 1 iniciada" | tee -a "$LOG"
    fi

    if [ "$TESTER_PHASE" -ge 1 ] && [ "$TESTER_PHASE" -le 3 ]; then
      t_waited=$(( NOW - TESTER_DISPATCH_TIME ))
      if [ "$t_waited" -ge "$MIN_WAIT" ] && has_prompt "$TESTER_PANE"; then
        echo "[${ELAPSED}s] 🧪 FASE $TESTER_PHASE concluída" | tee -a "$LOG"
        if [ "$TESTER_PHASE" -eq 1 ]; then
          TESTER_PHASE=2
          TESTER_DISPATCH_TIME=$NOW
          safe_send "$TESTER_PANE" "[FASE-2] Testes de API. Suba backend e frontend EXATAMENTE assim: 'tmux new-session -d -s servers' depois 'tmux send-keys -t servers:0 \"cd $PROJECT_DIR/backend && npx tsx src/index.ts\" Enter' depois 'tmux split-window -v -t servers:0' depois 'tmux send-keys -t servers:0.1 \"cd $PROJECT_DIR/frontend && npx vite --port 3000\" Enter'. Aguarde 5s. Teste TODOS os endpoints do orchestration/context.md com curl. PROIBIDO rodar tmux kill-server ou tmux kill-session sem -t servers. APENAS execute, ZERO texto."
          echo "[${ELAPSED}s] 🧪 FASE 2 iniciada" | tee -a "$LOG"
        elif [ "$TESTER_PHASE" -eq 2 ]; then
          TESTER_PHASE=3
          TESTER_DISPATCH_TIME=$NOW
          safe_send "$TESTER_PANE" "[FASE-3] Testes E2E com Playwright. Servidores já rodando. Crie testes em e2e/tests/ cobrindo navegação, CRUD. Rode com 'cd e2e && npx playwright test --project=chromium'. Se falhar, corrija. Ao terminar, 'tmux kill-session -t servers'. APENAS execute, ZERO texto, sem resumo."
          echo "[${ELAPSED}s] 🧪 FASE 3 iniciada" | tee -a "$LOG"
        elif [ "$TESTER_PHASE" -eq 3 ]; then
          TESTER_PHASE=4
          echo "[${ELAPSED}s] 🧪 CONCLUÍDO" | tee -a "$LOG"
        fi
      fi
    fi
  fi

  # --- Documenter ---
  if [ "$HAS_DOCUMENTER" = true ]; then
    # Contexto dev (fila)
    if [ -n "$DOC_CTX_DEV_CURRENT" ] && [ -z "$DOC_CURRENT" ]; then
      dcd_waited=$(( NOW - DOC_CTX_DEV_DISPATCH ))
      if [ "$dcd_waited" -ge "$MIN_WAIT" ] && has_prompt "$DOCUMENTER_PANE"; then
        echo "[${ELAPSED}s] 📄 Contexto dev $DOC_CTX_DEV_CURRENT lido" | tee -a "$LOG"
        DOC_CTX_DEV_CURRENT=""
      fi
    fi
    if [ -z "$DOC_CTX_DEV_CURRENT" ] && [ -z "$DOC_CURRENT" ] && [ -z "$DOC_CTX_REVIEW_CURRENT" ] && [ ${#DOC_CTX_DEV_QUEUE[@]} -gt 0 ] && [ "$DOC_DEV_DONE" = false ]; then
      NEXT_DC="${DOC_CTX_DEV_QUEUE[0]}"
      DOC_CTX_DEV_QUEUE=("${DOC_CTX_DEV_QUEUE[@]:1}")
      DOC_CTX_DEV_CURRENT="$NEXT_DC"
      DOC_CTX_DEV_DISPATCH=$NOW
      dir="${T_DIR[$NEXT_DC]}"
      safe_send "$DOCUMENTER_PANE" "[CONTEXTO-DEV] Tarefa $NEXT_DC concluída (pane ${T_PANE[$NEXT_DC]}, dir: $dir, $(( ${T_END[$NEXT_DC]} - ${T_START[$NEXT_DC]} ))s). Abra e leia TODOS os arquivos em $PROJECT_DIR/$dir/src/ que foram criados por esta tarefa. Use a ferramenta de leitura. Diga apenas ok ao terminar."
      echo "[${ELAPSED}s] 📄 Contexto dev $NEXT_DC → documenter" | tee -a "$LOG"
    fi

    # DOC-DEV
    if [ "$DONE_N" -eq "$TASK_COUNT" ] && [ "$DOC_DEV_DONE" = false ] && [ -z "$DOC_CURRENT" ] && [ -z "$DOC_CTX_DEV_CURRENT" ] && [ -z "$DOC_CTX_REVIEW_CURRENT" ] && [ ${#DOC_CTX_DEV_QUEUE[@]} -eq 0 ]; then
      DOC_CURRENT="dev"
      DOC_DISPATCH_TIME=$NOW
      safe_send "$DOCUMENTER_PANE" "[DOC-DEV] Projeto em $PROJECT_DIR. Crie o arquivo $DOCS_DIR/dev.md com fs_write. Conteúdo: cabeçalho (projeto, stack, data), uma seção por pane (tarefas, arquivos criados, tempo, decisões técnicas), resumo final (tempo total, arquivos, linhas). Leia orchestration/run.log e os arquivos de código. OBRIGATÓRIO criar o arquivo com fs_write. APENAS execute, ZERO texto."
      echo "[${ELAPSED}s] 📄 DOC-DEV iniciado" | tee -a "$LOG"
    fi

    # Contexto review (fila)
    if [ -n "$DOC_CTX_REVIEW_CURRENT" ] && [ -z "$DOC_CURRENT" ]; then
      dcr_waited=$(( NOW - DOC_CTX_REVIEW_DISPATCH ))
      if [ "$dcr_waited" -ge "$MIN_WAIT" ] && has_prompt "$DOCUMENTER_PANE"; then
        echo "[${ELAPSED}s] 📄 Contexto review $DOC_CTX_REVIEW_CURRENT lido" | tee -a "$LOG"
        DOC_CTX_REVIEW_CURRENT=""
      fi
    fi
    if [ -z "$DOC_CTX_REVIEW_CURRENT" ] && [ -z "$DOC_CTX_DEV_CURRENT" ] && [ -z "$DOC_CURRENT" ] && [ ${#DOC_CTX_REVIEW_QUEUE[@]} -gt 0 ] && [ "$DOC_REVIEW_DONE" = false ]; then
      NEXT_DR="${DOC_CTX_REVIEW_QUEUE[0]}"
      DOC_CTX_REVIEW_QUEUE=("${DOC_CTX_REVIEW_QUEUE[@]:1}")
      DOC_CTX_REVIEW_CURRENT="$NEXT_DR"
      DOC_CTX_REVIEW_DISPATCH=$NOW
      safe_send "$DOCUMENTER_PANE" "[CONTEXTO-REVIEW] Review da tarefa $NEXT_DR concluída por um reviewer. Abra e leia os arquivos que foram modificados pela tarefa $NEXT_DR em $PROJECT_DIR/. Use a ferramenta de leitura. Identifique mudanças. Diga apenas ok ao terminar."
      echo "[${ELAPSED}s] 📄 Contexto review $NEXT_DR → documenter" | tee -a "$LOG"
    fi

    # DOC-REVIEW
    if [ "$ALL_REVIEWS_DONE" = true ] && [ "$DOC_REVIEW_DONE" = false ] && [ "$DOC_DEV_DONE" = true ] && [ -z "$DOC_CURRENT" ] && [ -z "$DOC_CTX_REVIEW_CURRENT" ] && [ -z "$DOC_CTX_DEV_CURRENT" ] && [ ${#DOC_CTX_REVIEW_QUEUE[@]} -eq 0 ] && [ ${#DOC_CTX_DEV_QUEUE[@]} -eq 0 ]; then
      DOC_CURRENT="review"
      DOC_DISPATCH_TIME=$NOW
      safe_send "$DOCUMENTER_PANE" "[DOC-REVIEW] Projeto em $PROJECT_DIR. Leia os arquivos de código pra ver o estado atual após as reviews. Compare com o que você já conhece dos contextos. Crie o arquivo $DOCS_DIR/reviews.md com fs_write. Conteúdo: uma seção por reviewer (tarefas revisadas, problemas encontrados, correções), resumo final. OBRIGATÓRIO criar o arquivo com fs_write. APENAS execute, ZERO texto."
      echo "[${ELAPSED}s] 📄 DOC-REVIEW iniciado" | tee -a "$LOG"
    fi

    # DOC-TESTER
    if [ "$HAS_TESTER" = true ] && [ "$DOC_REVIEW_DONE" = true ] && [ "$TESTER_PHASE" -eq 4 ] && [ "$DOC_TESTER_DONE" = false ] && [ -z "$DOC_CURRENT" ]; then
      DOC_CURRENT="tester"
      DOC_DISPATCH_TIME=$NOW
      bash "$PROJECT_DIR/clean-logs.sh" > /dev/null 2>&1
      safe_send "$DOCUMENTER_PANE" "[DOC-TESTER] Projeto em $PROJECT_DIR. Crie o arquivo $DOCS_DIR/testes.md com fs_write. Leia orchestration/logs/clean/pane-$TESTER_PANE.log (log do tester) e e2e/tests/ (testes criados). Documente: fase 1 (integridade), fase 2 (API), fase 3 (E2E). OBRIGATÓRIO criar o arquivo com fs_write. APENAS execute, ZERO texto."
      echo "[${ELAPSED}s] 📄 DOC-TESTER iniciado" | tee -a "$LOG"
    fi

    # DOC-GERAL
    if [ "$DOC_TESTER_DONE" = true ] && [ "$DOC_GERAL_DONE" = false ] && [ -z "$DOC_CURRENT" ]; then
      DOC_CURRENT="geral"
      DOC_DISPATCH_TIME=$NOW
      safe_send "$DOCUMENTER_PANE" "[DOC-GERAL] Projeto em $PROJECT_DIR. Leia $DOCS_DIR/dev.md, $DOCS_DIR/reviews.md e $DOCS_DIR/testes.md. Crie o arquivo $DOCS_DIR/README.md com fs_write. Conteúdo: visão geral do projeto, stack, arquitetura, métricas, qualidade do código, conclusão. OBRIGATÓRIO criar o arquivo com fs_write. APENAS execute, ZERO texto."
      echo "[${ELAPSED}s] 📄 DOC-GERAL iniciado" | tee -a "$LOG"
    fi

    # DOC-REVIEW (sem tester — pula direto pra DOC-GERAL)
    if [ "$HAS_TESTER" = false ] && [ "$DOC_REVIEW_DONE" = true ] && [ "$DOC_TESTER_DONE" = false ] && [ -z "$DOC_CURRENT" ]; then
      DOC_TESTER_DONE=true  # skip
    fi

    # Checar conclusão do documenter
    if [ -n "$DOC_CURRENT" ]; then
      doc_waited=$(( NOW - DOC_DISPATCH_TIME ))
      if [ "$doc_waited" -ge "$MIN_WAIT" ] && has_prompt "$DOCUMENTER_PANE"; then
        echo "[${ELAPSED}s] 📄 DOC-$DOC_CURRENT concluído" | tee -a "$LOG"
        case "$DOC_CURRENT" in
          dev) DOC_DEV_DONE=true ;;
          review) DOC_REVIEW_DONE=true ;;
          tester) DOC_TESTER_DONE=true ;;
          geral) DOC_GERAL_DONE=true ;;
        esac
        DOC_CURRENT=""
      fi
    fi
  fi

  # --- Condição de término ---
  FINISHED=false
  if [ "$DONE_N" -eq "$TASK_COUNT" ] && [ "$ALL_REVIEWS_DONE" = true ]; then
    if [ "$HAS_TESTER" = true ] && [ "$HAS_DOCUMENTER" = true ]; then
      [ "$TESTER_PHASE" -eq 4 ] && [ "$DOC_GERAL_DONE" = true ] && FINISHED=true
    elif [ "$HAS_TESTER" = true ]; then
      [ "$TESTER_PHASE" -eq 4 ] && FINISHED=true
    elif [ "$HAS_DOCUMENTER" = true ]; then
      [ "$DOC_GERAL_DONE" = true ] && FINISHED=true
    else
      FINISHED=true
    fi
  fi
  [ "$FINISHED" = true ] && break

  show "$ELAPSED"
  sleep $POLL
done

TOTAL=$(($(date +%s) - T0))
echo "" | tee -a "$LOG"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$LOG"
echo "  ✅ CONCLUÍDO em ${TOTAL}s ($((TOTAL/60))m$((TOTAL%60))s)" | tee -a "$LOG"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$LOG"

echo "" | tee -a "$LOG"
echo "=== Tempo por tarefa ===" | tee -a "$LOG"
for ID in "${IDS[@]}"; do
  [ "${T_START[$ID]}" -gt 0 ] && [ "${T_END[$ID]}" -gt 0 ] && \
    echo "  $ID (pane ${T_PANE[$ID]}): $(( ${T_END[$ID]} - ${T_START[$ID]} ))s" | tee -a "$LOG"
done

echo "" | tee -a "$LOG"
BC=$(find "$PROJECT_DIR/backend/src" -type f 2>/dev/null | wc -l)
FC=$(find "$PROJECT_DIR/frontend/src" -type f 2>/dev/null | wc -l)
echo "Arquivos: Backend=$BC Frontend=$FC Total=$((BC+FC))" | tee -a "$LOG"
