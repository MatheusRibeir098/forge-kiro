---
name: quicksight-migration
description: Procedimento completo de migracao de dashboards Amazon QuickSight entre contas AWS: datasets, analyses, dashboards, templates cross-account, permissoes, temas e schedules SPICE. Use ao migrar ou replicar QuickSight entre contas.
---

# Skill: QuickSight Migration Agent

## Objetivo
Migrar dashboards completos entre contas AWS QuickSight, levando todo o "comboio" necessário para funcionar identicamente na conta destino.

## Gatilho
Quando o usuário disser algo como:
- "migrar dashboard X da conta Y para conta Z"
- "transferir dashboard para o Labs"
- "mover esse dashboard para outra conta"

## Primeira interação — SEMPRE perguntar

Antes de iniciar qualquer migração, o agente DEVE perguntar:

1. **Qual dashboard migrar?** (nome ou ID)
2. **Conta origem?** (perfil AWS CLI — ex: `dati_analytics_prd`, `dati_analytics_dev`)
3. **Conta destino?** (perfil AWS CLI — ex: `dati-labs`, `dati_analytics_prd`)

Se o usuário já informou na mensagem (ex: "migra o Billing - Priscila do PRD pro Labs"), extrair direto sem perguntar de novo.

### Como descobrir as contas disponíveis
Ler `~/.aws/config` para listar os perfis disponíveis e seus account IDs. Apresentar como opção se o usuário não souber.

```bash
cat ~/.aws/config | grep -E "^\[profile|sso_account_id|role_arn"
```

## Checklist obrigatório de migração

### Fase 1 — Descoberta (conta origem)

1. **Identificar o Dashboard**
   ```bash
   aws quicksight list-dashboards --aws-account-id <ORIGIN_ACCOUNT> --profile <ORIGIN_PROFILE> --region us-east-1
   aws quicksight describe-dashboard --aws-account-id <ORIGIN_ACCOUNT> --dashboard-id <ID> --profile <ORIGIN_PROFILE> --region us-east-1
   ```

2. **Identificar a Analysis fonte**
   - Extrair do CloudTrail ou do describe-dashboard o `SourceEntityArn`
   ```bash
   aws quicksight describe-analysis --aws-account-id <ORIGIN_ACCOUNT> --analysis-id <ID> --profile <ORIGIN_PROFILE> --region us-east-1
   ```
   - Anotar: nome, sheets, tema (ThemeArn), datasets usados

3. **Identificar Datasets**
   ```bash
   aws quicksight describe-data-set --aws-account-id <ORIGIN_ACCOUNT> --data-set-id <ID> --profile <ORIGIN_PROFILE> --region us-east-1
   ```
   - Anotar: nome, ImportMode (SPICE/DIRECT_QUERY), DataSourceArn, tabela/schema/catálogo
   - Se houver RLS (Row Level Security), anotar o dataset de RLS também

4. **Identificar DataSource**
   ```bash
   aws quicksight describe-data-source --aws-account-id <ORIGIN_ACCOUNT> --data-source-id <ID> --profile <ORIGIN_PROFILE> --region us-east-1
   ```
   - Anotar: tipo (ATHENA, S3, RDS, etc.), parâmetros de conexão (workgroup, catalog, schema)

5. **Identificar Permissões**
   ```bash
   aws quicksight describe-dashboard-permissions --aws-account-id <ORIGIN_ACCOUNT> --dashboard-id <ID> --profile <ORIGIN_PROFILE> --region us-east-1
   ```
   - Anotar todos os principals (usuários e grupos) e suas actions
   - Para grupos, verificar se existem na conta destino

6. **Identificar Schedule de Refresh**
   ```bash
   aws quicksight list-refresh-schedules --aws-account-id <ORIGIN_ACCOUNT> --data-set-id <ID> --profile <ORIGIN_PROFILE> --region us-east-1
   ```
   - Anotar: frequência (DAILY/WEEKLY/MONTHLY), horário, timezone, tipo (FULL/INCREMENTAL)

7. **Identificar Tema**
   - Se ThemeArn for `arn:aws:quicksight::aws:theme/CLASSIC` ou outro tema AWS → não precisa migrar
   - Se for tema custom → precisa exportar e recriar

### Fase 2 — Verificação da conta destino

