---
name: quicksight-dashboard-builder
description: Construcao programatica de dashboards QuickSight via AWS CLI: datasets, analyses, visuais, layout e temas sem usar o console. Use ao criar ou editar dashboard, analysis ou dataset QuickSight.
---

# Skill: QuickSight Dashboard Builder via CLI

## Conhecimento consolidado de criação de Datasets, Analyses e Dashboards via AWS CLI

---

## 1. DATASETS — Criação via CLI

### Padrão correto para S3 Tables (Iceberg)

**SEMPRE usar `RelationalTable`** (não `CustomSql`) quando acessar tabelas via S3 Tables catalog:

```json
{
  "AwsAccountId": "ACCOUNT_ID",
  "DataSetId": "meu-dataset-id",
  "Name": "Meu Dataset",
  "PhysicalTableMap": {
    "t1": {
      "RelationalTable": {
        "DataSourceArn": "arn:aws:quicksight:REGION:ACCOUNT:datasource/DATASOURCE_ID",
        "Catalog": "s3tablescatalog/NOME-DO-TABLE-BUCKET",
        "Schema": "NAMESPACE_NAME",
        "Name": "TABLE_NAME",
        "InputColumns": [
          {"Name": "coluna", "Type": "STRING|INTEGER|DECIMAL|DATETIME|BOOLEAN"}
        ]
      }
    }
  },
  "ImportMode": "DIRECT_QUERY",
  "Permissions": [...]
}
```

### ⛔ ERROS COMUNS — NÃO FAÇA:

1. **CustomSql com S3 Tables** — Dá SQL exception porque o QuickSight não resolve o catálogo corretamente via custom SQL. Sempre use `RelationalTable` com `Catalog` + `Schema` + `Name`.

2. **Nome errado do catálogo** — O formato correto é:
   - `Catalog`: `s3tablescatalog/nome-do-table-bucket` (com barra, não ponto)
   - `Schema`: nome do namespace (ex: `kiro_metrics_gold_dev`)
   - `Name`: nome da tabela (ex: `gold_kiro_usage`)

3. **Data Source sem RoleArn** — Para acessar S3 Tables, o data source Athena PRECISA ter `RoleArn` configurado. Verifique com:
   ```bash
   aws quicksight describe-data-source --aws-account-id ACCOUNT --data-source-id ID --query "DataSource.DataSourceParameters"
   ```
   Se não tiver `RoleArn`, use outro data source que tenha, ou crie um novo.

4. **Tipos de coluna** — Usar os tipos do QuickSight:
   - `STRING` — para textos e datas em formato string
   - `INTEGER` — para bigint/int
   - `DECIMAL` — para double/float
   - `DATETIME` — APENAS se a coluna for realmente timestamp
   - `BOOLEAN` — para boolean
   - `BIT` — alternativa para boolean

### ✅ Comando de criação:
```bash
aws quicksight create-data-set --cli-input-json file://dataset.json --profile PROFILE --region REGION
```

### ✅ Comando de atualização (mesmo JSON, muda o comando):
```bash
aws quicksight update-data-set --cli-input-json file://dataset.json --profile PROFILE --region REGION
```

### Permissions padrão para dataset:
```json
"Permissions": [{
  "Principal": "arn:aws:quicksight:REGION:ACCOUNT:user/default/ROLE/email@dominio.com",
  "Actions": [
    "quicksight:DescribeDataSet",
    "quicksight:DescribeDataSetPermissions",
    "quicksight:PassDataSet",
    "quicksight:DescribeIngestion",
    "quicksight:ListIngestions",
    "quicksight:UpdateDataSet",
    "quicksight:DeleteDataSet",
    "quicksight:CreateIngestion",
    "quicksight:CancelIngestion",
    "quicksight:UpdateDataSetPermissions"
  ]
}]
```

---

## 2. PERMISSÕES — Lake Formation + IAM para S3 Tables

### Checklist OBRIGATÓRIO antes de criar datasets:

