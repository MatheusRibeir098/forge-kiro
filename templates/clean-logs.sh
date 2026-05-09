#!/bin/bash
# clean-logs.sh — Limpa logs raw dos panes (remove ANSI, spinners, header do kiro)
LOGDIR="$(dirname "$0")/orchestration/logs"
CLEANDIR="$LOGDIR/clean"
mkdir -p "$CLEANDIR"

for f in "$LOGDIR"/pane-*.log; do
  name=$(basename "$f")
  cat "$f" \
    | sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g' \
    | sed 's/\x1b[()>=]//g; s/\x1b[kM\\]//g; s/\x08//g' \
    | sed 's/\x1b\][^\x07]*\x07//g' \
    | sed 's/\x1b\][^\x1b]*\x1b\\//g' \
    | tr -d '\r' \
    | sed '/⠋\|⠙\|⠹\|⠸\|⠼\|⠴\|⠦\|⠧\|⠇\|⠏/s/[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏] Thinking\.\.\.//g' \
    | sed -n '/!>/,$p' \
    | grep -v '^\s*$' \
    > "$CLEANDIR/$name"
  lines=$(wc -l < "$CLEANDIR/$name")
  echo "  $name → $lines linhas"
done
echo "Logs limpos em $CLEANDIR/"