1. **Verificar se o Dataset já existe no destino**
   ```bash
   aws quicksight list-data-sets --aws-account-id <DEST_ACCOUNT> --profile <DEST_PROFILE> --region us-east-1
   ```
   - Se já existe com mesmo nome → reutilizar (não duplicar!)

2. **Verificar se DataSource Athena existe**
   ```bash
   aws quicksight list-data-sources --aws-account-id <DEST_ACCOUNT> --profile <DEST_PROFILE> --region us-east-1
   ```
   - Se não existe → criar apontando para o catálogo/workgroup correto

3. **Verificar grupos necessários**
   ```bash
   aws quicksight list-groups --aws-account-id <DEST_ACCOUNT> --namespace default --profile <DEST_PROFILE> --region us-east-1
   ```
   - Mapear grupos da origem → grupos equivalentes no destino
   - Mapping conhecido:
     - `QS-Admin` (PRD) → `QS-Admin` (Labs)
     - `QS-Readers-Financeiro` (PRD) → `QS-Readers-Financeiro` (Labs)
     - `adm-financeiro-quick` existe no Labs para dashboards de billing

4. **Verificar usuários necessários**
   ```bash
   aws quicksight list-users --aws-account-id <DEST_ACCOUNT> --namespace default --profile <DEST_PROFILE> --region us-east-1
   ```
   - Confirmar que todos os usuários que tinham acesso na origem existem no destino

### Fase 3 — Execução da migração

1. **Criar DataSource (se necessário)**
   - Só criar se não existir um compatível no destino
   - O dataset deve continuar apontando para os DADOS na conta PRD (gold layer)

2. **Criar Dataset (se necessário)**
   - Só criar se não existir no destino
   - Manter mesma estrutura (colunas, tipos, ImportMode)
   - Apontar para o DataSource do destino

3. **Criar Template na origem (ponte de migração)**
   ```bash
   aws quicksight create-template --aws-account-id <ORIGIN_ACCOUNT> \
     --template-id <nome>-migration-template \
     --name "<Nome> Migration Template" \
     --source-entity '{"SourceAnalysis":{"Arn":"<ANALYSIS_ARN>","DataSetReferences":[{"DataSetPlaceholder":"<DATASET_NAME>","DataSetArn":"<DATASET_ARN>"}]}}' \
     --profile <ORIGIN_PROFILE> --region us-east-1
   ```

4. **Dar permissão cross-account no template**
   ```bash
   aws quicksight update-template-permissions --aws-account-id <ORIGIN_ACCOUNT> \
     --template-id <nome>-migration-template \
     --grant-permissions Principal=arn:aws:iam::<DEST_ACCOUNT>:root,Actions=quicksight:DescribeTemplate \
     --profile <ORIGIN_PROFILE> --region us-east-1
   ```

5. **Criar Analysis no destino**
   ```bash
   aws quicksight create-analysis --aws-account-id <DEST_ACCOUNT> \
     --analysis-id <nome>-analysis-labs \
     --name "<Nome da Analysis>" \
     --source-entity '{"SourceTemplate":{"Arn":"arn:aws:quicksight:us-east-1:<ORIGIN_ACCOUNT>:template/<template-id>","DataSetReferences":[{"DataSetPlaceholder":"<DATASET_NAME>","DataSetArn":"arn:aws:quicksight:us-east-1:<DEST_ACCOUNT>:dataset/<DEST_DATASET_ID>"}]}}' \
     --theme-arn "<THEME_ARN>" \
     --profile <DEST_PROFILE> --region us-east-1
   ```

6. **Criar Dashboard(s) no destino**
   ```bash
   aws quicksight create-dashboard --aws-account-id <DEST_ACCOUNT> \
     --dashboard-id <nome>-labs \
     --name "<Nome do Dashboard>" \
     --source-entity '{"SourceTemplate":{"Arn":"arn:aws:quicksight:us-east-1:<ORIGIN_ACCOUNT>:template/<template-id>","DataSetReferences":[{"DataSetPlaceholder":"<DATASET_NAME>","DataSetArn":"arn:aws:quicksight:us-east-1:<DEST_ACCOUNT>:dataset/<DEST_DATASET_ID>"}]}}' \
     --theme-arn "<THEME_ARN>" \
     --profile <DEST_PROFILE> --region us-east-1
   ```
   - Se a analysis tiver múltiplas sheets que viram dashboards separados, criar um dashboard para cada

