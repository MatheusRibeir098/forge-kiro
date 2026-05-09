# Skill: E2E com Playwright

## Setup de servidores para teste

SEMPRE use tmux sessions separadas para servidores. NUNCA `&`, `nohup` ou background jobs.

```bash
# Subir backend
tmux new-session -d -s servers -c "<projeto>/backend"
tmux send-keys -t servers "pnpm dev" Enter

# Subir frontend no mesmo session, novo pane
tmux split-window -t servers -h -c "<projeto>/frontend"
tmux send-keys -t servers:0.1 "pnpm dev" Enter

# Aguardar servidores ficarem prontos
sleep 5
curl -s http://localhost:3001/api/subjects > /dev/null && echo "Backend OK"
curl -s http://localhost:5173 > /dev/null && echo "Frontend OK"
```

## Executar testes E2E

```bash
cd <projeto>/e2e
npx playwright test <arquivo-de-teste>.spec.ts --headed
```

Se não existir teste específico, criar um inline:
```bash
cd <projeto>/e2e
cat > test-fix.spec.ts << 'EOF'
import { test, expect } from '@playwright/test';
test('descrição do teste', async ({ page }) => {
  await page.goto('http://localhost:5173');
  // assertions específicas do bug corrigido
});
EOF
npx playwright test test-fix.spec.ts
```

## Derrubar servidores após teste

```bash
tmux kill-session -t servers
```

NUNCA use `tmux kill-server` — mata TODAS as sessions incluindo dev/monitor/tester.

## Boas práticas

- Aguarde elementos com `await page.waitForSelector()` antes de interagir
- Use `page.waitForResponse()` para aguardar chamadas de API
- Screenshots em caso de falha: `await page.screenshot({ path: 'fail.png' })`
- Timeout padrão: 30s. Se precisar mais, use `test.setTimeout(60000)`
- Teste em viewport desktop (1280x720) e mobile (375x667) se relevante