1. **IAM Policy na role do QuickSight** (`aws-quicksight-service-role-v0`):
   ```json
   {
     "Statement": [
       {
         "Action": ["s3tables:GetNamespace","s3tables:GetTable","s3tables:GetTableBucket","s3tables:GetTableData","s3tables:GetTableMetadataLocation","s3tables:ListNamespaces","s3tables:ListTables"],
         "Resource": ["arn:aws:s3tables:REGION:ACCOUNT:bucket/TABLE-BUCKET-NAME", "arn:aws:s3tables:REGION:ACCOUNT:bucket/TABLE-BUCKET-NAME/*"],
         "Effect": "Allow"
       },
       {
         "Action": ["glue:GetCatalog","glue:GetDatabase","glue:GetDatabases","glue:GetTable","glue:GetTables"],
         "Resource": [
           "arn:aws:glue:REGION:ACCOUNT:catalog",
           "arn:aws:glue:REGION:ACCOUNT:catalog/s3tablescatalog",
           "arn:aws:glue:REGION:ACCOUNT:catalog/s3tablescatalog/TABLE-BUCKET-NAME",
           "arn:aws:glue:REGION:ACCOUNT:database/*",
           "arn:aws:glue:REGION:ACCOUNT:table/*/*"
         ],
         "Effect": "Allow"
       },
       {
         "Action": "lakeformation:GetDataAccess",
         "Resource": "*",
         "Effect": "Allow"
       }
     ]
   }
   ```

2. **Lake Formation Grants** (para service role E user role):
   ```bash
   # Catalog level
   aws lakeformation grant-permissions \
     --principal DataLakePrincipalIdentifier=arn:aws:iam::ACCOUNT:role/service-role/aws-quicksight-service-role-v0 \
     --resource '{"Catalog":{"Id":"ACCOUNT:s3tablescatalog/TABLE-BUCKET"}}' \
     --permissions ALL

   # Database level
   aws lakeformation grant-permissions \
     --principal DataLakePrincipalIdentifier=arn:aws:iam::ACCOUNT:role/service-role/aws-quicksight-service-role-v0 \
     --resource '{"Database":{"CatalogId":"ACCOUNT:s3tablescatalog/TABLE-BUCKET","Name":"NAMESPACE"}}' \
     --permissions DESCRIBE

   # Table level (wildcard)
   aws lakeformation grant-permissions \
     --principal DataLakePrincipalIdentifier=arn:aws:iam::ACCOUNT:role/service-role/aws-quicksight-service-role-v0 \
     --resource '{"Table":{"CatalogId":"ACCOUNT:s3tablescatalog/TABLE-BUCKET","DatabaseName":"NAMESPACE","TableWildcard":{}}}' \
     --permissions SELECT DESCRIBE
   ```

3. **Repetir Lake Formation grants para a role do usuário** (ex: `Dati-acc-access`).

### Como diagnosticar "SQL Exception":
1. Testar a query equivalente no Athena CLI
2. Se Athena funciona mas QuickSight não → problema de permissão da role
3. Se Athena também falha → problema de nome de catálogo/namespace/tabela

---

## 3. ANALYSIS — Criação via Definition JSON

### Estrutura mínima:
```json
{
  "AwsAccountId": "ACCOUNT",
  "AnalysisId": "meu-analysis-id",
  "Name": "Meu Dashboard",
  "ThemeArn": "arn:aws:quicksight:REGION:ACCOUNT:theme/THEME-ID",
  "Permissions": [...],
  "Definition": {
    "DataSetIdentifierDeclarations": [...],
    "FilterGroups": [...],
    "Sheets": [...],
    "AnalysisDefaults": {...}
  }
}
```

### DataSetIdentifierDeclarations:
```json
{"Identifier": "nome_referencia", "DataSetArn": "arn:aws:quicksight:REGION:ACCOUNT:dataset/DATASET-ID"}
```
O `Identifier` é usado nos visuais para referenciar qual dataset.

