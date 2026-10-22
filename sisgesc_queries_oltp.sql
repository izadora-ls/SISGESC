-- ============================================================
--  SisGESC — Operações OLTP
--  Versão 1.0 — Entrega Final
--
--  ESTRUTURA:
--    BLOCO 1 — SELECTs simples
--    BLOCO 2 — SELECTs com filtros
--    BLOCO 3 — Subselects com agregação
--    BLOCO 4 — Subselects correlacionados
-- ============================================================

USE sisgesc;


-- ============================================================
--  BLOCO 1 — SELECTs SIMPLES
--  Objetivo: demonstrar leitura direta de tabelas OLTP
-- ============================================================

-- 1.1 Lista todos os alunos ativos com nome completo
SELECT
    alu.pk_id_aluno                                      AS id_aluno,
    CONCAT(pes.primeiro_nome, ' ', pes.sobrenome)        AS nome_completo,
    alu.rgm,
    pes.email,
    pes.status
FROM tb_aluno alu
JOIN tb_pessoa pes ON alu.fk_id_pessoa = pes.pk_id_pessoa
WHERE pes.status = 'ATIVO'
ORDER BY pes.primeiro_nome;


-- 1.2 Todos os professores com sua especialidade e valor/hora
SELECT
    CONCAT(pes.primeiro_nome, ' ', pes.sobrenome)        AS nome_professor,
    prof.formacao_academica,
    prof.especialidade,
    prof.valor_hora_aula,
    func.tipo_vinculo,
    func.salario_base
FROM tb_professor prof
JOIN tb_funcionario func ON prof.fk_id_funcionario = func.pk_id_funcionario
JOIN tb_pessoa      pes  ON func.fk_id_pessoa      = pes.pk_id_pessoa
ORDER BY prof.valor_hora_aula DESC;


-- 1.3 Grade curricular completa por turma
SELECT
    tur.nome_turma,
    tur.turno,
    tur.ano_letivo,
    cur.nome_curso,
    dis.nome_disciplina,
    gr.carga_horaria_semanal
FROM tb_grade_curricular gr
JOIN tb_turma      tur ON gr.fk_id_turma      = tur.pk_id_turma
JOIN tb_disciplina dis ON gr.fk_id_disciplina = dis.pk_id_disciplina
JOIN tb_curso      cur ON tur.fk_id_curso     = cur.pk_id_curso
ORDER BY tur.nome_turma, dis.nome_disciplina;


-- 1.4 Situação financeira de todas as mensalidades
SELECT
    CONCAT(pes.primeiro_nome, ' ', pes.sobrenome)        AS aluno,
    tur.nome_turma,
    men.numero_parcela,
    men.data_vencimento,
    men.valor_original,
    men.valor_desconto,
    men.status_mensalidade
FROM tb_mensalidade men
JOIN tb_contrato_educacional con ON men.fk_id_contrato  = con.pk_id_contrato
JOIN tb_matricula            mat ON con.fk_id_matricula = mat.pk_id_matricula
JOIN tb_aluno                alu ON mat.fk_id_aluno     = alu.pk_id_aluno
JOIN tb_pessoa               pes ON alu.fk_id_pessoa    = pes.pk_id_pessoa
JOIN tb_turma                tur ON mat.fk_id_turma     = tur.pk_id_turma
ORDER BY pes.primeiro_nome, men.numero_parcela;


-- ============================================================
--  BLOCO 2 — SELECTs COM FILTROS
--  Objetivo: demonstrar filtragem e combinação de condições
-- ============================================================

-- 2.1 Alunos com matrícula ATIVA no turno MANHÃ em 2025
SELECT
    CONCAT(pes.primeiro_nome, ' ', pes.sobrenome)        AS aluno,
    tur.nome_turma,
    tur.turno,
    mat.data_matricula,
    mat.status_matricula
FROM tb_matricula mat
JOIN tb_aluno  alu ON mat.fk_id_aluno  = alu.pk_id_aluno
JOIN tb_pessoa pes ON alu.fk_id_pessoa = pes.pk_id_pessoa
JOIN tb_turma  tur ON mat.fk_id_turma  = tur.pk_id_turma
WHERE mat.status_matricula = 'ATIVA'
  AND tur.turno = 'MANHA'
  AND tur.ano_letivo = 2025
ORDER BY pes.primeiro_nome;


-- 2.2 Notas acima de 8.0 no 1º Bimestre de Matemática
SELECT
    CONCAT(pes.primeiro_nome, ' ', pes.sobrenome)        AS aluno,
    dis.nome_disciplina,
    par.descricao                                         AS bimestre,
    nota.valor_nota,
    nota.status_aprovacao
