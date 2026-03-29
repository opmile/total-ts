# CLAUDE.md direcionado ao contexto de Design System

Dashboard interno de gestão de contratos para escritório de advocacia.
Stack: React + Vite + shadcn/ui. Idioma: pt-BR. Moeda: BRL.

## Referência de design
Ver `docs/design.md` para estrutura completa de componentes,
layout e decisões de UI.

## Regras de negócio críticas
- valorTotal deve ser exatamente igual a entradaInicial + entradaRestante + valorCaso
- Tipo ADITIVO exige idContratoAditivo obrigatório
- Botão editar só aparece se podeEditar === true E anexoContratoAssinado === null
- Botão concluir só aparece se podeConcluir === true E status === 1

## Tipos canônicos
Ver `src/types/contrato.ts` — nunca redefina essas interfaces inline.

## Componentes shadcn em uso
Badge, Button, Card, Collapsible, Dialog, Drawer, Input,
Pagination, Select, Skeleton, Table, Tabs, Textarea, Toast (Sonner)

## Convenções
- Variantes de Badge por status: 1=default, 8=secondary, 9=destructive
- Sempre usar toast (Sonner) para feedback de ação, em português
- Skeleton em todas as zonas com loading assíncrono