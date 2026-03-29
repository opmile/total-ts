# CLAUDE.md — Estudos TypeScript

Estou aprendendo TypeScript para construir um dashboard de contratos
usando React + shadcn/ui.

## Destino do aprendizado
Este repo é ambiente de estudo para o projeto real localizado em:
~/dev/projetos/painel-contratos

O artefato de referência é o DESIGN.md desse projeto.
Sempre que explicar um padrão, relacione ao contexto do dashboard
de contratos — interfaces Contrato, ContratoDetalhes, Permissoes...

Tenha noção que os contratos definidos ainda não foram implementados de forma concreta justamente para me forçar a entender como funciona sua criação.

## Contexto

## Meu artefato de referência
Ver design.md anexo. Os tipos que preciso entender na prática estão
nas interfaces: Contrato, ContratoDetalhes, Permissoes, FiltrosContrato.

## O que focar
- Interfaces e type aliases
- Union types e literal types (StatusContrato = 1 | 8 | 9)
- Props tipadas em componentes React
- useState<T> e tipagem de eventos
- Optional chaining e nullish coalescing
- Type narrowing básico

## O que ignorar por agora
- Generics avançados, mapped types, conditional types
- Decorators, namespaces, module augmentation
- Configuração avançada de tsconfig

## Como me ajudar
Quando eu travar num exercício, explique relacionando ao contexto
do dashboard de contratos — não em exemplos genéricos.

## Planos de Estudo

Sempre que for solicitado um plano de estudo, crie um arquivo
no diretório `study-plans/` deste repositório.

### Nomenclatura

Padrão: `DD_MM_YYYY_cap-{N}_{topico-em-kebab-case}.md`

Exemplos:
- `27_03_2027_cap-03_interfaces-e-extends.md`
- `27_03_2027_cap-05_union-types-status-contrato.md`
- `27_03_2027_cap-08_props-tipadas-react.md`

Regras:
- Data sempre no início — permite ordenação cronológica automática
- Número do capítulo referente ao total-typescript-book, ou de acordo com a necessidade de crescimento de capítulos conforme estudo
- Tópico em kebab-case, em português, específico o suficiente
  para identificar o conteúdo sem abrir o arquivo
- Nunca usar nomes genéricos como `plano-01.md` ou `estudo-typescript.md`

### Estrutura interna de cada plano

Todo arquivo gerado nesse diretório deve seguir esta estrutura:

# Cap. {N} — {Tópico}

## Objetivo
O que preciso ser capaz de fazer no projeto painel-contratos ao fim deste estudo.

## Conexão com o projeto real
Como esse padrão é visto e entendido em outros projetos com complexidade de domínio familiar ao do que se quer construir. Qual interface, componente ou regra de negócio do DESIGN.md este capítulo alimenta. 

## Tópicos do capítulo
Lista do que será coberto, marcando com [ ] o que ainda não foi estudado.

## Exercícios relevantes
Quais exercícios do repositório se aplicam diretamente ao contexto do dashboard. Além disso, quando identificar uma possível lacuna de conhecimento que poderia ser aplicável no dashboard, crie você o exercício.

## Notas e dúvidas
Registro livre durante o estudo.