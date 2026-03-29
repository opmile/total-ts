# Cap. 5 — Guia de Estilo e Derivacao de Tipos

## Objetivo
Ao fim deste estudo, ser capaz de: organizar tipos em arquivos seguindo convencoes do ecossistema, usar `keyof`, `typeof` e indexed access para derivar tipos sem duplicacao, e configurar o TS com strictness adequada. Este e o capitulo final antes de comecar a implementar o painel-contratos.

## Conexao com o projeto real
- **Organizacao de tipos** — O DESIGN.md ja define `src/types/contrato.ts` como local canonico. Este capitulo ensina quando colocar tipos nesse arquivo vs co-locados nos componentes
- **`type` vs `interface`** — Decisao arquitetural: `interface` para `Contrato` (extensivel) vs `type` para `StatusContrato` (union, nao extensivel)
- **`keyof Contrato`** — Gera `"idContrato" | "statusContrato" | "dataInclusao" | ...` — util para colunas da tabela
- **`typeof statusConfig`** — Deriva o tipo do objeto em runtime sem duplicar a definicao
- **Indexed access** — `Contrato["statusContrato"]` extrai `StatusContrato` diretamente da interface
- **`ReturnType`** — `ReturnType<typeof fetchContratos>` para tipar o retorno da API sem duplicar

**Interfaces alimentadas:**
- Props tipadas de todos os componentes React do dashboard
- Tipo de colunas da tabela derivado de `keyof`
- Arquitetura final de arquivos de tipos

## Topicos do capitulo

### Guia de Estilo (090)
- [ ] Convencoes de nomeacao — evitar prefixos hungaros (`IContrato`, `TStatus`)
- [ ] Onde colocar tipos: arquivo centralizado vs co-locado
- [ ] Colocation de tipos — quando manter perto do componente
- [ ] `type` vs `interface` — quando usar cada um
- [ ] Nao usar tipos uppercase (`String`, `Number`, `Boolean`)
- [ ] Nivel de strictness no tsconfig
- [ ] Nao alargar tipos desnecessariamente

### Derivacao de Tipos (040)
- [ ] `keyof T` — extrair chaves como union
- [ ] `typeof valor` — criar tipo a partir de um valor
- [ ] Indexed access types: `T[K]`
- [ ] Passar unions para indexed access
- [ ] `ReturnType<typeof fn>` — tipar retorno de funcoes

### IDE Superpowers (016.5, passe rapido)
- [ ] Hover para inspecionar tipos
- [ ] TSDoc comments
- [ ] Autocomplete manual (Ctrl+Space)
- [ ] Auto-import
- [ ] Organize imports
- [ ] Refactor (rename symbol)

## Exercicios relevantes

### De `src/090-the-style-guide/`:

| # | Exercicio | Conceito | Conexao com painel-contratos |
|---|-----------|----------|------------------------------|
| 1 | `224-hungarian-notation` | Nao usar `IContrato` | Nomear `Contrato`, nao `IContrato` |
| 2 | `225-where-to-put-your-types` | Arquivo centralizado | `src/types/contrato.ts` como fonte canonica |
| 3 | `226-colocation-of-types` | Tipos perto do componente | Props de `ContractDrawer` ficam no proprio arquivo? |
| 4 | `232-types-vs-interfaces` | Quando usar cada | `interface Contrato` (extensivel) vs `type StatusContrato` (union) |
| 5 | `233-dont-use-uppercase-types` | `string` sim, `String` nao | Evitar armadilha comum de iniciante |
| 6 | `235-how-strict-should-you-configure-ts` | Strictness | Configurar `strict: true` no projeto |
| 7 | `236-dont-unnecessarily-widen-types` | Manter literais | `StatusContrato = 1 \| 8 \| 9`, nunca `number` |

### De `src/040-deriving-types-from-values/`:

| # | Exercicio | Conceito | Conexao com painel-contratos |
|---|-----------|----------|------------------------------|
| 8 | `125-keyof` | `keyof T` | `keyof Contrato` para colunas genericas da tabela |
| 9 | `126-typeof` | `typeof valor` | `typeof statusConfig` para derivar tipo do objeto |
| 10 | `135-indexed-access-types` | `T[K]` | `Contrato["statusContrato"]` extrai `StatusContrato` |
| 11 | `136-pass-unions-to-indexed-access` | `T[K1 \| K2]` | Extrair union de varios campos |
| 12 | `133-return-type` | `ReturnType<typeof fn>` | Tipar retorno de `fetchContratos` sem duplicar |

### De `src/016.5-ide-superpowers/` (passe rapido):

| # | Exercicio | Conceito |
|---|-----------|----------|
| 13 | `041-hovering-a-function-call` | Inspecionar tipos no hover |
| 14 | `042-adding-tsdoc-comments-for-hovers` | Documentar interfaces com TSDoc |
| 15 | `044-manually-triggering-autocomplete` | Ctrl+Space para autocompletar |
| 16 | `048-auto-import` | Importar tipos automaticamente |
| 17 | `049-organize-imports` | Limpar imports |
| 18 | `050-refactor` | Renomear simbolos com seguranca |

### Exercicio criado: Arquitetura final de tipos + Props React

```ts
// ===== src/types/contrato.ts =====
// Reuna TUDO que voce construiu nas fases 1-4 aqui.
// Este arquivo e a fonte canonica de tipos do projeto.

// Tipos base
export type StatusContrato = 1 | 8 | 9;
export type TipoContrato = /* ... */;

// Interfaces principais
export interface Contrato { /* ... */ }
export interface ContratoDetalhes extends Contrato { /* ... */ }
export interface Permissoes { /* ... */ }
export interface FiltrosContrato { /* ... */ }

// Objeto de configuracao de status (as const + satisfies)
export const statusConfig = { /* ... */ } as const satisfies /* ... */;

// Tipos derivados
export type StatusConfig = typeof statusConfig;
export type ContratoKeys = keyof Contrato;
export type ContratoResumo = Pick<Contrato, /* colunas da tabela */>;
export type ContratoFormData = Omit<ContratoDetalhes, /* campos auto */>;


// ===== Props dos componentes React =====
// Defina as props de cada componente do DESIGN.md:

// stats-cards.tsx
interface StatsCardsProps {
  contratos: readonly Contrato[];
  loading: boolean;
}

// filters-panel.tsx
interface FiltersPanelProps {
  filtros: FiltrosContrato;
  onFiltrosChange: (filtros: FiltrosContrato) => void;
  onConsultar: () => void;
  onLimpar: () => void;
}

// contracts-table.tsx
interface ContractsTableProps {
  contratos: readonly Contrato[];
  permissoes: Permissoes;
  loading: boolean;
  onDetalhes: (id: number) => void;
  onAnexos: (id: number) => void;
  onEditar: (id: number) => void;
  onConcluir: (id: number) => void;
  onAtivar: (id: number) => void;
  onInativar: (id: number) => void;
}

// contract-drawer.tsx
interface ContractDrawerProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  contrato: ContratoDetalhes | null; // null = modo criacao
  onSubmit: (data: ContratoFormData) => void;
}

// details-dialog.tsx
interface DetailsDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  contrato: ContratoDetalhes | null;
}
```

Ao concluir este exercicio, voce tera a arquitetura de tipos completa e estara pronta para comecar a implementar os componentes do painel-contratos.

## Notas e duvidas

_(preencher durante o estudo)_
