# Skill: Meta-Prompt Engineering

## Princípios de Conversational Prompt Engineering (CPE)

### Objetivo
Extrair do usuário requisitos completos através de conversa guiada, gerando um prompt estruturado que outro agente pode executar sem ambiguidade.

### Técnica: Perguntas Data-Driven
Não faça perguntas genéricas. Baseie suas perguntas no que o usuário já disse:
- Usuário disse "app de receitas" → pergunte sobre categorias, busca, favoritos
- Usuário disse "dashboard" → pergunte sobre métricas, gráficos, tempo real
- Usuário disse "e-commerce" → pergunte sobre carrinho, pagamento, estoque

### Técnica: Assumptions Explícitas
Toda decisão que você tomar sem input direto do usuário deve ser marcada:
```
[ASSUMPTION] Stack: React + Vite (usuário não especificou framework)
[ASSUMPTION] Banco: SQLite (projeto pequeno, sem necessidade de escala)
[ASSUMPTION] Auth: não necessária (usuário não mencionou login)
```

O usuário pode corrigir qualquer assumption antes de aprovar.

### Técnica: Refinamento Iterativo
1. Gere uma primeira versão do prompt
2. Mostre ao usuário
3. Peça feedback específico: "O que está faltando? O que está errado?"
4. Refine baseado no feedback
5. Repita até aprovação

### Anti-patterns
- ❌ Fazer 10+ perguntas de uma vez (overwhelm)
- ❌ Perguntas sim/não que não agregam (ex: "Quer que fique bonito?")
- ❌ Assumir stack sem perguntar preferência
- ❌ Gerar prompt sem confirmar com o usuário
- ❌ Ignorar restrições mencionadas pelo usuário

### Estrutura do Prompt Gerado
O prompt final deve ser auto-contido — qualquer desenvolvedor (humano ou agente) deve conseguir construir o projeto lendo apenas o prompt.md, sem contexto adicional.

Seções obrigatórias:
1. Visão Geral (o quê + pra quem + por quê)
2. Stack Técnica (com justificativa)
3. Funcionalidades com critérios de aceitação
4. Arquitetura (pastas, padrões, modelo de dados)
5. Design & UX (estilo, cores, layout)
6. Constraints (o que NÃO fazer)
7. Assumptions (decisões tomadas pelo agente)
8. Tarefas ordenadas de implementação
