# Prompt — Dashboard Painel de Contratos (Google Stitch)

## Stack & Setup

```bash
npx shadcn@latest init --preset b0 --template vite
```

Componentes shadcn/ui necessários:
```bash
npx shadcn@latest add card table badge button dialog drawer input select
npx shadcn@latest add separator skeleton tabs textarea tooltip
```

---

## Contexto do Produto

Dashboard interno de um escritório de advocacia para gestão de contratos com clientes.
Operado por equipe comercial/jurídica com dois níveis de permissão (editor e aprovador).
Idioma: português brasileiro. Moeda: BRL.

---

## Estética & Design System

- **Estilo**: Minimalista, shadcn/ui canônico — sem customizações visuais além do necessário
- **Tema**: Light com suporte a dark mode via `next-themes`
- **Tipografia**: Fonte padrão shadcn (`font-sans`, Geist ou similar)
- **Cores de status**:
  - Ativo → `badge variant="default"` (verde neutro)
  - Concluído → `badge variant="secondary"` (azul neutro)
  - Inativo → `badge variant="destructive"` (vermelho)
- **Densidade**: Compacta — tabela com `text-sm`, padding reduzido nas células
- **Não usar**: gradientes, animações complexas, cores vibrantes, sombras exageradas

---

## Layout Geral

```
┌─────────────────────────────────────────────────────┐
│ Sidebar (fixo, 240px)  │  Conteúdo principal        │
│                        │                             │
│  - Logo / sistema      │  Header da página           │
│  - Painel Contratos    │  ─────────────────────────  │
│    (item ativo)        │  Cards de estatísticas      │
│  - [outros módulos]    │  ─────────────────────────  │
│                        │  Filtros (colapsável)       │
│  ────────────────      │  ─────────────────────────  │
│  Usuário logado        │  Tabela de contratos        │
│  Badge de permissão    │                             │
└─────────────────────────────────────────────────────┘
```

---

## 1. Sidebar

```tsx
// components/sidebar.tsx
// Usar: SidebarProvider + Sidebar do shadcn/ui (sidebar component)

- Logo do sistema no topo (texto: "COMERCIAL" em peso bold)
- Item de navegação ativo: "Painel de Contratos" com ícone FileText
- Rodapé da sidebar:
  - Avatar + nome do usuário
  - Badge com permissão: "Editor" ou "Aprovador"
```

---

## 2. Header da Página

```tsx
// Dentro do layout principal, acima dos cards

<h1 className="text-xl font-semibold tracking-tight">Painel de Contratos</h1>
<p className="text-sm text-muted-foreground">Gestão e acompanhamento de contratos</p>

// Botão de ação principal (canto direito):
<Button onClick={() => setDrawerOpen(true)}>
  <Plus className="mr-2 h-4 w-4" /> Novo Contrato
</Button>
```

---

## 3. Cards de Estatísticas

```tsx
// 4 cards em grid: grid-cols-2 md:grid-cols-4

Card 1: "Contratos Ativos"
  - Valor: contagem de status = 1
  - Ícone: FileCheck (verde)

Card 2: "Contratos Concluídos"
  - Valor: contagem de status = 8
  - Ícone: CheckCircle (azul)

Card 3: "Valor em Contratos Ativos"
  - Valor: soma de valorTotal onde status = 1, formatado como BRL
  - Ícone: DollarSign

Card 4: "Aguardando Assinatura"
  - Valor: contratos sem anexoContratoAssinado
  - Ícone: AlertCircle (amarelo/warning)

// Estrutura de cada card:
<Card>
  <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
    <CardTitle className="text-sm font-medium">{titulo}</CardTitle>
    <Icon className="h-4 w-4 text-muted-foreground" />
  </CardHeader>
  <CardContent>
    <div className="text-2xl font-bold">{valor}</div>
    <p className="text-xs text-muted-foreground">{descricao}</p>
  </CardContent>
</Card>
```

---

## 4. Painel de Filtros

```tsx
// Colapsável com Collapsible do shadcn/ui
// Estado inicial: expandido

Campos:
- Input "ID" (tipo number, largura pequena)
- Select "Tipo de Contrato":
  options: ADITIVO, AMBIENTAL, CRIMINAL, LEILÃO, NAC, PRP, 
           RECUPERAÇÃO JUDICIAL, TRIBUTÁRIO, VENDA CASADA
- Select "Cliente" (searchable — usar Combobox shadcn)
- DatePicker "Período de" + DatePicker "até" (usar Calendar + Popover)
- Select "Status": Ativo (1), Concluído (8), Inativo (9)

Botões:
- <Button variant="outline">Limpar</Button>
- <Button>Consultar</Button>
```