FROM tb_nota nota
JOIN tb_matricula         mat ON nota.fk_id_matricula  = mat.pk_id_matricula
JOIN tb_aluno             alu ON mat.fk_id_aluno        = alu.pk_id_aluno
JOIN tb_pessoa            pes ON alu.fk_id_pessoa       = pes.pk_id_pessoa
JOIN tb_disciplina        dis ON nota.fk_id_disciplina  = dis.pk_id_disciplina
JOIN tb_parametro_avaliacao par ON nota.fk_id_parametro = par.pk_id_parametro
WHERE nota.valor_nota > 8.0
  AND dis.nome_disciplina = 'Matemática'
  AND par.descricao = '1º Bimestre'
ORDER BY nota.valor_nota DESC;


-- 2.3 Pagamentos realizados via PIX ou BOLETO em fevereiro/2025
SELECT
    CONCAT(pes.primeiro_nome, ' ', pes.sobrenome)        AS aluno,
    pag.data_pagamento,
    pag.forma_pagamento,
    pag.valor_pago,
    men.numero_parcela
FROM tb_pagamento pag
JOIN tb_mensalidade          men ON pag.fk_id_mensalidade  = men.pk_id_mensalidade
JOIN tb_contrato_educacional con ON men.fk_id_contrato      = con.pk_id_contrato
JOIN tb_matricula            mat ON con.fk_id_matricula     = mat.pk_id_matricula
JOIN tb_aluno                alu ON mat.fk_id_aluno         = alu.pk_id_aluno
JOIN tb_pessoa               pes ON alu.fk_id_pessoa        = pes.pk_id_pessoa
WHERE pag.forma_pagamento IN ('PIX', 'BOLETO')
  AND pag.data_pagamento BETWEEN '2025-02-01' AND '2025-02-28'
ORDER BY pag.data_pagamento;


-- 2.4 Contratos com desconto aplicado (desconto > 0)
SELECT
    CONCAT(pes.primeiro_nome, ' ', pes.sobrenome)        AS aluno,
    con.valor_mensalidade,
    con.desconto_percentual,
    ROUND(con.valor_mensalidade * (1 - con.desconto_percentual/100), 2) AS valor_liquido,
    con.status_contrato
FROM tb_contrato_educacional con
JOIN tb_matricula mat ON con.fk_id_matricula = mat.pk_id_matricula
JOIN tb_aluno     alu ON mat.fk_id_aluno     = alu.pk_id_aluno
JOIN tb_pessoa    pes ON alu.fk_id_pessoa    = pes.pk_id_pessoa
WHERE con.desconto_percentual > 0
ORDER BY con.desconto_percentual DESC;


-- ============================================================
--  BLOCO 3 — SUBSELECTS COM AGREGAÇÃO
--  Objetivo: demonstrar domínio de GROUP BY + comparações
--            com resultados agregados
-- ============================================================

-- 3.1 Alunos que pagaram mais do que a média geral de pagamentos
--     Subconsulta: calcula a média de valor_pago em tb_pagamento
SELECT
    CONCAT(pes.primeiro_nome, ' ', pes.sobrenome)        AS aluno,
    SUM(pag.valor_pago)                                  AS total_pago,
    ROUND(
        (SELECT AVG(valor_pago) FROM tb_pagamento), 2
    )                                                    AS media_geral
FROM tb_pagamento pag
JOIN tb_mensalidade          men ON pag.fk_id_mensalidade = men.pk_id_mensalidade
JOIN tb_contrato_educacional con ON men.fk_id_contrato    = con.pk_id_contrato
JOIN tb_matricula            mat ON con.fk_id_matricula   = mat.pk_id_matricula
JOIN tb_aluno                alu ON mat.fk_id_aluno       = alu.pk_id_aluno
JOIN tb_pessoa               pes ON alu.fk_id_pessoa      = pes.pk_id_pessoa
GROUP BY alu.pk_id_aluno, pes.primeiro_nome, pes.sobrenome
HAVING SUM(pag.valor_pago) > (SELECT AVG(valor_pago) FROM tb_pagamento)
ORDER BY total_pago DESC;


-- 3.2 Disciplinas com média de nota acima da média geral do sistema
SELECT
    dis.nome_disciplina,
    ROUND(AVG(nota.valor_nota), 2)                       AS media_disciplina,
    ROUND(
        (SELECT AVG(valor_nota) FROM tb_nota), 2
    )                                                    AS media_geral_sistema
FROM tb_nota nota
JOIN tb_disciplina dis ON nota.fk_id_disciplina = dis.pk_id_disciplina
GROUP BY dis.pk_id_disciplina, dis.nome_disciplina
HAVING AVG(nota.valor_nota) > (SELECT AVG(valor_nota) FROM tb_nota)
ORDER BY media_disciplina DESC;