### FilterGroups — Regras:
- **Scope único por sheet** — Se um filtro se aplica a mais de 1 sheet, precisa de `DefaultFilterControlConfiguration` OU criar filtros separados por sheet
- **Solução simples**: scope cada FilterGroup para 1 sheet só
- FilterId deve ser único
- `CrossDataset: "ALL_DATASETS"` para filtros que afetam todos os datasets

### FilterControls:
```json
{"Dropdown": {"FilterControlId": "ctrl-id", "Title": "Label", "SourceFilterId": "filter-id", "Type": "MULTI_SELECT"}}
```
- Para datas STRING: usar `Dropdown` (não `DateTimePicker`)
- `DateTimePicker` só funciona com colunas tipo DATETIME

### Visuais — Tipos e estrutura:

#### KPIVisual:
```json
{"KPIVisual": {
  "VisualId": "unique-id",
  "Title": {"Visibility": "VISIBLE", "FormatText": {"RichText": "<visual-title>Título</visual-title>"}},
  "Subtitle": {"Visibility": "VISIBLE"},
  "ChartConfiguration": {
    "FieldWells": {
      "Values": [{"NumericalMeasureField": {"FieldId": "f1", "Column": {"DataSetIdentifier": "ref", "ColumnName": "col"}, "AggregationFunction": {"SimpleNumericalAggregation": "SUM|AVERAGE|COUNT"}}}],
      "TargetValues": [],
      "TrendGroups": []
    },
    "SortConfiguration": {},
    "KPIOptions": {
      "PrimaryValueDisplayType": "ACTUAL",
      "PrimaryValueFontConfiguration": {"FontSize": {"Relative": "EXTRA_LARGE"}, "FontColor": "#FFFFFF"},
      "Sparkline": {"Visibility": "VISIBLE", "Type": "AREA"},
      "VisualLayoutOptions": {"StandardLayout": {"Type": "VERTICAL"}}
    }
  },
  "Actions": [],
  "ColumnHierarchies": []
}}
```

#### LineChartVisual:
```json
{"LineChartVisual": {
  "VisualId": "unique-id",
  "Title": {"Visibility": "VISIBLE", "FormatText": {"RichText": "<visual-title>Título</visual-title>"}},
  "Subtitle": {"Visibility": "VISIBLE"},
  "ChartConfiguration": {
    "FieldWells": {"LineChartAggregatedFieldWells": {
      "Category": [{"CategoricalDimensionField": {"FieldId": "f-cat", "Column": {"DataSetIdentifier": "ref", "ColumnName": "date"}}}],
      "Values": [{"NumericalMeasureField": {"FieldId": "f-val", "Column": {"DataSetIdentifier": "ref", "ColumnName": "col"}, "AggregationFunction": {"SimpleNumericalAggregation": "SUM"}}}],
      "SmallMultiples": []
    }},
    "SortConfiguration": {"CategorySort": [{"FieldSort": {"FieldId": "f-cat", "Direction": "ASC"}}]}
  },
  "Actions": [],
  "ColumnHierarchies": []
}}
```

#### BarChartVisual:
```json
{"BarChartVisual": {
  "VisualId": "unique-id",
  "Title": {"Visibility": "VISIBLE", "FormatText": {"RichText": "<visual-title>Título</visual-title>"}},
  "Subtitle": {"Visibility": "VISIBLE"},
  "ChartConfiguration": {
    "FieldWells": {"BarChartAggregatedFieldWells": {
      "Category": [{"CategoricalDimensionField": {"FieldId": "f-cat", "Column": {"DataSetIdentifier": "ref", "ColumnName": "col"}}}],
      "Values": [{"NumericalMeasureField": {"FieldId": "f-val", "Column": {"DataSetIdentifier": "ref", "ColumnName": "col"}, "AggregationFunction": {"SimpleNumericalAggregation": "SUM"}}}],
      "SmallMultiples": []
    }},
    "SortConfiguration": {"CategorySort": [{"FieldSort": {"FieldId": "f-val", "Direction": "DESC"}}]},
    "Orientation": "HORIZONTAL|VERTICAL",
    "BarsArrangement": "CLUSTERED|STACKED"
  },
  "Actions": [],
  "ColumnHierarchies": []
}}
```