---

## 5. Tabela de Contratos

```tsx
// Usar Table shadcn/ui com server-side pagination

Colunas:
| ID | Status | Data | Tipo | Cliente | Valor Contrato | Dt. Assinado | Dt. Conclusão | Ações |

// Coluna Status — Badge colorido:
const statusConfig = {
  1: { label: "Ativo",     variant: "default"     },
  8: { label: "Concluído", variant: "secondary"   },
  9: { label: "Inativo",   variant: "destructive" },
}

// Coluna Ações — DropdownMenu ou botões inline (ícones):
- Detalhes     → <Button variant="ghost" size="icon"><Eye /></Button>
- Anexos       → <Button variant="ghost" size="icon"><Paperclip /></Button>
- Editar   → visível se: permissoes.podeEditar && !anexoContratoAssinado
                 <Button variant="ghost" size="icon"><Pencil /></Button>
- Concluir → visível se: permissoes.podeConcluir && status === 1
                 <Button variant="ghost" size="icon"><CircleCheck /></Button>
- Ativar   → visível se: permissoes.podeEditar && status === 9
                 <Button variant="ghost" size="icon"><Play /></Button>
- Inativar → visível se: permissoes.podeEditar && (status === 1 || status === 8)
                 <Button variant="ghost" size="icon" className="text-destructive"><X /></Button>

// Paginação:
<Pagination> com controles Anterior / Próximo
pageLength: 30 registros por página
```

---

## 6. Drawer — Cadastro / Edição de Contrato

```tsx
// Usar Drawer (bottom sheet em mobile, lateral em desktop)
// Largura: max-w-2xl

Seção 1 — Identificação:
- Select "Cliente" (obrigatório, searchable)
- MultiSelect "Tipo de Contrato" (obrigatório)
  → Se "ADITIVO" selecionado: exibir Input "ID Contrato Principal" (obrigatório condicional)

Seção 2 — Valores Financeiros:
- Input "Entrada Inicial" (moeda BRL, obrigatório)
- Input "Entrada Restante" (moeda BRL, obrigatório)
- Input "Parcelas Entrada" (número, opcional)
- Input "Valor Caso" (moeda BRL, obrigatório)
- Input "Parcelas Caso" (número, opcional)
- Input "Valor Total" (somente leitura, calculado automaticamente: Entrada Inicial + Entrada Restante + Valor Caso)
- DatePicker "Vencimento" (obrigatório)

Seção 3 — Complemento:
- Textarea "Valor do Êxito" (obrigatório, 4 linhas)
- Textarea "Observações Gerais" (obrigatório, 4 linhas)

Rodapé do Drawer:
- <Button variant="outline">Cancelar</Button>
- <Button type="submit">{modoEdicao ? "Atualizar" : "Gravar"}</Button>

Validações frontend:
- Campos obrigatórios marcados com asterisco
- valorTotal deve ser exatamente igual à soma dos três componentes
- Formato de data dd/mm/yyyy
- ID do contrato aditivo: apenas números
```

---

## 7. Dialog — Detalhes do Contrato

```tsx
// Usar Dialog (modal centralizado)
// Usar Tabs para organizar as seções

<Tabs defaultValue="geral">
  <TabsList>
    <TabsTrigger value="geral">Dados Gerais</TabsTrigger>
    <TabsTrigger value="valores">Valores e Pagamento</TabsTrigger>
    <TabsTrigger value="exito">Êxito e Observações</TabsTrigger>
  </TabsList>

  <TabsContent value="geral">
    // Renderizar como lista de pares label/valor:
    - ID Contrato
    - Status (Badge)
    - Data de Inclusão
    - Tipo de Contrato
    - Cliente
    - ID Contrato Principal (condicional se ADITIVO)
    - Data de Conclusão (condicional se existir)
  </TabsContent>

  <TabsContent value="valores">
    - Valor Total
    - Vencimento
    - Entrada Inicial
    - Entrada Restante (Negociada)
    - Parcelas Entrada
    - Valor Caso
    - Parcelas Caso
  </TabsContent>

  <TabsContent value="exito">
    - Valor do Êxito (texto pré-formatado)
    - Observações Gerais (texto pré-formatado)
  </TabsContent>
</Tabs>
```

