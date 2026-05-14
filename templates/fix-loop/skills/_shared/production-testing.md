# Skill: Production Testing — Testes que Realmente Importam

## Lição aprendida (CertArena)

Testes locais passando ≠ produção funcionando. Os seguintes problemas só aparecem no deploy real e **não são cobertos por TDD ou Supertest local**:

- CORS bloqueando preflight OPTIONS
- ZIP do Lambda com estrutura errada (pasta wrapper)
- Variáveis de ambiente ausentes no Lambda
- Rotas dinâmicas (Next.js `/[id]`) sem SSR no S3 estático
- Usuários Cognito criados pelo site ficam `UNCONFIRMED`
- `uuid` v10+ usa ESM, incompatível com Lambda CommonJS
- `BASE_URL` sem `/api` prefix causando 404

---

## Checklist obrigatório ANTES de declarar tarefa concluída

### 1. Testes de API com autenticação REAL

Nunca usar apenas `NODE_ENV=test` (bypassa Cognito). Sempre testar com token real:

```bash
# Obter token real do Cognito
TOKEN=$(aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id $CLIENT_ID \
  --auth-parameters USERNAME=$EMAIL,PASSWORD=$PASS \
  --region us-east-1 \
  --query "AuthenticationResult.AccessToken" --output text)

# Testar rota protegida com token real
curl -s -X POST "$API_URL/api/exams" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"cert":"CLF-C02","mode":"custom","questionCount":10,"lang":"pt","feedbackMode":"final"}'
```

### 2. Teste de CORS (preflight OPTIONS)

```bash
# Deve retornar 200, não 500
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X OPTIONS "$API_URL/api/exams" \
  -H "Origin: $FRONTEND_URL" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: authorization,content-type")

[ "$STATUS" = "200" ] && echo "✅ CORS OK" || echo "❌ CORS FALHOU: $STATUS"
```

### 3. Verificar estrutura do ZIP do Lambda

```bash
# index.js deve estar na RAIZ do zip, não dentro de pasta
unzip -l lambda.zip | grep "index.js" | grep -v node_modules
# Correto:   427  2026-01-01   index.js
# Errado:    427  2026-01-01   lambda-pkg/./index.js
```

### 4. Verificar variáveis de ambiente do Lambda

```bash
aws lambda get-function-configuration \
  --function-name $FUNCTION_NAME \
  --query "Environment.Variables" --output json
# Verificar: COGNITO_USER_POOL_ID, COGNITO_CLIENT_ID, tabelas DynamoDB
```

### 5. Testar rotas dinâmicas no frontend deployado

```bash
# Rotas como /exam/UUID devem retornar 200, não 403/404
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$FRONTEND_URL/exam/test-uuid-123")
[ "$STATUS" = "200" ] && echo "✅ Rota dinâmica OK" || echo "❌ Rota dinâmica FALHOU: $STATUS"
```

### 6. Verificar banco populado antes de testar fluxo

```bash
# Nunca testar simulado com banco vazio
COUNT=$(aws dynamodb scan --table-name $QUESTIONS_TABLE --select COUNT \
  --query "Count" --output text)
[ "$COUNT" -gt "0" ] && echo "✅ $COUNT questões no banco" || echo "❌ Banco vazio — rode o seed"
```

### 7. Verificar usuários Cognito após cadastro pelo site

```bash
# Usuários criados pelo site ficam UNCONFIRMED — confirmar manualmente
aws cognito-idp list-users \
  --user-pool-id $USER_POOL_ID \
  --query "Users[?UserStatus=='UNCONFIRMED'].{Username:Username,Email:Attributes[?Name=='email'].Value|[0]}" \
  --output table

# Confirmar usuário
aws cognito-idp admin-confirm-sign-up \
  --user-pool-id $USER_POOL_ID \
  --username $USERNAME
```

---

## E2E Playwright contra produção — fluxo obrigatório

O E2E deve testar o fluxo COMPLETO até a funcionalidade principal funcionar:

```ts
test('fluxo completo — login → simulado → questão aparece', async ({ page }) => {
  // 1. Login real
  await page.goto(`${BASE_URL}/login`);
  await page.fill('[name=email]', EMAIL);
  await page.fill('[name=password]', PASSWORD);
  await page.screenshot({ path: 'screenshots/01-login.png' });
  await page.click('button[type=submit]');
  await page.waitForURL('**/dashboard**');
  await page.screenshot({ path: 'screenshots/02-dashboard.png' });

  // 2. Configurar simulado
  await page.click('text=Iniciar Simulado');
  await page.waitForURL('**/exam**');
  await page.screenshot({ path: 'screenshots/03-exam-config.png' });

  // 3. Iniciar e verificar que chegou na questão (NÃO voltou para dashboard)
  await page.click('text=Iniciar Simulado');
  await page.waitForURL('**/exam/**', { timeout: 10000 }); // UUID na URL
  await page.screenshot({ path: 'screenshots/04-questao.png' });

  // 4. Verificar que há texto de questão na tela
  const questionText = await page.locator('[data-testid=question-text]').textContent();
  expect(questionText?.length).toBeGreaterThan(10);
});
```

**Critério de sucesso:** a URL deve mudar para `/exam/UUID` e uma questão deve aparecer. Se voltar para `/dashboard`, o teste FALHOU.

---

## Regras para o tester

1. **NUNCA declarar sucesso sem testar o fluxo principal de ponta a ponta**
2. **SEMPRE testar CORS com curl antes de declarar API OK**
3. **SEMPRE verificar estrutura do ZIP antes de declarar Lambda OK**
4. **SEMPRE verificar banco populado antes de testar fluxo de simulado**
5. **E2E deve chegar na funcionalidade principal** — não basta login e dashboard