7. **Configurar permissões**
   ```bash
   aws quicksight update-dashboard-permissions --aws-account-id <DEST_ACCOUNT> \
     --dashboard-id <ID> \
     --grant-permissions Principal=<ARN>,Actions=<ACTIONS> \
     --profile <DEST_PROFILE> --region us-east-1
   ```
   - Owners: todas as 8 actions (Describe, List, UpdatePermissions, Query, Update, Delete, DescribePermissions, UpdatePublishedVersion)
   - Readers: 3 actions (Describe, List, Query)

8. **Criar Schedule de refresh**
   ```bash
   aws quicksight create-refresh-schedule --aws-account-id <DEST_ACCOUNT> \
     --data-set-id <ID> \
     --schedule '{"ScheduleId":"<nome>","ScheduleFrequency":{"Interval":"<WEEKLY/DAILY>","RefreshOnDay":{"DayOfWeek":"<DAY>"},"Timezone":"America/Sao_Paulo","TimeOfTheDay":"<HH:MM>"},"RefreshType":"FULL_REFRESH","StartAfterDateTime":"<NEXT_DATE>"}' \
     --profile <DEST_PROFILE> --region us-east-1
   ```

### Fase 4 — Validação

1. **Verificar status dos dashboards criados**
   ```bash
   aws quicksight describe-dashboard --aws-account-id <DEST_ACCOUNT> --dashboard-id <ID> --profile <DEST_PROFILE> --region us-east-1
   ```
   - Status deve ser `CREATION_SUCCESSFUL`
   - `Errors` deve estar vazio

2. **Forçar SPICE refresh (se ImportMode = SPICE)**
   ```bash
   aws quicksight create-ingestion --aws-account-id <DEST_ACCOUNT> \
     --data-set-id <ID> \
     --ingestion-id manual-refresh-<DATA> \
     --profile <DEST_PROFILE> --region us-east-1
   ```

3. **Monitorar refresh até COMPLETED**
   ```bash
   aws quicksight describe-ingestion --aws-account-id <DEST_ACCOUNT> \
     --data-set-id <ID> \
     --ingestion-id <INGESTION_ID> \
     --profile <DEST_PROFILE> --region us-east-1
   ```
   - Confirmar: IngestionStatus = COMPLETED, RowsIngested > 0, RowsDropped = 0

4. **Dar permissão de visualização ao usuário solicitante**
   - Sempre garantir que o usuário que pediu a migração consiga visualizar no destino

5. **Fornecer links de acesso**
   - Formato: `https://us-east-1.quicksight.aws.amazon.com/sn/dashboards/<DASHBOARD_ID>`

### Fase 5 — Atualizar planilha de triagem (se existir)

Se houver planilha de saneamento associada:
- Mover dashboard da seção "⚠️ Verificar" para "✅ Migrado para LABS"
- Atualizar observação com data da migração

## Regras de ouro

- **NUNCA duplicar** dataset/datasource se já existe no destino — reutilizar
- **SEMPRE verificar** se o tema é padrão AWS (não precisa migrar) ou custom
- **SEMPRE replicar** permissões — mapear usuários/grupos entre contas
- **SEMPRE criar** schedule de refresh se existia na origem
- **SEMPRE validar** que o dashboard foi criado sem erros
- **SEMPRE forçar** um refresh manual para ter dados imediatamente
- **SEMPRE monitorar** o refresh até COMPLETED
- O dataset no Labs deve **continuar lendo da gold no PRD** (cross-account via Athena)

## Informações de referência

### Como descobrir DataSources de uma conta
```bash
aws quicksight list-data-sources --aws-account-id <ACCOUNT_ID> --profile <PROFILE> --region us-east-1
```
O agente deve identificar automaticamente qual datasource Athena usar no destino. Se não existir, criar um.

### Service Account Google Sheets (planilha de triagem)
- Email: `kiro-cli-editor@dati-data-platform.iam.gserviceaccount.com`
- Credencial: `/home/math3us/forge/.google-sa.json`
- Planilha saneamento: verificar com o usuário se há planilha a atualizar
