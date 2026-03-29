# Cap. 1 — Tipos Basicos e Anotacoes

## Objetivo
Ao fim deste estudo, ser capaz de anotar corretamente tipos primitivos, objetos, arrays, funcoes e parametros opcionais — tudo o que e necessario para definir os campos de `Contrato` e `FiltrosContrato`.

## Conexao com o projeto real
Cada campo de `Contrato` no DESIGN.md usa tipos primitivos: `number` (idContrato, valorTotal), `string` (nomeCliente, dataInclusao), `string | null` (anexoContratoAssinado). Os filtros (`FiltrosContrato`) sao um objeto onde todas as propriedades sao opcionais (`?`). Os callbacks de componentes React (como `onFilter`) sao funcoes tipadas que retornam `void`. Este capitulo constroi o vocabulario necessario para tudo isso.

**Interfaces alimentadas:**
- `Contrato` — todos os campos primitivos
- `FiltrosContrato` — propriedades opcionais
- Callbacks de componentes — `(filtros: FiltrosContrato) => void`

## Topicos do capitulo

- [x] Anotacoes de tipo em parametros de funcao
- [ ] Tipos primitivos: `string`, `number`, `boolean`, `null`, `undefined`
- [ ] Inferencia de tipo vs anotacao explicita
- [ ] Parametros opcionais (`param?`) e valores default
- [ ] Object literal types: `{ chave: tipo }`
- [ ] Propriedades opcionais em objetos (`prop?:`)
- [ ] Type aliases com `type`
- [ ] Arrays: `tipo[]` e `Array<tipo>`
- [ ] Arrays de objetos: `Contrato[]`
- [ ] O tipo `any` e por que evita-lo
- [ ] Function types: `(params) => retorno`
- [ ] Funcoes que retornam `void`

## Exercicios relevantes

Todos em `src/015-essential-types-and-annotations/`:

| # | Exercicio | Conceito | Conexao com painel-contratos |
|---|-----------|----------|------------------------------|
| 1 | `020-basic-types-with-function-parameters` | Anotar `string`, `number`, `boolean` em params | Cada campo de `Contrato` e um primitivo |
| 2 | `021-annotating-empty-parameters` | Anotar parametros sem valor default | Funcoes utilitarias do dashboard |
| 3 | `022-all-types` | Panorama de todos os tipos | Saber qual tipo usar para cada campo |
| 4 | `023-optional-function-parameters` | `param?` | `FiltrosContrato` — todos os campos sao opcionais |
| 5 | `024-default-parameters` | Valor padrao em params | Filtros com valor default (ex: status = 1) |
| 6 | `025-object-literal-types` | `{ chave: tipo }` | `{ idContrato: number; nomeCliente: string }` |
| 7 | `026-optional-property-types` | `prop?: tipo` | 6 propriedades opcionais em `FiltrosContrato` |
| 8 | `027-type-keyword` | `type X = ...` | `type StatusContrato = 1 \| 8 \| 9` |
| 9 | `028-arrays` | `tipo[]` | `Contrato[]` — dados da tabela |
| 10 | `029-arrays-of-objects` | `Objeto[]` | Tipar `contratos: Contrato[]` na tabela |
| 11 | `032.5-any` | Perigos do `any` | `JSON.parse` retorna `any` — respostas da API |
| 12 | `033-function-types` | `(p: T) => R` | `onFilter: (filtros: FiltrosContrato) => void` |
| 13 | `034-functions-returning-void` | `(): void` | Todo event handler React retorna void |

### Exercicio criado: Rascunho do tipo Contrato

Apos completar os exercicios acima, tente escrever sem consultar o DESIGN.md:

```ts
// Usando APENAS type (sem interface), defina:

// 1. Um type alias para os 3 status possiveis de um contrato
type StatusContrato = // ???

// 2. Um type alias para os tipos de contrato disponiveis
type TipoContrato = // ???

// 3. Um type para representar um contrato na tabela
type Contrato = {
  // preencha os campos que voce lembra
  // use string | null para campos que podem ser nulos
}

// 4. Um type para os filtros (todas propriedades opcionais)
type FiltrosContrato = {
  // preencha com ?
}

// 5. Uma funcao que recebe filtros e nao retorna nada
type OnFilterCallback = // ???
```

Depois compare com o DESIGN.md. Note as limitacoes de `type` para composicao — na Fase 3, `interface extends` resolvera isso.

## Notas e duvidas

_(preencher durante o estudo)_
