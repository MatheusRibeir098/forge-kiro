# Guia: Lambda AWS — Problemas Comuns e Soluções

Lições aprendidas no projeto `dati-data-platform` (NPS). Aplicável a qualquer Lambda Python na AWS.

---

## 1. Limite de 250MB em Layers + Código

### Problema
```
Layers consume more than the available size of 262144000 bytes.
The actual size is 281264678 bytes.
```
O limite da AWS é **262MB descomprimido** para código + layers combinados.
O `AWSSDKPandas-Python314` layer sozinho tem ~280MB descomprimido — já ultrapassa o limite.

### Diagnóstico
Antes de escolher layers, verifique o tamanho descomprimido:
```bash
# Verificar tamanho de um layer
aws lambda get-layer-version-by-arn \
  --arn "arn:aws:lambda:us-east-1:336392948345:layer:AWSSDKPandas-Python314:2" \
  --query "Content.CodeSize"
```

### Soluções

**Opção A — Não usar pandas/pyarrow na Lambda**
Se a Lambda só precisa ler dados e salvar no S3, use CSV em vez de Parquet:
```python
# Em vez de pandas + pyarrow, use apenas stdlib
import csv, io, boto3

buf = io.StringIO()
writer = csv.DictWriter(buf, fieldnames=list(rows[0].keys()))
writer.writeheader()
writer.writerows(rows)
s3.put_object(Bucket=bucket, Key=key, Body=buf.getvalue().encode("utf-8"))
```
O Glue lê CSV normalmente com `spark.read.format("csv").option("header","true")`.

**Opção B — Bundlar dependências no pacote da Lambda (sem layer)**
Para dependências leves (< 50MB), inclua direto no pacote:
```python
# app.py — instalar deps no diretório da Lambda
deps_path = Path("src/domains/meu-dominio/lambda/vendor")
if not deps_path.exists():
    deps_path.mkdir(parents=True, exist_ok=True)
    subprocess.run(["pip", "install", "minha-lib", "--target", str(deps_path), "--quiet"], check=True)
```
```python
# No código da Lambda — adicionar vendor ao path
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'vendor'))
```

**Opção C — Criar um Lambda Layer dedicado (padrão do projeto — RECOMENDADO)**
Seguindo o mesmo padrão do `billing_aws` com o `pypdf`. As deps ficam em um layer separado, o código da Lambda fica limpo, e nada é commitado no repositório:
```python
# app.py — instalar deps na pasta do layer
layer_path = Path("src/domains/meu-dominio/layers/minha-lib/python")
if not layer_path.exists():
    layer_path.mkdir(parents=True, exist_ok=True)
    subprocess.run(["pip", "install", "minha-lib", "--target", str(layer_path), "--quiet"], check=True)
```
```python
# nps_stack.py — criar o layer e associar à Lambda
google_auth_layer = _lambda.LayerVersion(
    self,
    "GoogleAuthLayer",
    code=_lambda.Code.from_asset("src/domains/nps/layers/google-auth"),
    compatible_runtimes=[_lambda.Runtime.PYTHON_3_14],
    description="Layer com rsa + pyasn1 para autenticação JWT RS256",
)

lambda_common = dict(
    ...
    layers=[google_auth_layer],  # layer dedicado, sem AWSSDKPandas
    code=_lambda.Code.from_asset(
        "src/domains/nps/lambda",
        exclude=["__pycache__", "**/__pycache__", "*.pyc", "vendor", "vendor/*"],
    ),
)
```
```gitignore
# .gitignore — layers geradas automaticamente, não commitar
src/domains/nps/layers/
```
Vantagens sobre a Opção B:
- Código da Lambda fica limpo — sem `sys.path.insert`
- Nada de vendor commitado no repositório
- Padrão consistente com outros domínios do projeto

---

## 2. Binários `.so` não portáveis entre versões Python

### Problema
```
Unable to import module: No module named '_cffi_backend'
Unable to import module: No module named 'cryptography'
```
Bibliotecas com extensões C (`.so`) compiladas para Python 3.12 **não funcionam** no runtime Python 3.14 da Lambda. O pip instala a versão compilada para a versão Python da sua máquina.

### Diagnóstico
```bash
# Verificar se há binários .so no vendor
find src/domains/meu-dominio/lambda/vendor -name "*.so" | wc -l
# Se > 0, há risco de incompatibilidade
```

### Solução
Use apenas bibliotecas **pure Python** (sem extensões C). Para autenticação Google:

**❌ Não usar:**
- `cryptography` (tem `_rust.abi3.so`)
- `cffi` (tem `_cffi_backend.so`)
- `charset-normalizer` (tem `.so` opcionais)

**✅ Usar:**
- `rsa` — pure Python, assina JWT RS256
- `pyasn1` — pure Python, parseia chaves PKCS8
- `pyasn1_modules` — pure Python

### Implementação JWT RS256 sem cryptography

Para autenticar com Google Service Account sem nenhum binário — usando `rsa` + `pyasn1` via Lambda Layer (padrão do projeto):

