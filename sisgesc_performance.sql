-- ============================================================
--  SisGESC — Performance: Índices e Otimização
--  Versão 1.0 — Entrega Final
--
--  ESTRUTURA:
--    1. EXPLAIN ANTES (sem índices customizados)
--    2. Criação dos índices estratégicos
--    3. EXPLAIN DEPOIS (com índices)
--    4. Interpretação dos resultados
-- ============================================================

USE sisgesc;


-- ============================================================
--  1. EXPLAIN ANTES — executa com apenas os índices de PK/FK
--     Salve o output para comparar com o EXPLAIN do bloco 3
-- ============================================================

SELECT '=== EXPLAIN ANTES DOS ÍNDICES ===' AS etapa;

-- Análise 1: busca de mensalidades pendentes por aluno (query comum no dia a dia)
EXPLAIN SELECT
    CONCAT(pes.primeiro_nome, ' ', pes.sobrenome) AS aluno,
    men.numero_parcela,
    men.data_vencimento,
    men.status_mensalidade
FROM tb_mensalidade men
JOIN tb_contrato_educacional con ON men.fk_id_contrato  = con.pk_id_contrato
JOIN tb_matricula            mat ON con.fk_id_matricula = mat.pk_id_matricula
JOIN tb_aluno                alu ON mat.fk_id_aluno     = alu.pk_id_aluno
JOIN tb_pessoa               pes ON alu.fk_id_pessoa    = pes.pk_id_pessoa
WHERE men.status_mensalidade = 'INADIMPLENTE';
-- Observar: coluna "type" e "rows" — esperamos "ALL" (full scan) antes do índice


-- Análise 2: busca de notas por disciplina e bimestre (query de boletim)
EXPLAIN SELECT
    CONCAT(pes.primeiro_nome, ' ', pes.sobrenome) AS aluno,
    dis.nome_disciplina,
    nota.valor_nota
FROM tb_nota nota
JOIN tb_matricula  mat ON nota.fk_id_matricula  = mat.pk_id_matricula
JOIN tb_aluno      alu ON mat.fk_id_aluno        = alu.pk_id_aluno
JOIN tb_pessoa     pes ON alu.fk_id_pessoa       = pes.pk_id_pessoa
JOIN tb_disciplina dis ON nota.fk_id_disciplina  = dis.pk_id_disciplina
WHERE nota.fk_id_disciplina = 1
  AND nota.fk_id_parametro  = 1;


-- Análise 3: relatório de pagamentos por data (query financeira)
EXPLAIN SELECT
    pag.data_pagamento,
    pag.forma_pagamento,
    SUM(pag.valor_pago) AS total
FROM tb_pagamento pag
WHERE pag.data_pagamento BETWEEN '2025-02-01' AND '2025-04-30'
GROUP BY pag.data_pagamento, pag.forma_pagamento;


-- ============================================================
--  2. CRIAÇÃO DOS ÍNDICES ESTRATÉGICOS
--     Critérios de escolha documentados em comentários
-- ============================================================

-- ------------------------------------------------------------
--  MÓDULO FINANCEIRO
-- ------------------------------------------------------------

-- idx_mensalidade_status:
--   Justificativa: status_mensalidade é filtro frequente em
--   relatórios de inadimplência e emissão de cobrança.
--   Sem índice → full scan em toda tb_mensalidade.
CREATE INDEX idx_mensalidade_status
    ON tb_mensalidade (status_mensalidade);

-- idx_mensalidade_contrato:
--   Justificativa: fk_id_contrato é a chave de JOIN mais
--   frequente ao navegar do contrato para as parcelas.
CREATE INDEX idx_mensalidade_contrato
    ON tb_mensalidade (fk_id_contrato);

-- idx_pagamento_data:
--   Justificativa: data_pagamento é usada em filtros de
--   período (ex: relatório mensal, trimestral).
--   Range queries se beneficiam de índice B-tree.
CREATE INDEX idx_pagamento_data
    ON tb_pagamento (data_pagamento);

-- idx_pagamento_forma:
--   Justificativa: forma_pagamento é agrupada em análises
--   de mix de meios de pagamento.
CREATE INDEX idx_pagamento_forma
    ON tb_pagamento (forma_pagamento);


-- ------------------------------------------------------------
--  MÓDULO ACADÊMICO
-- ------------------------------------------------------------

-- idx_nota_matricula_disciplina_parametro:
--   Índice composto: cobre as três colunas usadas em conjunto
--   nos filtros de boletim. Ordem importa: da mais seletiva
--   para a menos seletiva.
CREATE INDEX idx_nota_filtro
    ON tb_nota (fk_id_matricula, fk_id_disciplina, fk_id_parametro);

