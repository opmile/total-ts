# Cap. 3 — Interfaces, Extends e Composicao de Objetos

## Objetivo
Ao fim deste estudo, ser capaz de: usar `interface extends` para compor tipos complexos a partir de tipos base, usar utility types (`Record`, `Pick`, `Omit`, `Partial`) para derivar variantes, e modelar a hierarquia completa de tipos do painel-contratos.

## Conexao com o projeto real
Este capitulo e onde tudo se conecta. O DESIGN.md define exatamente esta hierarquia:
- **`interface ContratoDetalhes extends Contrato`** — heranca de interface, o padrao central do projeto
- **`Record<StatusContrato, { label; variant }>`** — o `statusConfig` que mapeia cada status a seu badge
- **`Pick<Contrato, 'idContrato' | 'nomeCliente'>`** — subconjunto de campos para exibicao na tabela
- **`Omit<ContratoDetalhes, 'idContrato'>`** — dados do formulario de criacao (sem ID)
- **`Partial<FiltrosContrato>`** — todos os filtros ja sao opcionais, mas o padrao Partial generaliza

Alem disso, intersections (`&`) aparecem como alternativa a `extends`, e entender a diferenca e crucial para escolhas de design.

**Interfaces alimentadas:**
- `Contrato` (base)
- `ContratoDetalhes extends Contrato` (detalhes)
- `statusConfig: Record<StatusContrato, ...>`
- Tipos derivados para tabela e formulario

## Topicos do capitulo

- [ ] Intersection types (`&`) para combinar objetos
- [ ] `interface extends` para heranca
- [ ] Diferenca entre intersection e extends
- [ ] Conflitos ao estender propriedades incompativeis
- [ ] Index signatures: `[key: string]: tipo`
- [ ] Index signatures com chaves definidas
- [ ] `Record<K, V>` — mapear unions a valores
- [ ] `Pick<T, K>` — selecionar propriedades
- [ ] `Omit<T, K>` — excluir propriedades
- [ ] `Partial<T>` — tornar tudo opcional
- [ ] Unions de objetos e chaves comuns

## Exercicios relevantes

Todos em `src/020-objects/`:

| # | Exercicio | Conceito | Conexao com painel-contratos |
|---|-----------|----------|------------------------------|
| 1 | `081-extend-using-intersections` | `A & B` | `Contrato & { valorEntrada: number }` |
| 2 | `082-extend-using-interfaces` | `interface B extends A` | `ContratoDetalhes extends Contrato` |
| 3 | `082.5-extending-incompatible-properties` | Conflito de tipos | O que acontece se ContratoDetalhes tenta sobrescrever `valorTotal`? |
| 4 | `084-index-signatures` | `[key: string]: T` | Respostas flexiveis da API |
| 5 | `085-index-signatures-with-defined-keys` | Chaves fixas + dinamicas | Objeto com campos conhecidos + extras |
| 6 | `087-record-type-with-union-as-keys` | `Record<Union, T>` | `Record<StatusContrato, { label: string; variant: string }>` |
| 7 | `089-pick-type-helper` | `Pick<T, K>` | `Pick<Contrato, 'idContrato' \| 'nomeCliente' \| 'statusContrato'>` para colunas da tabela |
| 8 | `091-omit-type-helper` | `Omit<T, K>` | `Omit<ContratoDetalhes, 'idContrato'>` para form de criacao |
| 9 | `095-partial-type-helper` | `Partial<T>` | `Partial<FiltrosContrato>` para estado inicial dos filtros |
| 10 | `096.5-common-keys-of-unions` | Chaves comuns em unions de objetos | Entender como TS trata unions de `Contrato \| ContratoDetalhes` |

### Exercicio criado: Arquivo completo de tipos do painel-contratos

Este e o checkpoint mais importante do estudo. Escreva o arquivo `types/contrato.ts` completo:

```ts
// ===== TIPOS BASE =====

type StatusContrato = 1 | 8 | 9;

type TipoContrato =
  | "ADITIVO" | "AMBIENTAL" | "CRIMINAL" | "LEILAO"
  | "NAC" | "PRP" | "RECUPERACAO JUDICIAL"
  | "TRIBUTARIO" | "VENDA CASADA";

// ===== INTERFACES PRINCIPAIS =====

interface Contrato {
  // preencha todos os 10 campos do DESIGN.md
  // lembre: 4 campos sao string | null
}

interface ContratoDetalhes extends Contrato {
  // preencha os 10 campos adicionais
  // lembre: 3 campos sao number | null
}

interface Permissoes {
  // 2 campos booleanos
}

interface FiltrosContrato {
  // 6 campos, todos opcionais (?)
}

// ===== TIPOS DERIVADOS =====

// statusConfig: mapeia cada status a label + variant do badge
type StatusConfig = Record<StatusContrato, {
  label: string;
  variant: "default" | "secondary" | "destructive";
}>;

// Subconjunto de Contrato para exibicao na tabela
type ContratoResumo = Pick<Contrato, /* quais campos? */>;

// Dados do formulario de criacao (sem ID, sem campos auto-gerados)
type ContratoFormData = Omit<ContratoDetalhes, /* quais campos? */>;

// Estado inicial dos filtros (tudo vazio)
type FiltrosIniciais = Partial<FiltrosContrato>;
```

Compare com o DESIGN.md seção "Tipos TypeScript" (linhas 352-398).

## Notas e duvidas

_(preencher durante o estudo)_
