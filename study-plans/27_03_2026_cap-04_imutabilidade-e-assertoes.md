# Cap. 4 — Imutabilidade e Assertoes

## Objetivo
Ao fim deste estudo, ser capaz de: entender como `const` vs `let` afeta inferencia, usar `readonly` e `as const` para proteger dados, usar `satisfies` para validar tipos sem alargar, e tratar respostas da API com assertions seguras.

## Conexao com o projeto real
- **`as const` no statusConfig** — sem `as const`, o TS infere `variant: string` ao inves de `"default" | "secondary" | "destructive"`. Com `as const`, os literais sao preservados.
- **`satisfies`** — `statusConfig satisfies Record<StatusContrato, ...>` valida que todas as 3 chaves (1, 8, 9) existem sem perder os tipos literais
- **`readonly Contrato[]`** — a tabela recebe dados que nao devem ser mutados pelo componente
- **`readonly` em campos** — `idContrato` nunca deve ser alterado apos criacao
- **Assertions em API** — `JSON.parse(body)` retorna `any`; precisamos de `as` ou narrowing para obter `Contrato`
- **Non-null assertion** — `contrato.dataConclusaoContrato!` quando voce sabe que existe (ex: status === 8)

**Interfaces alimentadas:**
- Refinamento de `statusConfig` com `as const` + `satisfies`
- Props de componentes com `readonly`
- Tratamento de dados da API

## Topicos do capitulo

### Mutabilidade (028)
- [ ] Inferencia com `let` (tipo amplo) vs `const` (tipo literal)
- [ ] Inferencia de propriedades de objetos (sempre ampla)
- [ ] `readonly` em propriedades individuais
- [ ] `as const` — congela literais em tempo de compilacao
- [ ] `as const` vs `Object.freeze` — TS vs runtime
- [ ] `readonly` em arrays

### Assertoes (045)
- [ ] Quando NAO anotar — deixar TS inferir
- [ ] `as` e `as any` — quando usar com cuidado
- [ ] `JSON.parse` retorna `any` — como lidar
- [ ] Non-null assertion (`!`) — quando voce sabe mais que o TS
- [ ] `satisfies` — valida forma sem perder inferencia

## Exercicios relevantes

### De `src/028-mutability/`:

| # | Exercicio | Conceito | Conexao com painel-contratos |
|---|-----------|----------|------------------------------|
| 1 | `097-let-and-const-inference` | `const x = 1` infere `1`, nao `number` | Declarar status como const preserva o literal |
| 2 | `098-object-property-inference` | `{ status: 1 }` infere `number` | Por que statusConfig perde literais sem `as const` |
| 3 | `099-readonly-object-properties` | `readonly prop: T` | `readonly idContrato: number` — nunca muda |
| 4 | `101-intro-to-as-const` | `as const` | statusConfig com valores literais preservados |
| 5 | `102-as-const-vs-object-freeze` | Diferenca TS vs runtime | Escolher a ferramenta certa para cada caso |
| 6 | `103-readonly-arrays` | `readonly T[]` | `readonly Contrato[]` na tabela — componente nao muta |

### De `src/045-annotations-and-assertions/`:

| # | Exercicio | Conceito | Conexao com painel-contratos |
|---|-----------|----------|------------------------------|
| 7 | `139-dont-annotate-too-much` | Inferencia > anotacao | Nao repetir tipos que o TS ja sabe |
| 8 | `141-as-and-as-any` | Type assertions | `response.data as Contrato[]` da API |
| 9 | `142-global-typings-use-any` | `JSON.parse` → `any` | Toda resposta de API passa por isso |
| 10 | `143.5-non-null-assertions` | `x!` | `contrato.dataConclusaoContrato!` (quando status=8) |
| 11 | `146-satisfies` | Keyword `satisfies` | `statusConfig satisfies Record<StatusContrato, ...>` |

### Exercicio criado: Refinando o statusConfig

```ts
type StatusContrato = 1 | 8 | 9;

// ANTES (sem as const) — variant e inferido como string
const statusConfig = {
  1: { label: "Ativo",     variant: "default"     },
  8: { label: "Concluido", variant: "secondary"   },
  9: { label: "Inativo",   variant: "destructive" },
};
// Problema: statusConfig[1].variant e string, nao "default"

// DEPOIS — aplique as const E satisfies para:
// 1. Preservar os literais ("default", "secondary", "destructive")
// 2. Garantir que todas as 3 chaves existem
// 3. O TS avisa se voce esquecer uma chave ou errar o nome da variant

const statusConfigRefinado = {
  // preencha...
} as const satisfies Record<StatusContrato, {
  label: string;
  variant: "default" | "secondary" | "destructive";
}>;

// TESTE: remova a chave 9 e veja o erro do satisfies
// TESTE: troque "default" por "primary" e veja o erro
// TESTE: tente statusConfigRefinado[1].variant = "x" e veja o erro do readonly
```

## Notas e duvidas

_(preencher durante o estudo)_
