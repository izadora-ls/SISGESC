-- ============================================================
--  SisGESC — OLAP: Star Schema (Modelagem Estrela)
--  Versão 1.0 — Entrega Final
--
--  ESTRUTURA:
--    1. RESET das tabelas OLAP
--    2. DDL das Dimensões (dim_tempo, dim_aluno, dim_curso,
--       dim_turma, dim_forma_pagamento)
--    3. DDL da Tabela Fato (fato_pagamento)
--    4. ETL — carga das dimensões a partir do OLTP
--    5. ETL — carga da fato com JOINs nas dimensões
--    6. Validação: SUM(OLTP) = SUM(OLAP)
--    7. Consultas analíticas de exemplo
--
--  IDEMPOTÊNCIA:
--    As dimensões usam INSERT IGNORE + chave natural (nk_*)
--    A fato é TRUNCATE + recarga a cada execução do ETL
--    (padrão de mercado para cargas full-refresh)
-- ============================================================

USE sisgesc;

-- ============================================================
--  1. RESET — DROP das tabelas OLAP
--     (executar antes de recriar a estrutura)
-- ============================================================

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS fato_pagamento;
DROP TABLE IF EXISTS dim_forma_pagamento;
DROP TABLE IF EXISTS dim_turma;
DROP TABLE IF EXISTS dim_curso;
DROP TABLE IF EXISTS dim_aluno;
DROP TABLE IF EXISTS dim_tempo;

SET FOREIGN_KEY_CHECKS = 1;


-- ============================================================
--  2. DDL — DIMENSÕES
-- ============================================================

-- ------------------------------------------------------------
--  dim_tempo
--  Granularidade: um registro por dia de pagamento registrado
--  Surrogate Key: sk_tempo (INT, auto-increment)
-- ------------------------------------------------------------
CREATE TABLE dim_tempo (
    sk_tempo           INT          NOT NULL AUTO_INCREMENT,
    data_completa      DATE         NOT NULL,
    dia                INT          NOT NULL,
    mes                INT          NOT NULL,
    ano                INT          NOT NULL,
    trimestre          INT          NOT NULL,
    nome_mes           VARCHAR(20)  NOT NULL,
    nome_dia_semana    VARCHAR(20)  NOT NULL,
    eh_fim_semana      BOOLEAN      NOT NULL DEFAULT FALSE,

    CONSTRAINT pk_dim_tempo PRIMARY KEY (sk_tempo),
    CONSTRAINT uq_dim_tempo_data UNIQUE (data_completa)
) COMMENT 'Dimensão de tempo — cada data de pagamento registrada no sistema';


-- ------------------------------------------------------------
--  dim_aluno
--  Denormalizada: combina tb_aluno + tb_pessoa
--  Surrogate Key: sk_aluno (INT, auto-increment)
--  Natural Key: nk_id_aluno = tb_aluno.pk_id_aluno
-- ------------------------------------------------------------
CREATE TABLE dim_aluno (
    sk_aluno       INT          NOT NULL AUTO_INCREMENT,
    nk_id_aluno    INT          NOT NULL COMMENT 'Natural Key: tb_aluno.pk_id_aluno',
    nome_completo  VARCHAR(120) NOT NULL,
    rgm            VARCHAR(20)  NOT NULL,
    faixa_etaria   VARCHAR(20)  NOT NULL,
    status_aluno   VARCHAR(20)  NOT NULL,

    CONSTRAINT pk_dim_aluno PRIMARY KEY (sk_aluno),
    CONSTRAINT uq_dim_aluno_nk UNIQUE (nk_id_aluno)
) COMMENT 'Dimensão de aluno — desnormalizada de tb_aluno + tb_pessoa';


-- ------------------------------------------------------------
--  dim_curso
--  Surrogate Key: sk_curso
--  Natural Key: nk_id_curso = tb_curso.pk_id_curso
-- ------------------------------------------------------------
CREATE TABLE dim_curso (
    sk_curso      INT          NOT NULL AUTO_INCREMENT,
    nk_id_curso   INT          NOT NULL COMMENT 'Natural Key: tb_curso.pk_id_curso',
    nome_curso    VARCHAR(100) NOT NULL,
    nivel_ensino  VARCHAR(30)  NOT NULL,

    CONSTRAINT pk_dim_curso PRIMARY KEY (sk_curso),
    CONSTRAINT uq_dim_curso_nk UNIQUE (nk_id_curso)
) COMMENT 'Dimensão de curso — origin: tb_curso';


