# Skill: Code Review

## Checklist de revisão (executar ANTES de mandar pro tester)

### 1. Corretude
- A mudança resolve o problema descrito?
- Não introduz regressões em funcionalidades adjacentes?
- Edge cases tratados? (null, undefined, array vazio, string vazia)

### 2. Qualidade de código
- Nomes descritivos para variáveis e funções?
- Funções com responsabilidade única (< 50 linhas idealmente)?
- Sem código morto (funções não usadas, imports não usados)?
- Sem `console.log` de debug deixado no código?
- Sem `any` desnecessário em TypeScript?
- Sem `catch` vazio que engole erros silenciosamente?

### 3. Segurança
- Sem secrets/tokens hardcodados?
- Inputs do usuário validados antes de usar?
- Queries SQL parametrizadas (sem concatenação de strings)?
- Sem `dangerouslySetInnerHTML` sem sanitização?

### 4. Contratos e compatibilidade
- Assinaturas de exports preservadas? (não quebra quem importa)
- Respostas de API no formato esperado pelo frontend?
- Status codes HTTP corretos? (200, 201, 400, 404, 500)
- Tipos TypeScript consistentes entre backend e frontend?

### 5. Performance
- Sem loops desnecessários ou re-renders excessivos?
- Queries ao banco otimizadas? (sem N+1)
- Sem imports pesados desnecessários?

## Como revisar

1. Leia os arquivos modificados com `fs_read`
2. Compare com o comportamento anterior (se relevante)
3. Verifique cada item do checklist
4. Se encontrar problemas: mande o dev corrigir ANTES de ir pro tester
5. Se tudo OK: prossiga pro tester com briefing focado

## Formato do feedback pro dev

```
🔍 Review encontrou problemas:

1. [arquivo:linha] — <descrição do problema>
   Sugestão: <como corrigir>

2. [arquivo:linha] — <descrição do problema>
   Sugestão: <como corrigir>

Corrija esses pontos e avise quando terminar.
```
