# Plano Estrategico de Estudos TypeScript — painel-contratos

## Contexto

A usuario esta aprendendo TypeScript do zero para construir um dashboard de gestao de contratos
(painel-contratos) com React + shadcn/ui. O repositorio Total TypeScript Book contem 116
exercicios (.problem.ts) distribuidos em 13 pastas ativas. O CLAUDE.md define foco em:
interfaces, union types, narrowing, props React, useState, optional chaining. Este plano
seleciona 66 dos 116 exercicios (57%), organizados em 5 fases sequenciais com checkpoints
praticos conectados ao DESIGN.md do projeto real.

---

## Abordagem: 5 Fases com Checkpoints

### FASE 1 — Tipos Basicos e Anotacoes (13 exercicios)

Pasta: `src/015-essential-types-and-annotations/`
Plano: `study-plans/27_03_2026_cap-01_tipos-basicos-e-anotacoes.md`

Exercicios selecionados:
1. 020-basic-types-with-function-parameters — primitivos de cada campo Contrato
2. 021-annotating-empty-parameters — disciplina de anotacao
3. 022-all-types — panorama do sistema de tipos
4. 023-optional-function-parameters — mapeia para FiltrosContrato (tudo opcional)
5. 024-default-parameters — valores padrao de filtros
6. 025-object-literal-types — { idContrato: number; nomeCliente: string }
7. 026-optional-property-types — FiltrosContrato tem 6 props opcionais
8. 027-type-keyword — type StatusContrato = 1 | 8 | 9
9. 028-arrays — Contrato[] (dados da tabela)
10. 029-arrays-of-objects — tipar contratos: Contrato[]
11. 032.5-any — perigo do any (JSON.parse, API)
12. 033-function-types — callbacks onFilter: (filtros: FiltrosContrato) => void
13. 034-functions-returning-void — event handlers React

Pular: 030 (rest params), 031-032 (tuples), 034.5 (void vs undefined), 035-038 (Set/Map/async —
avancado)

Checkpoint 1: Escrever type StatusContrato, type TipoContrato e um tipo Contrato basico usando
apenas type keyword. Experimentar a limitacao antes de conhecer interface.

---
FASE 2 — Unions, Literais e Narrowing (14 exercicios)

Pasta: src/018-unions-and-narrowing/
Plano: study-plans/27_03_2026_cap-02_unions-narrowing-status-contrato.md

Exercicios selecionados:
1. 053-introduction-to-unions — string | null nos campos nullable de Contrato
2. 054-literal-types — StatusContrato = 1 | 8 | 9 (logica de badges)
3. 055-combining-unions — combinar StatusContrato com outros unions
4. 059-narrowing-with-if-statements — if (status === 1) para badge "Ativo"
5. 061-map-has-doesnt-narrow — limites de narrowing com Map (statusConfig)
6. 062-throwing-errors-to-narrow — estados impossiveis no switch de status
7. 064-narrowing-with-in-statements — if ('podeEditar' in permissoes)
8. 065.5-narrowing-with-instanceof — tratamento de erros da API
9. 066-narrowing-unknown-to-a-value — resposta segura da API
10. 067.5-never-array — arrays vazios tipados
11. 068-returning-never-to-narrow — checagem exaustiva (e se adicionarem status 10?)
12. 074-intro-to-discriminated-unions — modelar diferentes estados do contrato
13. 076-narrowing-discriminated-union-switch — switch em statusContrato
14. 079-discriminated-booleans — logica condicional de Permissoes

Pular: 071 (narrowing em escopos), 072.5 (type guards reutilizaveis), 075/078 (destructuring
DU/tuples), 080 (defaults em DU)

Checkpoint 2: Escrever getStatusLabel(status: StatusContrato): string com switch exaustivo +
never. Escrever podeExecutarAcao(contrato: Contrato, permissoes: Permissoes, acao: string) com
narrowing baseado em status e permissoes.

---
FASE 3 — Objetos, Interfaces e Composicao (10 exercicios)

Pasta: src/020-objects/
Plano: study-plans/27_03_2026_cap-03_interfaces-extends-contrato-detalhes.md

Exercicios selecionados:
1. 081-extend-using-intersections — Contrato & { valorEntrada: number }
2. 082-extend-using-interfaces — interface ContratoDetalhes extends Contrato
3. 082.5-extending-incompatible-properties — conflitos ao sobrescrever campos
4. 084-index-signatures — [key: string]: unknown para respostas flexiveis
5. 085-index-signatures-with-defined-keys — chaves conhecidas + dinamicas
6. 087-record-type-with-union-as-keys — Record<StatusContrato, { label; variant }>
7. 089-pick-type-helper — Pick<Contrato, 'idContrato' | 'nomeCliente'> para colunas
8. 091-omit-type-helper — Omit<ContratoDetalhes, 'idContrato'> para forms
9. 095-partial-type-helper — Partial<FiltrosContrato> padrao de filtros
10. 096.5-common-keys-of-unions — unions de objetos

Pular: 086 (PropertyKey), 088 (declaration merging)