-- idx_frequencia_matricula_data:
--   Justificativa: relatórios de frequência filtram por
--   matrícula + intervalo de data.
CREATE INDEX idx_frequencia_matricula_data
    ON tb_frequencia (fk_id_matricula, data_aula);


-- ------------------------------------------------------------
--  MÓDULO OLAP — TABELA FATO
-- ------------------------------------------------------------

-- idx_fato_tempo:
--   Justificativa: dim_tempo é a dimensão mais consultada
--   (filtros por mês/ano são onipresentes).
CREATE INDEX idx_fato_tempo
    ON fato_pagamento (fk_tempo);

-- idx_fato_aluno:
--   Justificativa: drill-down por aluno é o caso de uso
--   mais comum no BI escolar.
CREATE INDEX idx_fato_aluno
    ON fato_pagamento (fk_aluno);

-- idx_fato_curso:
--   Justificativa: análises de receita por curso/turma.
CREATE INDEX idx_fato_curso
    ON fato_pagamento (fk_curso);


-- ============================================================
--  3. EXPLAIN DEPOIS — mesmas queries do bloco 1
--     Compare "type", "key" e "rows" com os resultados anteriores
-- ============================================================

SELECT '=== EXPLAIN DEPOIS DOS ÍNDICES ===' AS etapa;

-- Análise 1 (mesma query): mensalidades inadimplentes
EXPLAIN SELECT
    CONCAT(pes.primeiro_nome, ' ', pes.sobrenome) AS aluno,
    men.numero_parcela,
    men.data_vencimento,
    men.status_mensalidade
FROM tb_mensalidade men
JOIN tb_contrato_educacional con ON men.fk_id_contrato  = con.pk_id_contrato
JOIN tb_matricula            mat ON con.fk_id_matricula = mat.pk_id_matricula
JOIN tb_aluno                alu ON mat.fk_id_aluno     = alu.pk_id_aluno
JOIN tb_pessoa               pes ON alu.fk_id_pessoa    = pes.pk_id_pessoa
WHERE men.status_mensalidade = 'INADIMPLENTE';
-- Esperado: "type" = ref, coluna "key" = idx_mensalidade_status
-- "rows" deve cair drasticamente vs. o EXPLAIN do bloco 1


-- Análise 2 (mesma query): notas por disciplina e bimestre
EXPLAIN SELECT
    CONCAT(pes.primeiro_nome, ' ', pes.sobrenome) AS aluno,
    dis.nome_disciplina,
    nota.valor_nota
FROM tb_nota nota
JOIN tb_matricula  mat ON nota.fk_id_matricula  = mat.pk_id_matricula
JOIN tb_aluno      alu ON mat.fk_id_aluno        = alu.pk_id_aluno
JOIN tb_pessoa     pes ON alu.fk_id_pessoa       = pes.pk_id_pessoa
JOIN tb_disciplina dis ON nota.fk_id_disciplina  = dis.pk_id_disciplina
WHERE nota.fk_id_disciplina = 1
  AND nota.fk_id_parametro  = 1;
-- Esperado: "key" = idx_nota_filtro (índice composto em uso)


-- Análise 3 (mesma query): pagamentos por período
EXPLAIN SELECT
    pag.data_pagamento,
    pag.forma_pagamento,
    SUM(pag.valor_pago) AS total
FROM tb_pagamento pag
WHERE pag.data_pagamento BETWEEN '2025-02-01' AND '2025-04-30'
GROUP BY pag.data_pagamento, pag.forma_pagamento;
-- Esperado: "type" = range, "key" = idx_pagamento_data


-- ============================================================
--  4. GUIA DE INTERPRETAÇÃO DO EXPLAIN
--     (para usar na defesa da banca)
--
--  Coluna "type" — do pior para o melhor:
--    ALL   → full table scan (sem índice) — evitar
--    index → varre o índice inteiro
--    range → usa índice em um intervalo (BETWEEN, >, <)
--    ref   → usa índice de igualdade (WHERE col = valor)
--    const → acessa exatamente 1 linha via PK/UNIQUE
--
--  O que mostrar na banca:
--    1. Antes: type=ALL, rows=N (número alto)
--    2. Depois: type=ref ou range, rows=n (número baixo)
--    3. A diferença de "rows" é a prova de eficiência
-- ============================================================

-- Listagem de todos os índices criados no banco (validação)
SELECT
    TABLE_NAME   AS tabela,
    INDEX_NAME   AS indice,
    COLUMN_NAME  AS coluna,
    SEQ_IN_INDEX AS posicao_no_indice,
    NON_UNIQUE   AS permite_duplicata
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
  AND INDEX_NAME != 'PRIMARY'
ORDER BY TABLE_NAME, INDEX_NAME, SEQ_IN_INDEX;
