# SISGESC
Um projeto de Gestão de Sistema Educacional, projeto voltado para a estruturação e organização de um banco de dados de uma Escola Particular com 3 módulos iniciais: Acadêmico, Financeiro e Recursos Humanos.

# SisGESC — Sistema de Gestão Escolar

> Projeto ERP Escolar desenvolvido para a disciplina de Banco de Dados.
> Implementa um ciclo completo: modelagem relacional (OLTP), carga idempotente,
> operações transacionais, conversão para Data Warehouse (OLAP) e otimização de performance.

---

## Índice

- [Visão Geral](#visão-geral)
- [Estrutura do Repositório](#estrutura-do-repositório)
- [Como Executar](#como-executar)
- [Módulos do Sistema](#módulos-do-sistema)
- [Star Schema (OLAP)](#star-schema-olap)
- [Validação de Idempotência](#validação-de-idempotência)
- [Validação OLTP × OLAP](#validação-oltp--olap)
- [Índices e Performance](#índices-e-performance)
- [Governança e Padrões](#governança-e-padrões)

---

## Visão Geral

O **SisGESC** é um sistema de gestão escolar que cobre três módulos operacionais:

| Módulo | Responsabilidade |
|---|---|
| **Acadêmico** | Alunos, matrículas, turmas, disciplinas, notas e frequência |
| **Financeiro** | Contratos, mensalidades, pagamentos e inadimplência |
| **Recursos Humanos** | Funcionários, professores e vínculos com disciplinas |

Sobre o OLTP, é construído um **Data Warehouse** com modelagem estrela (Star Schema) que permite análises de receita por tempo, aluno, curso, turma e forma de pagamento.

---

## Estrutura do Repositório

```
sisgesc/
│
├── sql/
│   ├── sisgesc_ddl_v2.sql          # DDL: criação de todas as tabelas OLTP
│   ├── sisgesc_dml_carga.sql       # DML: carga de dados com idempotência
│   ├── sisgesc_queries_oltp.sql    # Operações OLTP: SELECTs simples, filtros e subselects
│   ├── sisgesc_olap.sql            # Star Schema: DDL, ETL e validação SUM(OLTP)=SUM(OLAP)
│   └── sisgesc_performance.sql     # Índices, EXPLAIN antes/depois e guia de interpretação
│
├── docs/
│   ├── dicionario_de_dados.md      # Descrição de cada tabela, coluna, tipo e restrição
│   └── der.png                     # Diagrama Entidade-Relacionamento (OLTP + OLAP)
│
└── README.md
```

---

## Como Executar

### Pré-requisitos

- MySQL 8.0 ou superior
- Cliente MySQL (MySQL Workbench, DBeaver, CLI)
- Usuário com permissões `CREATE`, `DROP`, `INSERT`, `SELECT`

### Ordem de execução

Execute os scripts **na ordem abaixo**. Cada arquivo é independente e idempotente dentro do seu escopo.

```bash
# 1. Cria o banco e todas as tabelas OLTP (inclui script de reset)
mysql -u seu_usuario -p < sql/sisgesc_ddl_v2.sql

# 2. Carrega os dados operacionais
mysql -u seu_usuario -p < sql/sisgesc_dml_carga.sql

# 3. Executa as consultas OLTP (demonstração)
mysql -u seu_usuario -p < sql/sisgesc_queries_oltp.sql

# 4. Cria o Star Schema, executa o ETL e valida SUM(OLTP) = SUM(OLAP)
mysql -u seu_usuario -p < sql/sisgesc_olap.sql

# 5. Cria os índices e exibe comparação EXPLAIN antes/depois
mysql -u seu_usuario -p < sql/sisgesc_performance.sql
```

> **Dica:** Para rodar tudo de uma vez, você pode concatenar os arquivos na ordem acima ou criar um `run_all.sql` com `SOURCE` para cada arquivo.

### Reset completo

O próprio `sisgesc_ddl_v2.sql` contém o bloco de reset no início (`DROP TABLE IF EXISTS` com `SET FOREIGN_KEY_CHECKS = 0`). Basta reexecutá-lo para recomeçar do zero.

---

## Módulos do Sistema

### Módulo Transversal

| Tabela | Descrição |
|---|---|
| `tb_pessoa` | Entidade central: armazena todos os atores do sistema (alunos, professores, funcionários, responsáveis) |

### Módulo Acadêmico

| Tabela | Descrição |
|---|---|
| `tb_aluno` | Dados acadêmicos do aluno (RGM, data de ingresso) |
| `tb_responsavel` | Vínculo entre responsável e aluno com grau de parentesco |
| `tb_curso` | Cursos oferecidos (Fundamental, Médio) |
| `tb_turma` | Turmas por curso, ano letivo e turno |
| `tb_disciplina` | Disciplinas vinculadas a cada curso |
| `tb_grade_curricular` | Grade semanal: disciplinas por turma com carga horária |
| `tb_parametro_avaliacao` | Bimestres e pesos de avaliação por curso |
| `tb_matricula` | Vínculo aluno-turma com controle de status |
| `tb_nota` | Notas por matrícula, disciplina e bimestre |
| `tb_frequencia` | Registro de presença por aula |
| `tb_calendario_letivo` | Dias letivos e feriados por turma |
| `tb_historico_status_matricula` | Auditoria de mudanças de status de matrícula |
| `tb_documento_aluno` | Documentos digitalizados do aluno |
| `tb_ocorrencia_disciplinar` | Advertências, suspensões e elogios |

### Módulo Financeiro

| Tabela | Descrição |
|---|---|
| `tb_contrato_educacional` | Contrato entre responsável e escola com valor e desconto |
| `tb_mensalidade` | Parcelas geradas pelo contrato |
| `tb_pagamento` | Registro de cada pagamento realizado |
| `tb_inadimplencia` | Controle de contratos com parcelas em atraso |
| `tb_conta_pagar` | Salários e hora-aula a pagar para funcionários |

### Módulo de Recursos Humanos

| Tabela | Descrição |
|---|---|
| `tb_funcionario` | Dados contratuais do funcionário (cargo, vínculo, salário) |
| `tb_professor` | Dados pedagógicos do professor (formação, especialidade, valor/hora) |
| `tb_vinculo_prof_disciplina` | Quais disciplinas e turmas cada professor leciona |

---

## Star Schema (OLAP)

O Data Warehouse é construído sobre a **fato de pagamentos**, com granularidade de um registro por pagamento de mensalidade.

```
                    dim_tempo
                       │
    dim_aluno ─── fato_pagamento ─── dim_curso
                       │
                   dim_turma
                       │
              dim_forma_pagamento
```

### Dimensões

| Tabela | Surrogate Key | Origem OLTP |
|---|---|---|
| `dim_tempo` | `sk_tempo` | Datas de `tb_pagamento` |
| `dim_aluno` | `sk_aluno` | `tb_aluno` + `tb_pessoa` |
| `dim_curso` | `sk_curso` | `tb_curso` |
| `dim_turma` | `sk_turma` | `tb_turma` |
| `dim_forma_pagamento` | `sk_forma` | Valores distintos de `tb_pagamento` |

### Fato

| Tabela | Métricas |
|---|---|
| `fato_pagamento` | `valor_original`, `valor_desconto`, `valor_pago`, `numero_parcela` |

### ETL

O processo ETL está em `sisgesc_olap.sql` e segue o fluxo:

1. Dimensões carregadas com `INSERT IGNORE` (idempotente pela `UNIQUE` na natural key)
2. Fato carregada com `TRUNCATE` + `INSERT` (full-refresh — padrão dimensional)
3. Conversão OLTP → DW feita via JOINs encadeados que trocam valores descritivos por Surrogate Keys

---

## Validação de Idempotência

O script `sisgesc_dml_carga.sql` pode ser executado **quantas vezes quiser** sem duplicar dados.

**Mecanismo:** todos os `INSERT` usam `INSERT IGNORE` combinado com chaves `UNIQUE` naturais (CPF, e-mail, RGM, pares únicos). Se o registro já existir, a linha é simplesmente ignorada.

**Como provar para a banca:**

```sql
-- Execute a carga, anote os totais, execute novamente e compare
-- Os números devem ser IDÊNTICOS nas duas execuções

SELECT 'tb_pessoa' AS tabela, COUNT(*) AS total FROM tb_pessoa
UNION ALL
SELECT 'tb_matricula',        COUNT(*) FROM tb_matricula
UNION ALL
SELECT 'tb_pagamento',        COUNT(*) FROM tb_pagamento;
-- ... (query completa está no início e no final do sisgesc_dml_carga.sql)
```

Resultado esperado: contagens **iguais** antes e depois da reexecução.

---

## Validação OLTP × OLAP

Após rodar o ETL, a query de validação em `sisgesc_olap.sql` compara os totais entre os dois ambientes:

```sql
SELECT 'OLTP' AS origem, COUNT(*), SUM(valor_pago), SUM(valor_original)
FROM tb_pagamento pag
JOIN tb_mensalidade men ON pag.fk_id_mensalidade = men.pk_id_mensalidade
UNION ALL
SELECT 'OLAP', COUNT(*), SUM(valor_pago), SUM(valor_original)
FROM fato_pagamento;
```

Resultado esperado: **ambas as linhas com valores idênticos** — prova que o ETL não perdeu nem duplicou nenhum dado.

---

## Índices e Performance

O script `sisgesc_performance.sql` documenta o ciclo completo de otimização:

| Índice | Tabela | Justificativa |
|---|---|---|
| `idx_mensalidade_status` | `tb_mensalidade` | Filtros de inadimplência (coluna de alto uso em WHERE) |
| `idx_mensalidade_contrato` | `tb_mensalidade` | JOIN frequente com `tb_contrato_educacional` |
| `idx_pagamento_data` | `tb_pagamento` | Range queries por período (BETWEEN, >, <) |
| `idx_pagamento_forma` | `tb_pagamento` | Agrupamento por forma de pagamento |
| `idx_nota_filtro` | `tb_nota` | Índice composto para queries de boletim |
| `idx_frequencia_matricula_data` | `tb_frequencia` | Relatórios de frequência por aluno e data |
| `idx_fato_tempo` | `fato_pagamento` | Dimensão mais consultada no OLAP |
| `idx_fato_aluno` | `fato_pagamento` | Drill-down por aluno no BI |
| `idx_fato_curso` | `fato_pagamento` | Análises de receita por curso |

O script exibe o `EXPLAIN` das mesmas queries antes e depois de criar os índices. Na coluna `type` do resultado, a melhora esperada é de `ALL` (full scan) para `ref` ou `range` (uso de índice).

---

## Governança e Padrões

| Critério | Implementação |
|---|---|
| **Nomenclatura** | `snake_case` em todas as tabelas, colunas e constraints |
| **Comentários** | Todos os scripts comentados com `--` explicando cada bloco |
| **Script de reset** | Bloco `DROP TABLE IF EXISTS` no início do DDL |
| **Integridade** | `ON DELETE RESTRICT` explícito em todas as FKs (sem CASCADE acidental) |
| **Constraints** | `CHECK`, `UNIQUE` e `NOT NULL` aplicados em todas as entidades |
| **Versionamento** | Histórico de commits no Git com mensagens descritivas |
