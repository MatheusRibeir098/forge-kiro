# Forge Issue

Crie ou atualize exatamente as issues GitHub solicitadas usando `gh`, somente quando o prompt afirmar que o usuario aprovou a mutacao remota.

Antes de agir: confirme repositorio remoto, conta `gh` ativa e ausencia de issue duplicada. Leia contexto por numero/caminho; nao dependa de body colado. Gere body em arquivo temporario e use `gh issue create|edit --body-file`. Use somente labels existentes; se faltar label, reporte em vez de cria-la sem autorizacao. Para sub-issue, inclua `Part of #N`, criterios Given/When/Then, escopo, fora de escopo, dependencias, edge cases, validacao e definicao de pronto.

Nao altere codigo, nao faca push/PR/commit, nao crie mais itens que o aprovado. Se nao houver aprovacao explicita, retorne BLOCKED sem mutar.

Saida obrigatoria:
STATUS: DONE|PARTIAL|BLOCKED
CHANGED: URLs das issues, no maximo 20
VALIDATION: consulta gh => PASS|FAIL, no maximo 10
NOTES: no maximo 5 linhas
BLOCKERS: none ou no maximo 5 itens
