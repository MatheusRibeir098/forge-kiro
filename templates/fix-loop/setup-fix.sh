#!/usr/bin/env bash
# Setup do loop dev→tester→monitor para qualquer projeto
# Uso: bash setup-fix.sh <diretorio-do-projeto> [nome-sessao]
set -euo pipefail

PROJECT_DIR="${1:?Uso: bash setup-fix.sh <diretorio-do-projeto> [nome-sessao]}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
SESSION="${2:-fix-$(basename "$PROJECT_DIR")}"

if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "Sessão '$SESSION' já existe. Use: tmux attach -t $SESSION"
  exit 0
fi

# Paths
AGENTS_DIR="$PROJECT_DIR/.kiro/agents"
PROMPTS_DIR="$AGENTS_DIR/prompts"
SKILLS_DIR="$PROJECT_DIR/.kiro/skills"
TEMPLATE_DIR="$(cd "$(dirname "$0")" && pwd)"

# Copiar agents e prompts se não existirem no projeto
mkdir -p "$PROMPTS_DIR"

for f in dev-fix.json tester-fix.json monitor-fix.json; do
  cp -f "$TEMPLATE_DIR/agents/$f" "$AGENTS_DIR/$f"
done
for f in dev-fix.md tester-fix.md monitor-fix.md; do
  cp -f "$TEMPLATE_DIR/prompts/$f" "$PROMPTS_DIR/$f"
done

# Copiar steering (sempre sobrescreve — regras do template têm precedência)
if [ -d "$TEMPLATE_DIR/steering" ]; then
  mkdir -p "$PROJECT_DIR/.kiro/steering"
  for f in "$TEMPLATE_DIR/steering"/*.md; do
    [ -f "$f" ] || continue
    cp -f "$f" "$PROJECT_DIR/.kiro/steering/$(basename "$f")"
  done
fi

# Copiar skills se não existirem no projeto
if [ -d "$TEMPLATE_DIR/skills" ]; then
  for skill_dir in "$TEMPLATE_DIR/skills"/*/; do
    dir_name="$(basename "$skill_dir")"
    mkdir -p "$SKILLS_DIR/$dir_name"
    for skill_file in "$skill_dir"*.md; do
      [ -f "$skill_file" ] || continue
      file_name="$(basename "$skill_file")"
      [ -f "$SKILLS_DIR/$dir_name/$file_name" ] || cp "$skill_file" "$SKILLS_DIR/$dir_name/$file_name"
    done
  done
fi

# Substituir placeholders nos prompts copiados
sed -i "s|{{PROJECT_DIR}}|$PROJECT_DIR|g; s|{{SESSION}}|$SESSION|g" "$PROMPTS_DIR"/dev-fix.md "$PROMPTS_DIR"/tester-fix.md "$PROMPTS_DIR"/monitor-fix.md

# Criar sessão: tester (topo pequeno) | monitor (esquerda) | dev (direita)
tmux new-session -d -s "$SESSION" -c "$PROJECT_DIR"
tmux split-window -t "$SESSION:0" -v -c "$PROJECT_DIR"
tmux split-window -t "$SESSION:0.1" -h -c "$PROJECT_DIR"

# Pane 0 = tester (topo, pequeno)
tmux resize-pane -t "$SESSION:0.0" -y 5

# Títulos nos panes
tmux select-pane -t "$SESSION:0.0" -T "🧪 tester"
tmux select-pane -t "$SESSION:0.1" -T "👁 monitor"
tmux select-pane -t "$SESSION:0.2" -T "👷 dev"
tmux set -t "$SESSION" pane-border-format " #{pane_title} "
tmux set -t "$SESSION" pane-border-status top

# Iniciar agents (por NOME, não por path)
sleep 0.5
tmux send-keys -t "$SESSION:0.0" "kiro-cli chat --trust-all-tools --agent tester-fix" Enter
sleep 0.5
tmux send-keys -t "$SESSION:0.1" "kiro-cli chat --trust-all-tools --agent monitor-fix" Enter
sleep 0.5
tmux send-keys -t "$SESSION:0.2" "kiro-cli chat --trust-all-tools --agent dev-fix" Enter

# Foco no monitor ao abrir
tmux select-pane -t "$SESSION:0.1"

echo "✅ Sessão '$SESSION' criada com 3 panes (tester | monitor | dev)"
echo "   tmux attach -t $SESSION   ← abre direto no monitor"
