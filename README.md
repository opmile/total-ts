# ts-just_in_time

Repositório pessoal de aprendizado de TypeScript com foco aplicado na construção do **painel-contratos** — um dashboard interno de gestão de contratos para escritório de advocacia (React + Vite + shadcn/ui).

## Estrutura do repositório

```
ts-just_in_time/
├── studies/                    # Ambiente de estudo
│   ├── total-ts-book/          # Exercícios do Total TypeScript Book (Matt Pocock)
│   ├── total-ts-sandbox/       # Sandbox livre para experimentação
│   └── study-plans/            # Planos de estudo por capítulo
│       ├── cap-01 — Tipos básicos e anotações
│       ├── cap-02 — Unions, narrowing e status de contrato
│       ├── cap-03 — Interfaces, extends e composição
│       ├── cap-04 — Imutabilidade e asserções
│       └── cap-05 — Guia de estilo e derivação
│
└── project/
    └── painel-contratos/       # Especificação do dashboard (DESIGN.md)
```

## Metodologia

O estudo segue 5 fases sequenciais com exercícios selecionados do Total TypeScript Book. Cada fase termina com um **checkpoint prático** onde os conceitos são aplicados escrevendo tipos reais do `DESIGN.md` do painel-contratos (`Contrato`, `ContratoDetalhes`, `Permissoes`, `FiltrosContrato`).

## Rodando os exercícios

```sh
cd studies/total-ts-book
pnpm install
pnpm run exercise
```

---

## Git Worktrees com Superset

Este repositório utiliza **git worktrees** gerenciados pelo [Superset](https://github.com/nicholasgasior/gbt) para isolar os contextos de estudo e projeto em diretórios independentes, cada um com sua própria branch.

### Por que worktrees?

Em vez de ficar alternando branches com `git checkout` (que reescreve o working directory inteiro), worktrees permitem manter múltiplas branches checadas **simultaneamente** em diretórios separados. Isso é útil quando:

- Você quer estudar e mexer no projeto ao mesmo tempo sem conflitos de estado
- Cada contexto tem suas próprias dependências instaladas (`node_modules`) sem interferência
- Você pode ter editores/terminais abertos em cada worktree independentemente

### Worktrees ativos

| Worktree | Branch | Caminho |
|----------|--------|---------|
| **main** | `main` | `.` (raiz do repo) |
| **studies** | `studies` | `~/.superset/worktrees/ts-just_in_time/studies` |
| **project** | `project` | `~/.superset/worktrees/ts-just_in_time/project` |

### Comandos úteis

```sh
# Listar todos os worktrees
git worktree list

# Navegar para o worktree de estudos
cd ~/.superset/worktrees/ts-just_in_time/studies

# Navegar para o worktree do projeto
cd ~/.superset/worktrees/ts-just_in_time/project

# Criar um novo worktree para uma branch
git worktree add <caminho> <branch>

# Remover um worktree que não é mais necessário
git worktree remove <caminho>
```

### Como o Superset organiza

O Superset armazena os worktrees em `~/.superset/worktrees/ts-just_in_time/`, mantendo a raiz do repositório limpa. Cada worktree é um checkout independente que compartilha o mesmo `.git` — commits feitos em qualquer worktree são visíveis nos outros.

```
~/.superset/worktrees/ts-just_in_time/
├── studies/    ← branch studies checked out aqui
└── project/    ← branch project checked out aqui
```

> **Dica**: nunca delete manualmente um diretório de worktree. Sempre use `git worktree remove` para que o Git limpe as referências internas corretamente.