-- ------------------------------------------------------------
--  dim_turma
--  Surrogate Key: sk_turma
--  Natural Key: nk_id_turma = tb_turma.pk_id_turma
-- ------------------------------------------------------------
CREATE TABLE dim_turma (
    sk_turma      INT          NOT NULL AUTO_INCREMENT,
    nk_id_turma   INT          NOT NULL COMMENT 'Natural Key: tb_turma.pk_id_turma',
    nome_turma    VARCHAR(50)  NOT NULL,
    turno         VARCHAR(20)  NOT NULL,
    ano_letivo    INT          NOT NULL,

    CONSTRAINT pk_dim_turma PRIMARY KEY (sk_turma),
    CONSTRAINT uq_dim_turma_nk UNIQUE (nk_id_turma)
) COMMENT 'Dimensão de turma — origin: tb_turma';


-- ------------------------------------------------------------
--  dim_forma_pagamento
--  Surrogate Key: sk_forma
--  Natural Key: forma_pagamento (varchar, DISTINCT do OLTP)
-- ------------------------------------------------------------
CREATE TABLE dim_forma_pagamento (
    sk_forma        INT         NOT NULL AUTO_INCREMENT,
    forma_pagamento VARCHAR(30) NOT NULL,

    CONSTRAINT pk_dim_forma PRIMARY KEY (sk_forma),
    CONSTRAINT uq_dim_forma_nk UNIQUE (forma_pagamento)
) COMMENT 'Dimensão de forma de pagamento — extraída de tb_pagamento';


-- ============================================================
--  3. DDL — TABELA FATO
-- ============================================================

-- ------------------------------------------------------------
--  fato_pagamento
--  Granularidade: um registro por pagamento de mensalidade
--  Métricas: valor_original, valor_desconto, valor_pago
--  Chaves: FKs para todas as 5 dimensões
-- ------------------------------------------------------------
CREATE TABLE fato_pagamento (
    sk_pagamento        INT           NOT NULL AUTO_INCREMENT,
    fk_tempo            INT           NOT NULL,
    fk_aluno            INT           NOT NULL,
    fk_curso            INT           NOT NULL,
    fk_turma            INT           NOT NULL,
    fk_forma_pagamento  INT           NOT NULL,
    -- Métricas aditivas
    valor_original      DECIMAL(10,2) NOT NULL COMMENT 'Valor cheio da mensalidade antes de desconto',
    valor_desconto      DECIMAL(10,2) NOT NULL DEFAULT 0 COMMENT 'Desconto aplicado ao pagamento',
    valor_pago          DECIMAL(10,2) NOT NULL COMMENT 'Valor efetivamente pago',
    numero_parcela      INT           NOT NULL COMMENT 'Número da parcela do contrato',

    CONSTRAINT pk_fato_pagamento PRIMARY KEY (sk_pagamento),
    CONSTRAINT fk_fato_tempo   FOREIGN KEY (fk_tempo)           REFERENCES dim_tempo           (sk_tempo),
    CONSTRAINT fk_fato_aluno   FOREIGN KEY (fk_aluno)           REFERENCES dim_aluno           (sk_aluno),
    CONSTRAINT fk_fato_curso   FOREIGN KEY (fk_curso)           REFERENCES dim_curso           (sk_curso),
    CONSTRAINT fk_fato_turma   FOREIGN KEY (fk_turma)           REFERENCES dim_turma           (sk_turma),
    CONSTRAINT fk_fato_forma   FOREIGN KEY (fk_forma_pagamento) REFERENCES dim_forma_pagamento (sk_forma)
) COMMENT 'Fato de pagamentos — grain: 1 linha por pagamento de mensalidade';


-- ============================================================
--  4. ETL — CARGA DAS DIMENSÕES
--     INSERT IGNORE: idempotente pela UNIQUE na natural key
-- ============================================================

-- ------------------------------------------------------------
--  ETL dim_tempo
--  Origem: datas distintas de tb_pagamento
--  Transformações: extração de dia/mês/ano/trimestre/nome
-- ------------------------------------------------------------
INSERT IGNORE INTO dim_tempo
    (data_completa, dia, mes, ano, trimestre, nome_mes, nome_dia_semana, eh_fim_semana)
SELECT DISTINCT
    pag.data_pagamento                         AS data_completa,
    DAY(pag.data_pagamento)                    AS dia,
    MONTH(pag.data_pagamento)                  AS mes,
    YEAR(pag.data_pagamento)                   AS ano,
    QUARTER(pag.data_pagamento)                AS trimestre,
    MONTHNAME(pag.data_pagamento)              AS nome_mes,
    DAYNAME(pag.data_pagamento)                AS nome_dia_semana,
    IF(DAYOFWEEK(pag.data_pagamento) IN (1,7), TRUE, FALSE) AS eh_fim_semana