---

## 8. Dialog — Anexos do Contrato

```tsx
// Usar Dialog simples

Seção 1 — Enviar Arquivos:
- FileInput "Contrato Assinado" (PDF)
  → Exibir nome do arquivo selecionado abaixo do input
- FileInput "Comprovante de Pagamento" (PDF/imagem)
  → Exibir nome do arquivo selecionado abaixo do input

Seção 2 — Arquivos Existentes:
- "Contrato Assinado":
  → Se existir: link com ícone <FileText /> + nome do arquivo (abre em nova aba)
  → Se não existir: texto "Nenhum arquivo enviado" em muted
- "Data Anexo Contrato": data formatada dd/mm/yyyy HH:mm:ss
- "Comprovante de Pagamento":
  → Se existir: link com ícone <FileText /> + nome
  → Se não existir: texto "Nenhum arquivo enviado" em muted

Rodapé:
- <Button variant="outline">Fechar</Button>
- <Button><Upload className="mr-2 h-4 w-4" /> Enviar Arquivos</Button>

Nota UX: após upload bem-sucedido, recarregar seção 2 automaticamente.
```

---

## 9. Confirmações de Ação

```tsx
// Usar AlertDialog shadcn/ui para ações destrutivas ou irreversíveis

Concluir contrato:
  title: "Concluir contrato?"
  description: "O contrato será marcado como concluído. Esta ação não pode ser revertida."
  confirm: <Button variant="default">Confirmar</Button>

Inativar contrato:
  title: "Desativar contrato?"
  description: "Deseja realmente desativar este contrato?"
  confirm: <Button variant="destructive">Desativar</Button>

Ativar contrato:
  title: "Ativar contrato?"
  description: "Deseja realmente ativar este contrato?"
  confirm: <Button variant="default">Ativar</Button>
```

---

## 10. Estados de Loading e Feedback

```tsx
// Tabela carregando:
<Skeleton className="h-8 w-full" /> // repetir por N linhas

// Cards de estatísticas carregando:
<Skeleton className="h-6 w-24" />

// Toast para feedback de ações (usar Sonner ou shadcn toast):
toast.success("Contrato gravado com sucesso! (ID: 42)")
toast.error("Erro ao processar a solicitação.")
toast.success("Arquivo(s) enviado(s) com sucesso!")
```

---

## Estrutura de Arquivos Sugerida

```
app/
  (dashboard)/
    layout.tsx          ← sidebar + content wrapper
    contratos/
      page.tsx          ← página principal
      components/
        stats-cards.tsx
        filters-panel.tsx
        contracts-table.tsx
        contract-drawer.tsx   ← cadastro/edição
        details-dialog.tsx
        attachments-dialog.tsx
        action-confirm-dialog.tsx
```

---

## Tipos TypeScript

```ts
type StatusContrato = 1 | 8 | 9;

type TipoContrato =
  | "ADITIVO" | "AMBIENTAL" | "CRIMINAL" | "LEILÃO"
  | "NAC" | "PRP" | "RECUPERAÇÃO JUDICIAL"
  | "TRIBUTÁRIO" | "VENDA CASADA";

interface Contrato {
  idContrato: number;
  statusContrato: StatusContrato;
  dataInclusao: string;
  tipoContrato: string;
  nomeCliente: string;
  valorTotal: number;
  anexoContratoAssinado: string | null;
  comprovantePagamento: string | null;
  dataAnexoContrato: string | null;
  dataConclusaoContrato: string | null;
}

interface ContratoDetalhes extends Contrato {
  idCliente: number;
  idContratoAditivo: number | null;
  dataEntrada: string;
  valorEntrada: number;
  valorNegociado: number;
  parcelaNegociado: number | null;
  valorCaso: number;
  parcelaCaso: number | null;
  valorInvestimento: string;
  obsGeral: string;
}

interface Permissoes {
  podeEditar: boolean;  
  podeConcluir: boolean; 
}

interface FiltrosContrato {
  idContrato?: number;
  tipoContrato?: TipoContrato;
  idCliente?: number;
  dataInicial?: string;
  dataFinal?: string;
  statusContrato?: StatusContrato;
}
```