-- 3.3 Total de receita líquida por turma (após descontos)
--     com número de alunos inadimplentes por turma
SELECT
    tur.nome_turma,
    tur.turno,
    COUNT(DISTINCT mat.pk_id_matricula)                  AS total_alunos,
    SUM(pag.valor_pago)                                  AS receita_recebida,
    SUM(men.valor_desconto)                              AS total_descontos,
    (
        SELECT COUNT(DISTINCT con2.pk_id_contrato)
        FROM tb_inadimplencia       ina
        JOIN tb_contrato_educacional con2 ON ina.fk_id_contrato   = con2.pk_id_contrato
        JOIN tb_matricula            mat2 ON con2.fk_id_matricula  = mat2.pk_id_matricula
        WHERE mat2.fk_id_turma = tur.pk_id_turma
    )                                                    AS alunos_inadimplentes
FROM tb_pagamento pag
JOIN tb_mensalidade          men ON pag.fk_id_mensalidade = men.pk_id_mensalidade
JOIN tb_contrato_educacional con ON men.fk_id_contrato    = con.pk_id_contrato
JOIN tb_matricula            mat ON con.fk_id_matricula   = mat.pk_id_matricula
JOIN tb_turma                tur ON mat.fk_id_turma       = tur.pk_id_turma
GROUP BY tur.pk_id_turma, tur.nome_turma, tur.turno
ORDER BY receita_recebida DESC;


-- ============================================================
--  BLOCO 4 — SUBSELECTS CORRELACIONADOS
--  Objetivo: subqueries que referenciam a query externa,
--            demonstrando raciocínio técnico avançado
-- ============================================================

-- 4.1 Alunos que NÃO possuem nenhum pagamento em atraso
--     (EXISTS correlacionado: exclui quem tem mensalidade INADIMPLENTE)
SELECT
    CONCAT(pes.primeiro_nome, ' ', pes.sobrenome)        AS aluno,
    alu.rgm,
    mat.status_matricula
FROM tb_aluno   alu
JOIN tb_pessoa  pes ON alu.fk_id_pessoa = pes.pk_id_pessoa
JOIN tb_matricula mat ON mat.fk_id_aluno = alu.pk_id_aluno
WHERE NOT EXISTS (
    SELECT 1
    FROM tb_contrato_educacional con
    JOIN tb_mensalidade men ON men.fk_id_contrato = con.pk_id_contrato
    WHERE con.fk_id_matricula = mat.pk_id_matricula
      AND men.status_mensalidade = 'INADIMPLENTE'
)
ORDER BY pes.primeiro_nome;


-- 4.2 Professores que ministram TODAS as disciplinas de pelo menos uma turma
--     (EXISTS correlacionado: checa vínculo com turma inteira)
SELECT
    CONCAT(pes.primeiro_nome, ' ', pes.sobrenome)        AS professor,
    prof.especialidade,
    COUNT(DISTINCT vpd.fk_id_turma)                      AS turmas_com_cobertura_total
FROM tb_professor prof
JOIN tb_funcionario func ON prof.fk_id_funcionario = func.pk_id_funcionario
JOIN tb_pessoa      pes  ON func.fk_id_pessoa      = pes.pk_id_pessoa
JOIN tb_vinculo_prof_disciplina vpd ON vpd.fk_id_professor = prof.pk_id_professor
WHERE EXISTS (
    SELECT 1
    FROM tb_grade_curricular gc
    WHERE gc.fk_id_turma = vpd.fk_id_turma
      AND gc.fk_id_disciplina = vpd.fk_id_disciplina
)
GROUP BY prof.pk_id_professor, pes.primeiro_nome, pes.sobrenome, prof.especialidade
ORDER BY turmas_com_cobertura_total DESC;


-- 4.3 Mensalidades pendentes de alunos com matrícula ATIVA
--     (subquery correlacionada que garante que o aluno ainda está ativo)
SELECT
    CONCAT(pes.primeiro_nome, ' ', pes.sobrenome)        AS aluno,
    men.numero_parcela,
    men.data_vencimento,
    men.valor_original,
    men.status_mensalidade,
    DATEDIFF(CURDATE(), men.data_vencimento)             AS dias_vencida
FROM tb_mensalidade men
JOIN tb_contrato_educacional con ON men.fk_id_contrato  = con.pk_id_contrato
JOIN tb_matricula            mat ON con.fk_id_matricula = mat.pk_id_matricula
JOIN tb_aluno                alu ON mat.fk_id_aluno     = alu.pk_id_aluno
JOIN tb_pessoa               pes ON alu.fk_id_pessoa    = pes.pk_id_pessoa
WHERE men.status_mensalidade IN ('PENDENTE', 'INADIMPLENTE')
  AND mat.status_matricula = 'ATIVA'
  AND (
      SELECT COUNT(*)
      FROM tb_pagamento pag2
      WHERE pag2.fk_id_mensalidade = men.pk_id_mensalidade
  ) = 0
ORDER BY dias_vencida DESC, pes.primeiro_nome;