FROM tb_pagamento pag
WHERE pag.data_pagamento IS NOT NULL;


-- ------------------------------------------------------------
--  ETL dim_aluno
--  Origem: tb_aluno JOIN tb_pessoa
--  Transformação: concatenação do nome + cálculo de faixa etária
-- ------------------------------------------------------------
INSERT IGNORE INTO dim_aluno
    (nk_id_aluno, nome_completo, rgm, faixa_etaria, status_aluno)
SELECT
    alu.pk_id_aluno                                                    AS nk_id_aluno,
    CONCAT(pes.primeiro_nome, ' ', pes.sobrenome)                      AS nome_completo,
    alu.rgm,
    CASE
        WHEN TIMESTAMPDIFF(YEAR, pes.data_nascimento, CURDATE()) < 12  THEN 'Criança'
        WHEN TIMESTAMPDIFF(YEAR, pes.data_nascimento, CURDATE()) < 15  THEN 'Adolescente'
        ELSE 'Jovem Adulto'
    END                                                                AS faixa_etaria,
    pes.status                                                         AS status_aluno
FROM tb_aluno alu
JOIN tb_pessoa pes ON alu.fk_id_pessoa = pes.pk_id_pessoa;


-- ------------------------------------------------------------
--  ETL dim_curso
--  Origem: tb_curso
-- ------------------------------------------------------------
INSERT IGNORE INTO dim_curso
    (nk_id_curso, nome_curso, nivel_ensino)
SELECT
    cur.pk_id_curso,
    cur.nome_curso,
    cur.nivel_ensino
FROM tb_curso cur;


-- ------------------------------------------------------------
--  ETL dim_turma
--  Origem: tb_turma
-- ------------------------------------------------------------
INSERT IGNORE INTO dim_turma
    (nk_id_turma, nome_turma, turno, ano_letivo)
SELECT
    tur.pk_id_turma,
    tur.nome_turma,
    tur.turno,
    tur.ano_letivo
FROM tb_turma tur;


-- ------------------------------------------------------------
--  ETL dim_forma_pagamento
--  Origem: formas distintas de tb_pagamento
-- ------------------------------------------------------------
INSERT IGNORE INTO dim_forma_pagamento
    (forma_pagamento)
SELECT DISTINCT
    pag.forma_pagamento
FROM tb_pagamento pag;


-- ============================================================
--  5. ETL — CARGA DA FATO (full-refresh)
--     TRUNCATE + recarga: padrão para cargas dimensionais
--     Idempotente: executar N vezes → mesmo resultado
-- ============================================================

-- Limpa a fato para recarregar do zero
TRUNCATE TABLE fato_pagamento;

-- Carga da fato: troca valores descritivos por Surrogate Keys
-- Caminho OLTP: pagamento → mensalidade → contrato → matricula → aluno/turma/curso
INSERT INTO fato_pagamento
    (fk_tempo, fk_aluno, fk_curso, fk_turma, fk_forma_pagamento,
     valor_original, valor_desconto, valor_pago, numero_parcela)
SELECT
    dt.sk_tempo,
    da.sk_aluno,
    dc.sk_curso,
    dtu.sk_turma,
    dfp.sk_forma,
    men.valor_original,
    men.valor_desconto,
    pag.valor_pago,
    men.numero_parcela
FROM tb_pagamento pag
-- JOIN 1 — Tempo: converte data_pagamento → sk_tempo
JOIN dim_tempo          dt  ON pag.data_pagamento         = dt.data_completa
-- JOIN 2 — Forma de pagamento: converte string → sk_forma
JOIN dim_forma_pagamento dfp ON pag.forma_pagamento        = dfp.forma_pagamento
-- JOIN 3 — Mensalidade: obtém valor_original, valor_desconto e numero_parcela
JOIN tb_mensalidade     men ON pag.fk_id_mensalidade       = men.pk_id_mensalidade
-- JOIN 4 — Contrato: liga mensalidade à matrícula
JOIN tb_contrato_educacional con ON men.fk_id_contrato     = con.pk_id_contrato
-- JOIN 5 — Matrícula: liga contrato ao aluno e à turma
JOIN tb_matricula       mat ON con.fk_id_matricula         = mat.pk_id_matricula
-- JOIN 6 — Aluno: obtém sk_aluno da dimensão
JOIN tb_aluno           alu ON mat.fk_id_aluno             = alu.pk_id_aluno
JOIN dim_aluno          da  ON alu.pk_id_aluno             = da.nk_id_aluno
-- JOIN 7 — Turma e Curso: obtém sk_turma e sk_curso
JOIN tb_turma           tur ON mat.fk_id_turma             = tur.pk_id_turma
JOIN dim_turma          dtu ON tur.pk_id_turma             = dtu.nk_id_turma
JOIN tb_curso           cur ON tur.fk_id_curso             = cur.pk_id_curso
JOIN dim_curso          dc  ON cur.pk_id_curso             = dc.nk_id_curso;