Checkpoint 3: Escrever o arquivo completo de tipos do painel-contratos:
- StatusContrato, TipoContrato, Contrato, ContratoDetalhes extends Contrato, Permissoes,
FiltrosContrato
- Record<StatusContrato, { label: string; variant: string }> para statusConfig
- Um tipo Pick para exibicao na tabela
- Um tipo Omit para formulario de criacao

---
FASE 4 — Imutabilidade e Assertoes (11 exercicios)

Pastas: src/028-mutability/ + src/045-annotations-and-assertions/
Plano: study-plans/27_03_2026_cap-04_imutabilidade-e-assertoes.md

De 028-mutability (6):
1. 097-let-and-const-inference — const status = 1 infere literal 1
2. 098-object-property-inference — por que { status: 1 } infere number
3. 099-readonly-object-properties — proteger dados de Contrato
4. 101-intro-to-as-const — as const no statusConfig
5. 102-as-const-vs-object-freeze — escolher ferramenta certa
6. 103-readonly-arrays — readonly Contrato[] para dados da tabela

De 045-annotations-and-assertions (5):
7. 139-dont-annotate-too-much — quando deixar TS inferir
8. 141-as-and-as-any — assertions em respostas de API
9. 142-global-typings-use-any — JSON.parse retorna any
10. 143.5-non-null-assertions — contrato.dataConclusaoContrato!
11. 146-satisfies — statusConfig satisfies Record<StatusContrato, ...>

Checkpoint 4: Refinar o arquivo de tipos: adicionar as const ao statusConfig, validar com
satisfies, marcar campos como readonly, tratar JSON.parse com assertion + narrowing.

---
FASE 5 — Guia de Estilo e Derivacao (18 exercicios)

Pastas: src/090-the-style-guide/ + src/040-deriving-types-from-values/ +
src/016.5-ide-superpowers/
Plano: study-plans/27_03_2026_cap-05_guia-estilo-e-derivacao.md

De 090-style-guide (7):
1. 224-hungarian-notation — evitar IContrato, TStatus
2. 225-where-to-put-your-types — organizacao: src/types/contrato.ts
3. 226-colocation-of-types — tipos perto dos componentes vs compartilhados
4. 232-types-vs-interfaces — decisao final type vs interface pro projeto
5. 233-dont-use-uppercase-types — evitar String, Number
6. 235-how-strict-should-you-configure-ts — strict mode pro projeto
7. 236-dont-unnecessarily-widen-types — manter 1 | 8 | 9, nao number

De 040-deriving-types (5):
8. 125-keyof — keyof Contrato para colunas genericas
9. 126-typeof — derivar tipos do statusConfig
10. 135-indexed-access-types — Contrato['statusContrato'] extrai StatusContrato
11. 136-pass-unions-to-indexed-access — extracoes avancadas
12. 133-return-type — ReturnType<typeof fetchContratos>

De 016.5-ide-superpowers (6, passe rapido):
13-18. Todos: hover, TSDoc, autocomplete, auto-import, organize imports, refactor

Checkpoint 5: Arquitetura final de tipos do painel-contratos. Organizar tipos em arquivos
seguindo o style guide. Derivar tipos de colunas com keyof e indexed access. Escrever
interfaces de props tipadas para: StatsCards, FiltersPanel, ContractsTable, ContractDrawer,
DetailsDialog.

---
Resumo

┌──────┬────────────────────────────────────┬────────────┬───────────┐
│ Fase │                Foco                │ Exercicios │ Acumulado │
├──────┼────────────────────────────────────┼────────────┼───────────┤
│ 1    │ Tipos basicos, anotacoes           │ 13         │ 13        │
├──────┼────────────────────────────────────┼────────────┼───────────┤
│ 2    │ Unions, literais, narrowing        │ 14         │ 27        │
├──────┼────────────────────────────────────┼────────────┼───────────┤
│ 3    │ Interfaces, extends, utility types │ 10         │ 37        │
├──────┼────────────────────────────────────┼────────────┼───────────┤
│ 4    │ Imutabilidade, assertions          │ 11         │ 48        │
├──────┼────────────────────────────────────┼────────────┼───────────┤
│ 5    │ Style guide, derivacao, IDE        │ 18         │ 66        │
└──────┴────────────────────────────────────┴────────────┴───────────┘

Pastas excluidas intencionalmente

- 030-classes (9 ex): painel-contratos usa componentes funcionais React, nao classes
- 060-modules-scripts-and-declaration-files: sistema de modulos — importante depois, nao agora
- 065-types-you-dont-control: augmentacao de tipos terceiros — apos construir o projeto

Arquivos criticos

- studies/CLAUDE.md — instrucoes de estudo e convencoes
- project/painel-contratos/DESIGN.md — interfaces reais do projeto
- studies/study-plans/ — destino dos 5 planos de estudo
- studies/total-ts-book/total-typescript-book/src/ — exercicios

Verificacao

Apos cada fase:
1. Executar os exercicios com npm run exercise no repo total-typescript-book
2. Comparar solucao com npm run solution
3. Completar o checkpoint escrevendo tipos reais no contexto do painel-contratos
4. Ao final da Fase 5, o arquivo de tipos completo deve cobrir 100% do DESIGN.md