#### PieChartVisual:
```json
{"PieChartVisual": {
  "VisualId": "unique-id",
  "Title": {"Visibility": "VISIBLE", "FormatText": {"RichText": "<visual-title>Título</visual-title>"}},
  "Subtitle": {"Visibility": "VISIBLE"},
  "ChartConfiguration": {
    "FieldWells": {"PieChartAggregatedFieldWells": {
      "Category": [{"CategoricalDimensionField": {"FieldId": "f-cat", "Column": {"DataSetIdentifier": "ref", "ColumnName": "col"}}}],
      "Values": [{"NumericalMeasureField": {"FieldId": "f-val", "Column": {"DataSetIdentifier": "ref", "ColumnName": "col"}, "AggregationFunction": {"SimpleNumericalAggregation": "SUM"}}}],
      "SmallMultiples": []
    }},
    "SortConfiguration": {}
  },
  "Actions": [],
  "ColumnHierarchies": []
}}
```

#### TableVisual:
```json
{"TableVisual": {
  "VisualId": "unique-id",
  "Title": {"Visibility": "VISIBLE", "FormatText": {"RichText": "<visual-title>Título</visual-title>"}},
  "Subtitle": {"Visibility": "VISIBLE"},
  "ChartConfiguration": {
    "FieldWells": {"TableAggregatedFieldWells": {
      "GroupBy": [{"CategoricalDimensionField": {"FieldId": "f1", "Column": {"DataSetIdentifier": "ref", "ColumnName": "col"}}}],
      "Values": [{"NumericalMeasureField": {"FieldId": "f2", "Column": {"DataSetIdentifier": "ref", "ColumnName": "col"}, "AggregationFunction": {"SimpleNumericalAggregation": "SUM"}}}]
    }},
    "SortConfiguration": {}
  },
  "Actions": []
}}
```
⚠️ TableVisual **NÃO tem** `ColumnHierarchies`.

---

## 4. LAYOUT — Grid System

### Grid de 36 colunas (padrão QuickSight):
```json
"Layouts": [{"Configuration": {"GridLayout": {
  "Elements": [
    {"ElementId": "visual-id", "ElementType": "VISUAL|FILTER_CONTROL", "ColumnIndex": 0, "RowIndex": 0, "ColumnSpan": 9, "RowSpan": 6}
  ],
  "CanvasSizeOptions": {"ScreenCanvasSizeOptions": {"ResizeOption": "FIXED", "OptimizedViewPortWidth": "1600px"}}
}}}]
```

### Padrões de layout profissional (baseado em dashboards de referência):

| Área | ColumnSpan | RowSpan | Uso |
|---|---|---|---|
| Filtros | 9 cada (4 lado a lado) | 2 | Barra de filtros no topo |
| KPIs | 9 cada (4 lado a lado) | 6 | KPIs com sparkline |
| KPIs (3) | 12 cada | 6 | 3 KPIs lado a lado |
| Gráfico grande | 18 (metade) | 10-12 | Line/Bar charts |
| Gráfico full | 36 (inteiro) | 10-14 | Tabelas, mapas |
| Pie/Donut | 18 (metade) | 10 | Distribuições |

### Ordem vertical típica:
1. Row 0: Filtros (h=2)
2. Row 2: KPIs (h=6)
3. Row 8: Gráficos de tendência (h=10-12)
4. Row 18: Gráficos de distribuição (h=10)
5. Row 28+: Tabelas detalhadas (h=12-14)

---

## 5. DASHBOARD — Publicação

### Criar dashboard a partir de analysis (via definition):
```bash
# 1. Exportar definition da analysis
aws quicksight describe-analysis-definition --aws-account-id ACCOUNT --analysis-id ID --query "Definition" > definition.json

# 2. Montar payload do dashboard
python3 -c "
import json
with open('definition.json') as f:
    defn = json.load(f)
payload = {
    'AwsAccountId': 'ACCOUNT',
    'DashboardId': 'dashboard-id',
    'Name': 'Dashboard Name',
    'ThemeArn': 'arn:...',
    'Permissions': [...],
    'Definition': defn
}
with open('dashboard.json', 'w') as f:
    json.dump(payload, f)
"

# 3. Criar
aws quicksight create-dashboard --cli-input-json file://dashboard.json --profile PROFILE --region REGION
```

