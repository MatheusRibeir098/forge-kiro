#!/usr/bin/env bash
# Setup do forge-loop (criação de projeto do zero)
# Uso: bash setup-forge.sh <diretorio-do-projeto> [nome-sessao]
set -euo pipefail

PROJECT_DIR="${1:?Uso: bash setup-forge.sh <diretorio-do-projeto> [nome-sessao]}"
PROJECT_DIR="$(cd "$PROJECT_DIR" 2>/dev/null && pwd || (mkdir -p "$1" && cd "$1" && pwd))"
SESSION="${2:-forge-$(basename "$PROJECT_DIR")}"

if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "Sessão '$SESSION' já existe. Use: tmux attach -t $SESSION"
  exit 0
fi

# Paths
AGENTS_DIR="$PROJECT_DIR/.kiro/agents"
PROMPTS_DIR="$AGENTS_DIR/prompts"
SKILLS_DIR="$PROJECT_DIR/.kiro/skills"
TEMPLATE_DIR="$(cd "$(dirname "$0")" && pwd)"

# Copiar agents e prompts
mkdir -p "$PROMPTS_DIR"
for f in dev-forge.json tester-forge.json monitor-forge.json; do
  cp -f "$TEMPLATE_DIR/agents/$f" "$AGENTS_DIR/$f"
done
for f in dev-forge.md tester-forge.md monitor-forge.md; do
  cp -f "$TEMPLATE_DIR/prompts/$f" "$PROMPTS_DIR/$f"
done

# Copiar skills
if [ -d "$TEMPLATE_DIR/skills" ]; then
  for skill_dir in "$TEMPLATE_DIR/skills"/*/; do
    dir_name="$(basename "$skill_dir")"
    mkdir -p "$SKILLS_DIR/$dir_name"
    for skill_file in "$skill_dir"*.md; do
      [ -f "$skill_file" ] || continue
      file_name="$(basename "$skill_file")"
      cp -f "$skill_file" "$SKILLS_DIR/$dir_name/$file_name"
    done
  done
fi

# Substituir placeholders
sed -i "s|{{PROJECT_DIR}}|$PROJECT_DIR|g; s|{{SESSION}}|$SESSION|g" \
  "$PROMPTS_DIR"/dev-forge.md "$PROMPTS_DIR"/tester-forge.md "$PROMPTS_DIR"/monitor-forge.md

# Criar sessão tmux: tester (topo pequeno) | monitor (esquerda) | dev (direita)
tmux new-session -d -s "$SESSION" -c "$PROJECT_DIR"
tmux split-window -t "$SESSION:0" -v -c "$PROJECT_DIR"
tmux split-window -t "$SESSION:0.1" -h -c "$PROJECT_DIR"
tmux resize-pane -t "$SESSION:0.0" -y 5

# Títulos
tmux select-pane -t "$SESSION:0.0" -T "🧪 tester"
tmux select-pane -t "$SESSION:0.1" -T "👁 monitor"
tmux select-pane -t "$SESSION:0.2" -T "👷 dev"
tmux set -t "$SESSION" pane-border-format " #{pane_title} "
tmux set -t "$SESSION" pane-border-status top

# Hook: injeta lembrete de papel no fim de toda mensagem enviada ao monitor
send_to_monitor() {
  local msg="$1"
  local hook="

---
⚠️ REGRA DO SISTEMA: Você é o MONITOR. NÃO escreve código, NÃO cria/edita arquivos, NÃO executa comandos que alteram o projeto. Sua única ação permitida é: ler arquivos → montar briefing → enviar ao dev via tmux send-keys (pane $SESSION:0.2)."
  tmux send-keys -t "$SESSION:0.1" "" Enter
  sleep 0.5
  tmux send-keys -t "$SESSION:0.1" "" Enter
  sleep 0.5
  tmux send-keys -t "$SESSION:0.1" "${msg}${hook}" Enter
}

# Iniciar agents
sleep 0.5
tmux send-keys -t "$SESSION:0.0" "kiro-cli chat --trust-all-tools --agent tester-forge" Enter
sleep 0.5
tmux send-keys -t "$SESSION:0.1" "kiro-cli chat --trust-all-tools --agent monitor-forge" Enter
sleep 0.5
tmux send-keys -t "$SESSION:0.2" "kiro-cli chat --trust-all-tools --agent dev-forge" Enter

# Foco no monitor
tmux select-pane -t "$SESSION:0.1"

# Aguardar agents carregarem e enviar comando inicial pro monitor
sleep 8
send_to_monitor "Leia o prompt.md do projeto e comece a construir."

# Gerar script auxiliar para enviar mensagens ao monitor com o hook injetado
cat > "$PROJECT_DIR/send_to_monitor.sh" << SCRIPT
#!/usr/bin/env bash
# Uso: bash send_to_monitor.sh "sua mensagem aqui"
SESSION="$SESSION"
MSG="\$1"
HOOK="

---
⚠️ REGRA DO SISTEMA: Você é o MONITOR. NÃO escreve código, NÃO cria/edita arquivos, NÃO executa comandos que alteram o projeto. Sua única ação permitida é: ler arquivos → montar briefing → enviar ao dev via tmux send-keys (pane \$SESSION:0.2)."
tmux send-keys -t "\$SESSION:0.1" "" Enter
sleep 0.5
tmux send-keys -t "\$SESSION:0.1" "" Enter
sleep 0.5
tmux send-keys -t "\$SESSION:0.1" "\${MSG}\${HOOK}" Enter
SCRIPT
chmod +x "$PROJECT_DIR/send_to_monitor.sh"

echo "✅ Sessão '$SESSION' criada com 3 panes (tester | monitor | dev)"
echo "   tmux attach -t $SESSION   ← abre direto no monitor"
echo "   bash send_to_monitor.sh \"mensagem\"   ← envia ao monitor com hook"
