# Cap. 2 — Unions, Literais e Narrowing

## Objetivo
Ao fim deste estudo, ser capaz de: definir union types para estados e valores possiveis, usar narrowing com `if`, `switch`, `in` e `instanceof` para refinar tipos, e implementar checagem exaustiva com `never`. Isso e o nucleo da logica de status e permissoes do dashboard.

## Conexao com o projeto real
O painel-contratos depende fortemente de unions e narrowing:
- **`StatusContrato = 1 | 8 | 9`** — cada valor literal determina a cor do badge, quais botoes aparecem e quais acoes sao permitidas
- **Campos nullable** — `anexoContratoAssinado: string | null` exige narrowing antes de usar o valor
- **Logica de permissoes** — `if (permissoes.podeEditar && !contrato.anexoContratoAssinado)` e narrowing puro
- **Switch exaustivo** — o statusConfig com 3 variantes precisa cobrir todos os casos; `never` garante que nenhum status novo passe despercebido

**Interfaces alimentadas:**
- `StatusContrato` — union de literais numericos
- `statusConfig` — objeto mapeado por status (narrowing via switch)
- Logica de visibilidade dos botoes de acao na tabela
- Tratamento seguro de respostas da API (`unknown`)

## Topicos do capitulo

- [ ] Union types: `A | B`
- [ ] Literal types: `1`, `"ativo"`, `true`
- [ ] Combinando unions com literais
- [ ] Narrowing com `if` / `else`
- [ ] Narrowing com `typeof`
- [ ] Narrowing com `in`
- [ ] Narrowing com `instanceof`
- [ ] Narrowing de `unknown` para tipo concreto
- [ ] O tipo `never` e checagem exaustiva
- [ ] Discriminated unions (tagged unions)
- [ ] Switch statements com discriminated unions
- [ ] Discriminated booleans

## Exercicios relevantes

Todos em `src/018-unions-and-narrowing/`:

| # | Exercicio | Conceito | Conexao com painel-contratos |
|---|-----------|----------|------------------------------|
| 1 | `053-introduction-to-unions` | `A \| B` | `string \| null` nos campos nullable de Contrato |
| 2 | `054-literal-types` | Valores literais como tipos | `StatusContrato = 1 \| 8 \| 9` |
| 3 | `055-combining-unions` | Compor unions | Combinar StatusContrato com TipoContrato |
| 4 | `059-narrowing-with-if-statements` | `if (x === valor)` | `if (status === 1)` para exibir badge "Ativo" |
| 5 | `061-map-has-doesnt-narrow` | Limites do Map.has | Lookup no statusConfig |
| 6 | `062-throwing-errors-to-narrow` | throw para eliminar ramos | Estado impossivel no switch de status |
| 7 | `064-narrowing-with-in-statements` | `'prop' in obj` | `if ('podeEditar' in permissoes)` |
| 8 | `065.5-narrowing-with-instanceof` | `instanceof Error` | Tratamento de erros da API |
| 9 | `066-narrowing-unknown-to-a-value` | `unknown` → tipo seguro | Resposta da API antes de tipar |
| 10 | `067.5-never-array` | Array vazio tipado | `contratos` vazio antes do fetch |
| 11 | `068-returning-never-to-narrow` | `never` para exaustividade | E se adicionarem status 10? O TS avisa |
| 12 | `074-intro-to-discriminated-unions` | Tagged unions | Modelar estados do contrato com discriminante |
| 13 | `076-narrowing-discriminated-union-switch` | Switch em tag | `switch (contrato.statusContrato)` |
| 14 | `079-discriminated-booleans` | Booleano como discriminante | `Permissoes.podeEditar` → habilita/desabilita acoes |

### Exercicio criado: Logica de status e permissoes

```ts
type StatusContrato = 1 | 8 | 9;

interface Contrato {
  idContrato: number;
  statusContrato: StatusContrato;
  anexoContratoAssinado: string | null;
}

interface Permissoes {
  podeEditar: boolean;
  podeConcluir: boolean;
}

// 1. Implemente: deve retornar o label do status
//    Use switch exaustivo com never no default
function getStatusLabel(status: StatusContrato): string {
  // ???
}

// 2. Implemente: deve retornar a variante do badge
//    "default" | "secondary" | "destructive"
function getStatusVariant(status: StatusContrato): string {
  // ???
}

// 3. Implemente: determina se o botao "Editar" e visivel
//    Regra: podeEditar === true E anexoContratoAssinado === null
function podeExibirBotaoEditar(
  contrato: Contrato,
  permissoes: Permissoes
): boolean {
  // ???
}

// 4. Implemente: determina se o botao "Concluir" e visivel
//    Regra: podeConcluir === true E status === 1
function podeExibirBotaoConcluir(
  contrato: Contrato,
  permissoes: Permissoes
): boolean {
  // ???
}

// 5. Implemente: recebe resposta unknown da API e retorna Contrato ou lanca erro
function parseContratoResponse(data: unknown): Contrato {
  // use narrowing para validar que data e um objeto com os campos esperados
  // ???
}
```

## Notas e duvidas

_(preencher durante o estudo)_