-- ============================================================
--  6. VALIDAÇÃO — SUM(OLTP) deve ser IGUAL a SUM(OLAP)
--     Este é o critério obrigatório da entrega:
--     prova que nenhum dado foi perdido ou duplicado no ETL
-- ============================================================

SELECT
    'OLTP — tb_pagamento'         AS origem,
    COUNT(*)                       AS qtd_registros,
    SUM(valor_pago)                AS total_valor_pago,
    SUM(valor_original)            AS total_valor_original
FROM tb_pagamento pag
JOIN tb_mensalidade men ON pag.fk_id_mensalidade = men.pk_id_mensalidade

UNION ALL

SELECT
    'OLAP — fato_pagamento'        AS origem,
    COUNT(*)                       AS qtd_registros,
    SUM(valor_pago)                AS total_valor_pago,
    SUM(valor_original)            AS total_valor_original
FROM fato_pagamento;

-- Resultado esperado:
-- Ambas as linhas devem ter qtd_registros, total_valor_pago
-- e total_valor_original IDÊNTICOS.
-- Diferença = bug no ETL.


-- ============================================================
--  7. CONSULTAS ANALÍTICAS (OLAP)
--     Exemplos para a banca — cada uma demonstra uma análise
--     que seria custosa ou complexa no OLTP
-- ============================================================

-- ------------------------------------------------------------
--  7.1 Total arrecadado por mês e ano
-- ------------------------------------------------------------
SELECT
    dt.ano,
    dt.mes,
    dt.nome_mes,
    SUM(fp.valor_pago)          AS total_arrecadado,
    COUNT(*)                    AS qtd_pagamentos
FROM fato_pagamento fp
JOIN dim_tempo dt ON fp.fk_tempo = dt.sk_tempo
GROUP BY dt.ano, dt.mes, dt.nome_mes
ORDER BY dt.ano, dt.mes;


-- ------------------------------------------------------------
--  7.2 Receita por curso e turno
-- ------------------------------------------------------------
SELECT
    dc.nome_curso,
    dtu.turno,
    SUM(fp.valor_pago)          AS total_arrecadado,
    SUM(fp.valor_desconto)      AS total_descontos,
    COUNT(*)                    AS qtd_pagamentos
FROM fato_pagamento fp
JOIN dim_curso dc  ON fp.fk_curso = dc.sk_curso
JOIN dim_turma dtu ON fp.fk_turma = dtu.sk_turma
GROUP BY dc.nome_curso, dtu.turno
ORDER BY total_arrecadado DESC;


-- ------------------------------------------------------------
--  7.3 Perfil de pagamento por aluno
-- ------------------------------------------------------------
SELECT
    da.nome_completo,
    da.faixa_etaria,
    da.status_aluno,
    COUNT(*)                    AS qtd_parcelas_pagas,
    SUM(fp.valor_pago)          AS total_pago,
    SUM(fp.valor_desconto)      AS total_descontos
FROM fato_pagamento fp
JOIN dim_aluno da ON fp.fk_aluno = da.sk_aluno
GROUP BY da.sk_aluno, da.nome_completo, da.faixa_etaria, da.status_aluno
ORDER BY total_pago DESC;


-- ------------------------------------------------------------
--  7.4 Forma de pagamento mais utilizada
-- ------------------------------------------------------------
SELECT
    dfp.forma_pagamento,
    COUNT(*)                    AS qtd_usos,
    SUM(fp.valor_pago)          AS total_movimentado,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentual
FROM fato_pagamento fp
JOIN dim_forma_pagamento dfp ON fp.fk_forma_pagamento = dfp.sk_forma
GROUP BY dfp.forma_pagamento
ORDER BY qtd_usos DESC;


-- ------------------------------------------------------------
--  7.5 Contagem final das tabelas OLAP
-- ------------------------------------------------------------
SELECT 'dim_tempo'           AS tabela, COUNT(*) AS total FROM dim_tempo
UNION ALL
SELECT 'dim_aluno',                     COUNT(*) FROM dim_aluno
UNION ALL
SELECT 'dim_curso',                     COUNT(*) FROM dim_curso
UNION ALL
SELECT 'dim_turma',                     COUNT(*) FROM dim_turma
UNION ALL
SELECT 'dim_forma_pagamento',           COUNT(*) FROM dim_forma_pagamento
UNION ALL
SELECT 'fato_pagamento',                COUNT(*) FROM fato_pagamento;