### ⛔ NÃO funciona:
- `--source-entity` com ARN de analysis diretamente (precisa de template)
- A abordagem `--definition` é a mais direta e confiável

### Permissions padrão para dashboard:
```json
[{"Principal": "arn:...", "Actions": [
  "quicksight:DescribeDashboard",
  "quicksight:ListDashboardVersions",
  "quicksight:UpdateDashboardPermissions",
  "quicksight:QueryDashboard",
  "quicksight:UpdateDashboard",
  "quicksight:DeleteDashboard",
  "quicksight:UpdateDashboardPublishedVersion",
  "quicksight:DescribeDashboardPermissions"
]}]
```

---

## 6. TEMAS

### Referência: Thema Dark Dati (ID: thema-dark-dati)
```json
{
  "UIColorPalette": {
    "PrimaryForeground": "#FFFFFF",
    "PrimaryBackground": "#0F0B26",
    "SecondaryForeground": "#D9D9E6",
    "SecondaryBackground": "#1A1040",
    "Accent": "#5EC8F2",
    "Success": "#2CAD00",
    "Danger": "#EA5077",
    "Warning": "#FF9900"
  },
  "DataColorPalette": {
    "Colors": ["#9FDEF1","#2A5D78","#F6AA54","#B9E52F","#E436BB","#6197E2","#863CFF","#30CB71"]
  }
}
```

### Para replicar tema entre contas:
```bash
aws quicksight describe-theme --aws-account-id ACCOUNT_ORIG --theme-id ID --query "Theme.Version.Configuration"
aws quicksight create-theme --aws-account-id ACCOUNT_DEST --theme-id ID --name "Nome" --base-theme-id CLASSIC --configuration file://theme-config.json
```

---

## 7. TROUBLESHOOTING

| Erro | Causa | Solução |
|---|---|---|
| SQL exception (genérico) | Permissão da role do QS | Verificar IAM policy + Lake Formation grants |
| Schema does not exist | Nome errado do catálogo/namespace | Usar `s3tablescatalog/BUCKET-NAME` como Catalog |
| Missing field | Dataset mudou após criar analysis | Recriar analysis (delete + create) |
| Invalid analysis arn | Tentou criar dashboard via source-entity com analysis | Usar `--definition` extraída da analysis |
| ColumnHierarchies unknown param | TableVisual não suporta | Remover `ColumnHierarchies` de TableVisual |
| Filter scoped to more than one sheet | Filtro multi-sheet sem DefaultFilterControlConfiguration | Scope o filtro para 1 sheet só |
| TimeRangeFilter column type incompatible | Coluna é STRING, não DATETIME | Usar CategoryFilter + Dropdown em vez de DateTimePicker |
| COLUMN_TYPE_INCOMPATIBLE | Tipo na Definition não bate com dado real | Verificar tipos reais via Athena describe |

---

## 8. FLUXO CORRETO DE CRIAÇÃO (ordem)

1. **Verificar data source** — confirmar que existe e tem RoleArn
2. **Verificar permissões** — IAM policy + Lake Formation para o table bucket alvo
3. **Testar query no Athena** — confirmar que os dados são acessíveis
4. **Criar datasets** — com `RelationalTable`, ImportMode DIRECT_QUERY
5. **Criar analysis** — com Definition (sheets, visuals, layout, filtros)
6. **Validar visualmente** — abrir no browser, checar se dados aparecem
7. **Publicar dashboard** — extrair definition da analysis e criar dashboard

### Dica: Para copiar layout de um dashboard existente:
```bash
aws quicksight describe-analysis-definition --aws-account-id ACCOUNT --analysis-id ID \
  --query "Definition.Sheets[0].Layouts[0].Configuration.GridLayout.Elements"
```