```python
# sheets_client.py — sem sys.path.insert, deps vêm do layer
import base64, json, re, time, urllib.request, urllib.parse
import boto3, rsa
from pyasn1.codec.der import decoder as asn1_decoder

def _load_private_key(pem: str) -> rsa.PrivateKey:
    """Carrega chave PKCS8 PEM (formato Google Service Account)."""
    der_b64 = re.sub(r"-----[^-]+-----|\s", "", pem)
    pkcs8_der = base64.b64decode(der_b64)
    pkcs8_seq, _ = asn1_decoder.decode(pkcs8_der)
    return rsa.PrivateKey._load_pkcs1_der(bytes(pkcs8_seq[2]))

def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()

def get_google_access_token(client_email: str, private_key_pem: str, scopes: str) -> str:
    TOKEN_URL = "https://oauth2.googleapis.com/token"
    now = int(time.time())
    header = _b64url(json.dumps({"alg": "RS256", "typ": "JWT"}).encode())
    payload = _b64url(json.dumps({
        "iss": client_email, "scope": scopes,
        "aud": TOKEN_URL, "iat": now, "exp": now + 3600,
    }).encode())
    signing_input = f"{header}.{payload}".encode()
    private_key = _load_private_key(private_key_pem)
    signature = rsa.sign(signing_input, private_key, "SHA-256")
    jwt = f"{header}.{payload}.{_b64url(signature)}"
    body = urllib.parse.urlencode({
        "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
        "assertion": jwt,
    }).encode()
    req = urllib.request.Request(TOKEN_URL, data=body, method="POST")
    req.add_header("Content-Type", "application/x-www-form-urlencoded")
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())["access_token"]
```

**Instalar no vendor:**
```bash
pip install rsa pyasn1 pyasn1-modules --no-deps --target src/domains/meu-dominio/lambda/vendor/
# Resultado: ~3.7MB, zero binários .so
```

---

## 3. Glue Job lendo formato errado

### Problema
```
is not a Parquet file. Expected magic number at tail, but found [48, 48, 13, 10]
```
O script Glue usa `spark.read.format("parquet")` mas os arquivos são CSV.

### Solução
```python
# Para CSV
df = (
    spark.read.format("csv")
    .option("header", "true")
    .option("recursiveFileLookup", "true")
    .option("multiLine", "true")
    .option("escape", '"')
    .load(valid_paths)
)

# Para Parquet (padrão)
df = (
    spark.read.format("parquet")
    .option("recursiveFileLookup", "true")
    .option("mergeSchema", "true")
    .load(valid_paths)
)
```

---

## 4. Nome de campo errado no ClickUp Silver

### Problema
```
AnalysisException: A column with name `t`.`status` cannot be resolved.
Did you mean: `t`.`status_status`?
```
O campo `status` na `silver_tasks` do ClickUp se chama `status_status` (vem do campo aninhado `status.status` da API).

### Solução
```python
# ❌ Errado
F.col("t.status")

# ✅ Correto
F.col("t.status_status").alias("status")

# No filtro SQL
WHERE t.status_status IN ('closed', 'complete')
```

---

## 5. CAST duplo de TIMESTAMP

### Problema
```
Cannot resolve "CAST(date_closed AS BIGINT)": cannot cast "TIMESTAMP_NTZ" to "BIGINT"
```
O campo já foi convertido de ms epoch para TIMESTAMP em uma camada anterior (Silver). Tentar fazer CAST novamente falha.

### Diagnóstico
Verificar o tipo real do campo antes de fazer CAST:
```python
df.printSchema()  # ou
spark.sql("DESCRIBE TABLE catalog.database.tabela").show()
```

### Solução
Se o campo já é TIMESTAMP, use diretamente:
```sql
-- ❌ Errado (quando já é TIMESTAMP)
CAST(CAST(date_closed AS BIGINT) / 1000 AS TIMESTAMP)

-- ✅ Correto
date_closed

-- Para filtro de data
WHERE date_closed >= CAST('2026-04-01' AS DATE)
```

Se o campo ainda é string ms epoch (ex: vindo direto do ClickUp Raw/Bronze):
```sql
-- ✅ Converter ms epoch string para TIMESTAMP
CAST(CAST(date_closed AS BIGINT) / 1000 AS TIMESTAMP)
```

---

## 6. CDK usando asset em cache após mudança de código

### Problema
O CDK continua deployando o asset antigo mesmo após alterar o código.

### Solução
Limpar o cache do CDK antes do deploy:
```bash
rm -rf cdk.out
cdk deploy ...
```

---

## 7. S3 Table Bucket em estado de transição

### Problema
```
The bucket is in a transitional state because of a previous deletion attempt. Try again later.
```
Ocorre quando um deploy falhou com rollback e o S3 Table Bucket ainda está sendo deletado.

### Solução
Aguardar alguns minutos e tentar novamente. Verificar se o bucket foi deletado:
```bash
aws s3tables get-table-bucket \
  --table-bucket-arn "arn:aws:s3tables:REGION:ACCOUNT:bucket/NOME" \
  --profile SEU_PROFILE --region REGION
# Se retornar NotFoundException, está pronto para recriar
```

---

## Checklist antes de deployar uma Lambda

- [ ] Verificar tamanho descomprimido de todos os layers (`aws lambda get-layer-version-by-arn`)
- [ ] Verificar se há binários `.so` no layer/vendor (`find layers -name "*.so"`)
- [ ] Usar Lambda Layer dedicado para deps externas (padrão do projeto — ver Opção C acima)
- [ ] Adicionar `src/domains/*/layers/` ao `.gitignore`
- [ ] Testar imports localmente com a mesma versão Python do runtime
- [ ] Confirmar formato dos arquivos no S3 Raw (CSV vs Parquet)
- [ ] Verificar nomes reais dos campos nas tabelas Silver/Gold antes de referenciar
- [ ] Limpar `cdk.out` se houve mudanças no código da Lambda
