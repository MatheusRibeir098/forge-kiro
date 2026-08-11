---
name: tester-rules
description: Regras obrigatorias de QA de frontend com Playwright, screenshots e inspecao visual em desktop/mobile e estados loading, vazio, dados e erro. Use sempre que testar qualquer mudanca de frontend.
---

# QA visual obrigatorio

Para toda implementacao de frontend:

1. execute E2E com Playwright no fluxo afetado;
2. capture screenshots full-page das telas e estados relevantes;
3. analise cada imagem antes de aprovar;
4. valide funcionalidade e aparencia em desktop 1280 px e mobile 375 px;
5. reporte qualquer estado que nao foi possivel produzir como lacuna, nunca como aprovado.

Cobertura minima quando o produto possui esses estados:

- carregamento/inicial;
- vazio;
- com dados;
- erro;
- desktop 1280 px;
- mobile 375 px.

Ao inspecionar, verifique: overflow e layout quebrado; alinhamento e espacamento; texto cortado/sobreposto; controles fora da viewport; legibilidade/contraste; foco/teclado; loading/empty/error coerentes; animacoes e transicoes sem quebra.

Screenshot Playwright:

```ts
await page.screenshot({ path: '.screenshots/<caso>-<viewport>.png', fullPage: true });
```

Mantenha `.screenshots/` fora de commits salvo quando o projeto exigir evidencias versionadas. Prefira testes/servidor ja configurados no repo; nao instale Playwright novamente se ja existir.

Criterio de aprovacao: testes funcionais passam e todos os screenshots obrigatorios foram abertos e analisados. Teste verde sem inspecao visual nao e PASS. Problema visual produz `VERDICT: NEEDS_CHANGES` com viewport, estado, evidencia e correcao esperada.
