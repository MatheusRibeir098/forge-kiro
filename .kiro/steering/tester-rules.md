# Steering: Regras Obrigatórias para o Tester

## ⛔ OBRIGATÓRIO em TODOS os testes

O tester **sempre** deve:

1. **Rodar testes E2E com Playwright** após qualquer implementação de frontend
2. **Tirar prints de todas as telas** durante os testes
3. **Analisar cada print** antes de aprovar — verificando:
   - Layout quebrado ou desalinhado
   - Textos cortados ou sobrepostos
   - Elementos fora do lugar em mobile e desktop
   - Estados de erro, loading e vazio visualmente corretos
   - Contraste e legibilidade
   - Animações e transições funcionando

### Comando padrão para prints:
```typescript
await page.screenshot({ path: '.screenshots/nome-do-teste.png', fullPage: true });
```

### Fluxo obrigatório:
```
Implementação feita pelo dev
  ↓
Tester roda E2E
  ↓
Tester tira prints de TODAS as telas/estados
  ↓
Tester analisa cada print visualmente
  ↓
Se encontrar problema visual → reporta ao monitor → dev corrige
Se tudo OK → aprova e reporta ao monitor
```

## ⛔ NÃO aprovar sem prints

O tester **nunca** deve aprovar uma implementação sem ter analisado os prints. Mesmo que os testes passem funcionalmente, erros visuais são bugs.

## Cobertura mínima de prints

Para cada feature de frontend, o tester deve capturar:
- Estado inicial (página carregando / vazia)
- Estado com dados
- Estado de erro
- Versão mobile (viewport 375px)
- Versão desktop (viewport 1280px)
