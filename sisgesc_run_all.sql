-- ============================================================
--  SisGESC — run_all.sql
--  Script único de instalação completa
--  
--  COMO USAR NO WORKBENCH:
--  1. File → Open SQL Script → seleciona este arquivo
--  2. Clica no raio ⚡
--  3. Pronto! Banco criado, tabelas criadas e dados inseridos.
--
--  Versão: 2.0 | Entrega Final
-- ============================================================


-- ============================================================
--  PASSO 1 — CRIAR / RECRIAR O BANCO
-- ============================================================

DROP DATABASE IF EXISTS sisgesc;
CREATE DATABASE sisgesc
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE sisgesc;


-- ============================================================
--  PASSO 2 — RESET DE SEGURANÇA (evita conflito de FKs)
-- ============================================================

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS tb_conta_pagar;
DROP TABLE IF EXISTS tb_inadimplencia;
DROP TABLE IF EXISTS tb_pagamento;
DROP TABLE IF EXISTS tb_mensalidade;
DROP TABLE IF EXISTS tb_contrato_educacional;
DROP TABLE IF EXISTS tb_ocorrencia_disciplinar;
DROP TABLE IF EXISTS tb_documento_aluno;
DROP TABLE IF EXISTS tb_historico_status_matricula;
DROP TABLE IF EXISTS tb_calendario_letivo;
DROP TABLE IF EXISTS tb_frequencia;
DROP TABLE IF EXISTS tb_nota;
DROP TABLE IF EXISTS tb_matricula;
DROP TABLE IF EXISTS tb_parametro_avaliacao;
DROP TABLE IF EXISTS tb_grade_curricular;
DROP TABLE IF EXISTS tb_disciplina;
DROP TABLE IF EXISTS tb_turma;
DROP TABLE IF EXISTS tb_curso;
DROP TABLE IF EXISTS tb_responsavel;
DROP TABLE IF EXISTS tb_aluno;
DROP TABLE IF EXISTS tb_vinculo_prof_disciplina;
DROP TABLE IF EXISTS tb_professor;
DROP TABLE IF EXISTS tb_funcionario;
DROP TABLE IF EXISTS tb_pessoa;

SET FOREIGN_KEY_CHECKS = 1;


-- ============================================================
--  PASSO 3 — DDL: CRIAÇÃO DAS TABELAS
-- ============================================================

-- ------------------------------------------------------------
--  MÓDULO TRANSVERSAL
-- ------------------------------------------------------------

CREATE TABLE tb_pessoa (
    pk_id_pessoa        INT             NOT NULL AUTO_INCREMENT,
    tipo_pessoa         VARCHAR(20)     NOT NULL COMMENT 'CHECK: ALUNO | PROFESSOR | FUNCIONARIO | RESPONSAVEL',
    primeiro_nome       VARCHAR(60)     NOT NULL,
    sobrenome           VARCHAR(60)     NOT NULL,
    cpf                 VARCHAR(14)     NOT NULL COMMENT 'Formato: XXX.XXX.XXX-XX',
    data_nascimento     DATE            NOT NULL,
    email               VARCHAR(100)    NOT NULL,
    telefone            VARCHAR(20)     NOT NULL,
    endereco            VARCHAR(200)    NOT NULL,
    status              VARCHAR(20)     NOT NULL DEFAULT 'ATIVO' COMMENT 'CHECK: ATIVO | INATIVO',
    data_criacao        TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ultima_atualizacao  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT pk_pessoa        PRIMARY KEY (pk_id_pessoa),
    CONSTRAINT uq_pessoa_cpf    UNIQUE (cpf),
    CONSTRAINT uq_pessoa_email  UNIQUE (email),
    CONSTRAINT ck_pessoa_tipo   CHECK (tipo_pessoa IN ('ALUNO','PROFESSOR','FUNCIONARIO','RESPONSAVEL')),
    CONSTRAINT ck_pessoa_status CHECK (status IN ('ATIVO','INATIVO'))
) COMMENT 'Entidade central de todos os atores do sistema';


-- ------------------------------------------------------------
--  MÓDULO RECURSOS HUMANOS
-- ------------------------------------------------------------

CREATE TABLE tb_funcionario (
    pk_id_funcionario        INT           NOT NULL AUTO_INCREMENT,
    fk_id_pessoa             INT           NOT NULL,
    cargo                    VARCHAR(80)   NOT NULL,
    tipo_vinculo             VARCHAR(30)   NOT NULL COMMENT 'CHECK: CLT | PJ | ESTATUTARIO',
    salario_base             DECIMAL(10,2) NOT NULL,
    carga_horaria_contratual DECIMAL(5,2)  NOT NULL,
    data_admissao            DATE          NOT NULL,
    status_funcionario       VARCHAR(20)   NOT NULL DEFAULT 'ATIVO' COMMENT 'CHECK: ATIVO | INATIVO | AFASTADO',
    data_criacao             TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ultima_atualizacao       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT pk_funcionario         PRIMARY KEY (pk_id_funcionario),
    CONSTRAINT fk_funcionario_pessoa  FOREIGN KEY (fk_id_pessoa)
        REFERENCES tb_pessoa (pk_id_pessoa) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_funcionario_vinculo CHECK (tipo_vinculo IN ('CLT','PJ','ESTATUTARIO')),
    CONSTRAINT ck_funcionario_status  CHECK (status_funcionario IN ('ATIVO','INATIVO','AFASTADO'))
);

CREATE TABLE tb_professor (
    pk_id_professor    INT           NOT NULL AUTO_INCREMENT,
    fk_id_funcionario  INT           NOT NULL,
    formacao_academica VARCHAR(100)  NOT NULL,
    especialidade      VARCHAR(100),
    valor_hora_aula    DECIMAL(8,2)  NOT NULL,

    CONSTRAINT pk_professor              PRIMARY KEY (pk_id_professor),
    CONSTRAINT fk_professor_funcionario  FOREIGN KEY (fk_id_funcionario)
        REFERENCES tb_funcionario (pk_id_funcionario) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE tb_vinculo_prof_disciplina (
    pk_id_vinculo         INT          NOT NULL AUTO_INCREMENT,
    fk_id_professor       INT          NOT NULL,
    fk_id_turma           INT          NOT NULL,
    fk_id_disciplina      INT          NOT NULL,
    carga_horaria_semanal DECIMAL(5,2) NOT NULL,
    status                VARCHAR(20)  NOT NULL DEFAULT 'ATIVO' COMMENT 'CHECK: ATIVO | ENCERRADO',
    data_criacao          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_vinculo          PRIMARY KEY (pk_id_vinculo),
    CONSTRAINT fk_vinculo_professor FOREIGN KEY (fk_id_professor)
        REFERENCES tb_professor (pk_id_professor) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT uq_vinculo          UNIQUE (fk_id_professor, fk_id_turma, fk_id_disciplina),
    CONSTRAINT ck_vinculo_status   CHECK (status IN ('ATIVO','ENCERRADO'))
);


-- ------------------------------------------------------------
--  MÓDULO ACADÊMICO
-- ------------------------------------------------------------

CREATE TABLE tb_aluno (
    pk_id_aluno   INT         NOT NULL AUTO_INCREMENT,
    fk_id_pessoa  INT         NOT NULL,
    rgm           VARCHAR(20) NOT NULL,
    data_ingresso DATE        NOT NULL,

    CONSTRAINT pk_aluno       PRIMARY KEY (pk_id_aluno),
    CONSTRAINT uq_aluno_rgm   UNIQUE (rgm),
    CONSTRAINT fk_aluno_pessoa FOREIGN KEY (fk_id_pessoa)
        REFERENCES tb_pessoa (pk_id_pessoa) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE tb_responsavel (
    fk_id_pessoa INT         NOT NULL,
    fk_id_aluno  INT         NOT NULL,
    parentesco   VARCHAR(30) NOT NULL COMMENT 'CHECK: PAI | MAE | AVO | RESPONSAVEL_LEGAL | OUTRO',

    CONSTRAINT pk_responsavel          PRIMARY KEY (fk_id_pessoa, fk_id_aluno),
    CONSTRAINT fk_responsavel_pessoa   FOREIGN KEY (fk_id_pessoa)
        REFERENCES tb_pessoa (pk_id_pessoa) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_responsavel_aluno    FOREIGN KEY (fk_id_aluno)
        REFERENCES tb_aluno (pk_id_aluno) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_responsavel_parentesco CHECK (parentesco IN ('PAI','MAE','AVO','RESPONSAVEL_LEGAL','OUTRO'))
);

CREATE TABLE tb_curso (
    pk_id_curso         INT          NOT NULL AUTO_INCREMENT,
    nome_curso          VARCHAR(100) NOT NULL,
    nivel_ensino        VARCHAR(30)  NOT NULL COMMENT 'CHECK: FUNDAMENTAL | MEDIO',
    carga_horaria_total INT          NOT NULL,
    status              VARCHAR(20)  NOT NULL DEFAULT 'ATIVO' COMMENT 'CHECK: ATIVO | INATIVO',

    CONSTRAINT pk_curso        PRIMARY KEY (pk_id_curso),
    CONSTRAINT ck_curso_nivel  CHECK (nivel_ensino IN ('FUNDAMENTAL','MEDIO')),
    CONSTRAINT ck_curso_status CHECK (status IN ('ATIVO','INATIVO'))
);

CREATE TABLE tb_turma (
    pk_id_turma       INT         NOT NULL AUTO_INCREMENT,
    fk_id_curso       INT         NOT NULL,
    nome_turma        VARCHAR(50) NOT NULL,
    ano_letivo        INT         NOT NULL,
    turno             VARCHAR(20) NOT NULL COMMENT 'CHECK: MANHA | TARDE | INTEGRAL',
    capacidade_maxima INT         NOT NULL DEFAULT 35,
    status            VARCHAR(20) NOT NULL DEFAULT 'ATIVA' COMMENT 'CHECK: ATIVA | ENCERRADA | SUSPENSA',

    CONSTRAINT pk_turma        PRIMARY KEY (pk_id_turma),
    CONSTRAINT fk_turma_curso  FOREIGN KEY (fk_id_curso)
        REFERENCES tb_curso (pk_id_curso) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_turma_turno  CHECK (turno IN ('MANHA','TARDE','INTEGRAL')),
    CONSTRAINT ck_turma_status CHECK (status IN ('ATIVA','ENCERRADA','SUSPENSA'))
);

CREATE TABLE tb_disciplina (
    pk_id_disciplina INT          NOT NULL AUTO_INCREMENT,
    fk_id_curso      INT          NOT NULL,
    nome_disciplina  VARCHAR(100) NOT NULL,
    carga_horaria    INT          NOT NULL,
    status           VARCHAR(20)  NOT NULL DEFAULT 'ATIVA' COMMENT 'CHECK: ATIVA | INATIVA',

    CONSTRAINT pk_disciplina        PRIMARY KEY (pk_id_disciplina),
    CONSTRAINT fk_disciplina_curso  FOREIGN KEY (fk_id_curso)
        REFERENCES tb_curso (pk_id_curso) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_disciplina_status CHECK (status IN ('ATIVA','INATIVA'))
);

CREATE TABLE tb_grade_curricular (
    fk_id_turma           INT          NOT NULL,
    fk_id_disciplina      INT          NOT NULL,
    carga_horaria_semanal DECIMAL(5,2) NOT NULL,
    status                VARCHAR(20)  NOT NULL DEFAULT 'ATIVA' COMMENT 'CHECK: ATIVA | INATIVA',

    CONSTRAINT pk_grade          PRIMARY KEY (fk_id_turma, fk_id_disciplina),
    CONSTRAINT fk_grade_turma    FOREIGN KEY (fk_id_turma)
        REFERENCES tb_turma (pk_id_turma) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_grade_disciplina FOREIGN KEY (fk_id_disciplina)
        REFERENCES tb_disciplina (pk_id_disciplina) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_grade_status   CHECK (status IN ('ATIVA','INATIVA'))
);

-- FK composta de vinculo adicionada após grade existir
ALTER TABLE tb_vinculo_prof_disciplina
    ADD CONSTRAINT fk_vinculo_grade FOREIGN KEY (fk_id_turma, fk_id_disciplina)
        REFERENCES tb_grade_curricular (fk_id_turma, fk_id_disciplina)
        ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE tb_parametro_avaliacao (
    pk_id_parametro INT          NOT NULL AUTO_INCREMENT,
    fk_id_curso     INT          NOT NULL,
    descricao       VARCHAR(60)  NOT NULL,
    peso            DECIMAL(4,2) NOT NULL DEFAULT 1.0,
    ordem           INT          NOT NULL,
    ano_letivo      INT          NOT NULL,

    CONSTRAINT pk_parametro       PRIMARY KEY (pk_id_parametro),
    CONSTRAINT fk_parametro_curso FOREIGN KEY (fk_id_curso)
        REFERENCES tb_curso (pk_id_curso) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT uq_parametro       UNIQUE (fk_id_curso, ordem, ano_letivo)
);

CREATE TABLE tb_matricula (
    pk_id_matricula    INT         NOT NULL AUTO_INCREMENT,
    fk_id_aluno        INT         NOT NULL,
    fk_id_turma        INT         NOT NULL,
    data_matricula     DATE        NOT NULL,
    status_matricula   VARCHAR(20) NOT NULL DEFAULT 'ATIVA' COMMENT 'CHECK: ATIVA | TRANCADA | CANCELADA | CONCLUIDA',
    data_criacao       TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ultima_atualizacao TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT pk_matricula        PRIMARY KEY (pk_id_matricula),
    CONSTRAINT uq_matricula        UNIQUE (fk_id_aluno, fk_id_turma),
    CONSTRAINT fk_matricula_aluno  FOREIGN KEY (fk_id_aluno)
        REFERENCES tb_aluno (pk_id_aluno) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_matricula_turma  FOREIGN KEY (fk_id_turma)
        REFERENCES tb_turma (pk_id_turma) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_matricula_status CHECK (status_matricula IN ('ATIVA','TRANCADA','CANCELADA','CONCLUIDA'))
);

CREATE TABLE tb_nota (
    pk_id_nota         INT          NOT NULL AUTO_INCREMENT,
    fk_id_matricula    INT          NOT NULL,
    fk_id_turma        INT          NOT NULL,
    fk_id_disciplina   INT          NOT NULL,
    fk_id_parametro    INT          NOT NULL,
    valor_nota         DECIMAL(4,2) NOT NULL,
    status_aprovacao   VARCHAR(20)  COMMENT 'CHECK: APROVADO | REPROVADO | EM_ANDAMENTO',
    ultima_atualizacao TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT pk_nota           PRIMARY KEY (pk_id_nota),
    CONSTRAINT uq_nota           UNIQUE (fk_id_matricula, fk_id_disciplina, fk_id_parametro),
    CONSTRAINT fk_nota_matricula FOREIGN KEY (fk_id_matricula)
        REFERENCES tb_matricula (pk_id_matricula) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_nota_parametro FOREIGN KEY (fk_id_parametro)
        REFERENCES tb_parametro_avaliacao (pk_id_parametro) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_nota_grade     FOREIGN KEY (fk_id_turma, fk_id_disciplina)
        REFERENCES tb_grade_curricular (fk_id_turma, fk_id_disciplina) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_nota_valor     CHECK (valor_nota BETWEEN 0.00 AND 10.00),
    CONSTRAINT ck_nota_aprovacao CHECK (status_aprovacao IN ('APROVADO','REPROVADO','EM_ANDAMENTO'))
);

CREATE TABLE tb_frequencia (
    pk_id_frequencia INT         NOT NULL AUTO_INCREMENT,
    fk_id_matricula  INT         NOT NULL,
    fk_id_turma      INT         NOT NULL,
    fk_id_disciplina INT         NOT NULL,
    data_aula        DATE        NOT NULL,
    status_presenca  VARCHAR(20) NOT NULL COMMENT 'CHECK: PRESENTE | AUSENTE | JUSTIFICADO',
    data_criacao     TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_frequencia         PRIMARY KEY (pk_id_frequencia),
    CONSTRAINT uq_frequencia         UNIQUE (fk_id_matricula, fk_id_disciplina, data_aula),
    CONSTRAINT fk_frequencia_matricula FOREIGN KEY (fk_id_matricula)
        REFERENCES tb_matricula (pk_id_matricula) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_frequencia_grade   FOREIGN KEY (fk_id_turma, fk_id_disciplina)
        REFERENCES tb_grade_curricular (fk_id_turma, fk_id_disciplina) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_frequencia_status  CHECK (status_presenca IN ('PRESENTE','AUSENTE','JUSTIFICADO'))
);

CREATE TABLE tb_calendario_letivo (
    pk_id_calendario INT          NOT NULL AUTO_INCREMENT,
    fk_id_turma      INT          NOT NULL,
    data             DATE         NOT NULL,
    tipo             VARCHAR(20)  NOT NULL COMMENT 'CHECK: DIA_LETIVO | FERIADO | RECESSO | EVENTO',
    descricao        VARCHAR(100),

    CONSTRAINT pk_calendario       PRIMARY KEY (pk_id_calendario),
    CONSTRAINT uq_calendario       UNIQUE (fk_id_turma, data),
    CONSTRAINT fk_calendario_turma FOREIGN KEY (fk_id_turma)
        REFERENCES tb_turma (pk_id_turma) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_calendario_tipo  CHECK (tipo IN ('DIA_LETIVO','FERIADO','RECESSO','EVENTO'))
);

CREATE TABLE tb_historico_status_matricula (
    pk_id_historico   INT          NOT NULL AUTO_INCREMENT,
    fk_id_matricula   INT          NOT NULL,
    fk_id_funcionario INT          NOT NULL,
    status_anterior   VARCHAR(20)  NOT NULL,
    status_novo       VARCHAR(20)  NOT NULL,
    data_alteracao    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    observacao        VARCHAR(200),

    CONSTRAINT pk_historico              PRIMARY KEY (pk_id_historico),
    CONSTRAINT fk_historico_matricula    FOREIGN KEY (fk_id_matricula)
        REFERENCES tb_matricula (pk_id_matricula) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_historico_funcionario  FOREIGN KEY (fk_id_funcionario)
        REFERENCES tb_funcionario (pk_id_funcionario) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE tb_documento_aluno (
    pk_id_documento INT          NOT NULL AUTO_INCREMENT,
    fk_id_aluno     INT          NOT NULL,
    tipo_documento  VARCHAR(40)  NOT NULL COMMENT 'CHECK: RG | CPF | CERTIDAO_NASCIMENTO | COMPROVANTE_RESIDENCIA | LAUDO | OUTRO',
    caminho_arquivo VARCHAR(200) NOT NULL,
    data_upload     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status          VARCHAR(20)  NOT NULL DEFAULT 'PENDENTE' COMMENT 'CHECK: PENDENTE | VALIDADO | REJEITADO',

    CONSTRAINT pk_documento        PRIMARY KEY (pk_id_documento),
    CONSTRAINT fk_documento_aluno  FOREIGN KEY (fk_id_aluno)
        REFERENCES tb_aluno (pk_id_aluno) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_documento_tipo   CHECK (tipo_documento IN ('RG','CPF','CERTIDAO_NASCIMENTO','COMPROVANTE_RESIDENCIA','LAUDO','OUTRO')),
    CONSTRAINT ck_documento_status CHECK (status IN ('PENDENTE','VALIDADO','REJEITADO'))
);

CREATE TABLE tb_ocorrencia_disciplinar (
    pk_id_ocorrencia    INT          NOT NULL AUTO_INCREMENT,
    fk_id_aluno         INT          NOT NULL,
    fk_id_funcionario   INT          NOT NULL,
    tipo                VARCHAR(20)  NOT NULL COMMENT 'CHECK: ADVERTENCIA | SUSPENSAO | ELOGIO | OUTRO',
    descricao           VARCHAR(300) NOT NULL,
    data_ocorrencia     DATE         NOT NULL,
    ciencia_responsavel BOOLEAN      NOT NULL DEFAULT FALSE,
    data_criacao        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_ocorrencia              PRIMARY KEY (pk_id_ocorrencia),
    CONSTRAINT fk_ocorrencia_aluno        FOREIGN KEY (fk_id_aluno)
        REFERENCES tb_aluno (pk_id_aluno) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_ocorrencia_funcionario  FOREIGN KEY (fk_id_funcionario)
        REFERENCES tb_funcionario (pk_id_funcionario) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_ocorrencia_tipo         CHECK (tipo IN ('ADVERTENCIA','SUSPENSAO','ELOGIO','OUTRO'))
);


-- ------------------------------------------------------------
--  MÓDULO FINANCEIRO
-- ------------------------------------------------------------

CREATE TABLE tb_contrato_educacional (
    pk_id_contrato           INT           NOT NULL AUTO_INCREMENT,
    fk_id_matricula          INT           NOT NULL,
    fk_id_responsavel_pessoa INT           NOT NULL,
    fk_id_responsavel_aluno  INT           NOT NULL,
    data_inicio              DATE          NOT NULL,
    data_fim                 DATE          NOT NULL,
    valor_mensalidade        DECIMAL(10,2) NOT NULL,
    desconto_percentual      DECIMAL(5,2)  NOT NULL DEFAULT 0,
    total_parcelas           INT           NOT NULL,
    status_contrato          VARCHAR(20)   NOT NULL DEFAULT 'ATIVO' COMMENT 'CHECK: ATIVO | SUSPENSO | ENCERRADO | CANCELADO',
    data_criacao             TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ultima_atualizacao       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT pk_contrato             PRIMARY KEY (pk_id_contrato),
    CONSTRAINT uq_contrato_matricula   UNIQUE (fk_id_matricula),
    CONSTRAINT fk_contrato_matricula   FOREIGN KEY (fk_id_matricula)
        REFERENCES tb_matricula (pk_id_matricula) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_contrato_responsavel FOREIGN KEY (fk_id_responsavel_pessoa, fk_id_responsavel_aluno)
        REFERENCES tb_responsavel (fk_id_pessoa, fk_id_aluno) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_contrato_status      CHECK (status_contrato IN ('ATIVO','SUSPENSO','ENCERRADO','CANCELADO'))
);

CREATE TABLE tb_mensalidade (
    pk_id_mensalidade  INT           NOT NULL AUTO_INCREMENT,
    fk_id_contrato     INT           NOT NULL,
    numero_parcela     INT           NOT NULL,
    data_vencimento    DATE          NOT NULL,
    valor_original     DECIMAL(10,2) NOT NULL,
    valor_desconto     DECIMAL(10,2) NOT NULL DEFAULT 0,
    status_mensalidade VARCHAR(20)   NOT NULL DEFAULT 'PENDENTE' COMMENT 'CHECK: PENDENTE | PAGO | INADIMPLENTE | ISENTO',
    ultima_atualizacao TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT pk_mensalidade          PRIMARY KEY (pk_id_mensalidade),
    CONSTRAINT uq_mensalidade          UNIQUE (fk_id_contrato, numero_parcela),
    CONSTRAINT fk_mensalidade_contrato FOREIGN KEY (fk_id_contrato)
        REFERENCES tb_contrato_educacional (pk_id_contrato) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_mensalidade_status   CHECK (status_mensalidade IN ('PENDENTE','PAGO','INADIMPLENTE','ISENTO'))
);

CREATE TABLE tb_pagamento (
    pk_id_pagamento   INT           NOT NULL AUTO_INCREMENT,
    fk_id_mensalidade INT           NOT NULL,
    data_pagamento    DATE          NOT NULL,
    valor_pago        DECIMAL(10,2) NOT NULL,
    forma_pagamento   VARCHAR(30)   NOT NULL COMMENT 'CHECK: PIX | BOLETO | CARTAO_CREDITO | CARTAO_DEBITO | DINHEIRO',
    comprovante       VARCHAR(100),
    data_criacao      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_pagamento            PRIMARY KEY (pk_id_pagamento),
    CONSTRAINT fk_pagamento_mensalidade FOREIGN KEY (fk_id_mensalidade)
        REFERENCES tb_mensalidade (pk_id_mensalidade) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_pagamento_forma      CHECK (forma_pagamento IN ('PIX','BOLETO','CARTAO_CREDITO','CARTAO_DEBITO','DINHEIRO'))
);

CREATE TABLE tb_inadimplencia (
    pk_id_inadimplencia     INT         NOT NULL AUTO_INCREMENT,
    fk_id_contrato          INT         NOT NULL,
    qtd_mensalidades_atraso INT         NOT NULL DEFAULT 0,
    data_primeiro_atraso    DATE        NOT NULL,
    status_negociacao       VARCHAR(30) NOT NULL DEFAULT 'PENDENTE' COMMENT 'CHECK: PENDENTE | EM_NEGOCIACAO | REGULARIZADO',
    ultima_atualizacao      TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT pk_inadimplencia          PRIMARY KEY (pk_id_inadimplencia),
    CONSTRAINT fk_inadimplencia_contrato FOREIGN KEY (fk_id_contrato)
        REFERENCES tb_contrato_educacional (pk_id_contrato) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_inadimplencia_status   CHECK (status_negociacao IN ('PENDENTE','EM_NEGOCIACAO','REGULARIZADO'))
);

CREATE TABLE tb_conta_pagar (
    pk_id_conta_pagar  INT           NOT NULL AUTO_INCREMENT,
    fk_id_vinculo      INT           NULL COMMENT 'NULL para funcionários sem vínculo docente',
    fk_id_funcionario  INT           NOT NULL,
    descricao          VARCHAR(150)  NOT NULL,
    valor              DECIMAL(10,2) NOT NULL,
    data_vencimento    DATE          NOT NULL,
    data_pagamento     DATE          NULL,
    status_pagamento   VARCHAR(20)   NOT NULL DEFAULT 'PENDENTE' COMMENT 'CHECK: PENDENTE | PAGO | CANCELADO',
    tipo_provento      VARCHAR(40)   NOT NULL COMMENT 'CHECK: HORA_AULA | SALARIO | BONUS | ENCARGO',
    data_criacao       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ultima_atualizacao TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT pk_conta_pagar      PRIMARY KEY (pk_id_conta_pagar),
    CONSTRAINT fk_conta_vinculo    FOREIGN KEY (fk_id_vinculo)
        REFERENCES tb_vinculo_prof_disciplina (pk_id_vinculo) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_conta_funcionario FOREIGN KEY (fk_id_funcionario)
        REFERENCES tb_funcionario (pk_id_funcionario) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_conta_status     CHECK (status_pagamento IN ('PENDENTE','PAGO','CANCELADO')),
    CONSTRAINT ck_conta_provento   CHECK (tipo_provento IN ('HORA_AULA','SALARIO','BONUS','ENCARGO'))
);


-- ============================================================
--  PASSO 4 — DML: CARGA DE DADOS (INSERT IGNORE = idempotente)
-- ============================================================

-- ------------------------------------------------------------
--  CONTAGEM ANTES DA CARGA
-- ------------------------------------------------------------
SELECT 'CONTAGEM ANTES DA CARGA' AS momento;
SELECT 'tb_pessoa'                     AS tabela, COUNT(*) AS total FROM tb_pessoa          UNION ALL
SELECT 'tb_funcionario',                           COUNT(*) FROM tb_funcionario             UNION ALL
SELECT 'tb_professor',                             COUNT(*) FROM tb_professor               UNION ALL
SELECT 'tb_vinculo_prof_disciplina',               COUNT(*) FROM tb_vinculo_prof_disciplina UNION ALL
SELECT 'tb_aluno',                                 COUNT(*) FROM tb_aluno                   UNION ALL
SELECT 'tb_responsavel',                           COUNT(*) FROM tb_responsavel             UNION ALL
SELECT 'tb_curso',                                 COUNT(*) FROM tb_curso                   UNION ALL
SELECT 'tb_turma',                                 COUNT(*) FROM tb_turma                   UNION ALL
SELECT 'tb_disciplina',                            COUNT(*) FROM tb_disciplina              UNION ALL
SELECT 'tb_grade_curricular',                      COUNT(*) FROM tb_grade_curricular        UNION ALL
SELECT 'tb_parametro_avaliacao',                   COUNT(*) FROM tb_parametro_avaliacao     UNION ALL
SELECT 'tb_matricula',                             COUNT(*) FROM tb_matricula               UNION ALL
SELECT 'tb_nota',                                  COUNT(*) FROM tb_nota                    UNION ALL
SELECT 'tb_frequencia',                            COUNT(*) FROM tb_frequencia              UNION ALL
SELECT 'tb_calendario_letivo',                     COUNT(*) FROM tb_calendario_letivo       UNION ALL
SELECT 'tb_historico_status_matricula',            COUNT(*) FROM tb_historico_status_matricula UNION ALL
SELECT 'tb_documento_aluno',                       COUNT(*) FROM tb_documento_aluno         UNION ALL
SELECT 'tb_ocorrencia_disciplinar',                COUNT(*) FROM tb_ocorrencia_disciplinar  UNION ALL
SELECT 'tb_contrato_educacional',                  COUNT(*) FROM tb_contrato_educacional    UNION ALL
SELECT 'tb_mensalidade',                           COUNT(*) FROM tb_mensalidade             UNION ALL
SELECT 'tb_pagamento',                             COUNT(*) FROM tb_pagamento               UNION ALL
SELECT 'tb_inadimplencia',                         COUNT(*) FROM tb_inadimplencia           UNION ALL
SELECT 'tb_conta_pagar',                           COUNT(*) FROM tb_conta_pagar;

-- ------------------------------------------------------------
--  MÓDULO TRANSVERSAL — tb_pessoa (22 registros)
-- ------------------------------------------------------------
INSERT IGNORE INTO tb_pessoa
    (pk_id_pessoa, tipo_pessoa, primeiro_nome, sobrenome, cpf, data_nascimento, email, telefone, endereco, status)
VALUES
(1,  'ALUNO',       'Lucas',    'Oliveira',   '111.111.111-01', '2010-03-15', 'lucas.oliveira@aluno.sisgesc.br',    '(11)91111-0001', 'Rua das Flores, 10, São Paulo - SP',      'ATIVO'),
(2,  'ALUNO',       'Mariana',  'Santos',     '111.111.111-02', '2009-07-22', 'mariana.santos@aluno.sisgesc.br',    '(11)91111-0002', 'Av. Paulista, 200, São Paulo - SP',       'ATIVO'),
(3,  'ALUNO',       'Pedro',    'Costa',      '111.111.111-03', '2010-01-10', 'pedro.costa@aluno.sisgesc.br',       '(11)91111-0003', 'Rua Augusta, 350, São Paulo - SP',        'ATIVO'),
(4,  'ALUNO',       'Beatriz',  'Lima',       '111.111.111-04', '2008-11-05', 'beatriz.lima@aluno.sisgesc.br',      '(11)91111-0004', 'Rua Oscar Freire, 80, São Paulo - SP',    'ATIVO'),
(5,  'ALUNO',       'Rafael',   'Ferreira',   '111.111.111-05', '2009-04-18', 'rafael.ferreira@aluno.sisgesc.br',   '(11)91111-0005', 'Alameda Santos, 120, São Paulo - SP',     'ATIVO'),
(6,  'ALUNO',       'Camila',   'Rodrigues',  '111.111.111-06', '2010-09-30', 'camila.rodrigues@aluno.sisgesc.br',  '(11)91111-0006', 'Rua Consolação, 55, São Paulo - SP',      'ATIVO'),
(7,  'ALUNO',       'Gabriel',  'Alves',      '111.111.111-07', '2008-06-14', 'gabriel.alves@aluno.sisgesc.br',     '(11)91111-0007', 'Rua da Liberdade, 300, São Paulo - SP',   'ATIVO'),
(8,  'ALUNO',       'Julia',    'Nascimento', '111.111.111-08', '2009-12-01', 'julia.nascimento@aluno.sisgesc.br',  '(11)91111-0008', 'Av. Brigadeiro Faria Lima, 10, SP',       'INATIVO'),
(9,  'PROFESSOR',   'Carlos',   'Mendes',     '222.222.222-01', '1980-05-20', 'carlos.mendes@prof.sisgesc.br',      '(11)92222-0001', 'Rua Vergueiro, 400, São Paulo - SP',      'ATIVO'),
(10, 'PROFESSOR',   'Ana',      'Pereira',    '222.222.222-02', '1975-08-14', 'ana.pereira@prof.sisgesc.br',        '(11)92222-0002', 'Rua Tutóia, 210, São Paulo - SP',         'ATIVO'),
(11, 'PROFESSOR',   'Roberto',  'Souza',      '222.222.222-03', '1982-02-28', 'roberto.souza@prof.sisgesc.br',      '(11)92222-0003', 'Av. Rebouças, 600, São Paulo - SP',       'ATIVO'),
(12, 'FUNCIONARIO', 'Fernanda', 'Gomes',      '333.333.333-01', '1985-10-10', 'fernanda.gomes@adm.sisgesc.br',      '(11)93333-0001', 'Rua Frei Caneca, 90, São Paulo - SP',     'ATIVO'),
(13, 'FUNCIONARIO', 'Marcos',   'Barbosa',    '333.333.333-02', '1978-03-25', 'marcos.barbosa@adm.sisgesc.br',      '(11)93333-0002', 'Rua da Consolação, 700, São Paulo - SP',  'ATIVO'),
(14, 'FUNCIONARIO', 'Patricia', 'Cardoso',    '333.333.333-03', '1990-07-07', 'patricia.cardoso@adm.sisgesc.br',    '(11)93333-0003', 'Av. São João, 150, São Paulo - SP',       'ATIVO'),
(15, 'RESPONSAVEL', 'Paulo',    'Oliveira',   '444.444.444-01', '1978-01-10', 'paulo.oliveira@resp.sisgesc.br',     '(11)94444-0001', 'Rua das Flores, 10, São Paulo - SP',      'ATIVO'),
(16, 'RESPONSAVEL', 'Sandra',   'Santos',     '444.444.444-02', '1975-05-30', 'sandra.santos@resp.sisgesc.br',      '(11)94444-0002', 'Av. Paulista, 200, São Paulo - SP',       'ATIVO'),
(17, 'RESPONSAVEL', 'Marcos',   'Costa',      '444.444.444-03', '1980-09-12', 'marcos.costa@resp.sisgesc.br',       '(11)94444-0003', 'Rua Augusta, 350, São Paulo - SP',        'ATIVO'),
(18, 'RESPONSAVEL', 'Renata',   'Lima',       '444.444.444-04', '1977-03-22', 'renata.lima@resp.sisgesc.br',        '(11)94444-0004', 'Rua Oscar Freire, 80, São Paulo - SP',    'ATIVO'),
(19, 'RESPONSAVEL', 'José',     'Ferreira',   '444.444.444-05', '1975-11-08', 'jose.ferreira@resp.sisgesc.br',      '(11)94444-0005', 'Alameda Santos, 120, São Paulo - SP',     'ATIVO'),
(20, 'RESPONSAVEL', 'Luciana',  'Rodrigues',  '444.444.444-06', '1983-06-18', 'luciana.rodrigues@resp.sisgesc.br',  '(11)94444-0006', 'Rua Consolação, 55, São Paulo - SP',      'ATIVO'),
(21, 'RESPONSAVEL', 'Eduardo',  'Alves',      '444.444.444-07', '1979-08-25', 'eduardo.alves@resp.sisgesc.br',      '(11)94444-0007', 'Rua da Liberdade, 300, São Paulo - SP',   'ATIVO'),
(22, 'RESPONSAVEL', 'Cristina', 'Nascimento', '444.444.444-08', '1981-04-14', 'cristina.nascimento@resp.sisgesc.br','(11)94444-0008', 'Av. Brigadeiro Faria Lima, 10, SP',       'ATIVO');

-- ------------------------------------------------------------
--  MÓDULO RH
-- ------------------------------------------------------------
INSERT IGNORE INTO tb_funcionario
    (pk_id_funcionario, fk_id_pessoa, cargo, tipo_vinculo, salario_base, carga_horaria_contratual, data_admissao, status_funcionario)
VALUES
(1, 9,  'Professor',               'CLT', 5500.00, 40.00, '2018-02-01', 'ATIVO'),
(2, 10, 'Professor',               'CLT', 6200.00, 40.00, '2015-03-01', 'ATIVO'),
(3, 11, 'Professor',               'PJ',  4800.00, 30.00, '2020-07-01', 'ATIVO'),
(4, 12, 'Coordenadora Pedagógica', 'CLT', 7000.00, 40.00, '2016-01-15', 'ATIVO'),
(5, 13, 'Secretário',              'CLT', 3500.00, 40.00, '2019-05-10', 'ATIVO'),
(6, 14, 'Auxiliar Administrativo', 'CLT', 2800.00, 40.00, '2021-08-01', 'ATIVO');

INSERT IGNORE INTO tb_professor
    (pk_id_professor, fk_id_funcionario, formacao_academica, especialidade, valor_hora_aula)
VALUES
(1, 1, 'Licenciatura em Matemática', 'Álgebra e Geometria',   85.00),
(2, 2, 'Licenciatura em Letras',     'Literatura Brasileira', 90.00),
(3, 3, 'Licenciatura em Ciências',   'Biologia e Química',    80.00);

-- ------------------------------------------------------------
--  MÓDULO ACADÊMICO
-- ------------------------------------------------------------
INSERT IGNORE INTO tb_curso
    (pk_id_curso, nome_curso, nivel_ensino, carga_horaria_total, status)
VALUES
(1, 'Ensino Fundamental II', 'FUNDAMENTAL', 3400, 'ATIVO'),
(2, 'Ensino Médio',          'MEDIO',       2400, 'ATIVO');

INSERT IGNORE INTO tb_turma
    (pk_id_turma, fk_id_curso, nome_turma, ano_letivo, turno, capacidade_maxima, status)
VALUES
(1, 1, '8º Ano A', 2025, 'MANHA',    35, 'ATIVA'),
(2, 1, '9º Ano B', 2025, 'TARDE',    35, 'ATIVA'),
(3, 2, '1º EM A',  2025, 'INTEGRAL', 30, 'ATIVA');

INSERT IGNORE INTO tb_disciplina
    (pk_id_disciplina, fk_id_curso, nome_disciplina, carga_horaria, status)
VALUES
(1, 1, 'Matemática',        120, 'ATIVA'),
(2, 1, 'Língua Portuguesa', 120, 'ATIVA'),
(3, 1, 'Ciências',           80, 'ATIVA'),
(4, 2, 'Matemática',        120, 'ATIVA'),
(5, 2, 'Língua Portuguesa', 120, 'ATIVA'),
(6, 2, 'Biologia',           80, 'ATIVA');

INSERT IGNORE INTO tb_grade_curricular
    (fk_id_turma, fk_id_disciplina, carga_horaria_semanal, status)
VALUES
(1, 1, 5.00, 'ATIVA'), (1, 2, 5.00, 'ATIVA'), (1, 3, 3.00, 'ATIVA'),
(2, 1, 5.00, 'ATIVA'), (2, 2, 5.00, 'ATIVA'), (2, 3, 3.00, 'ATIVA'),
(3, 4, 5.00, 'ATIVA'), (3, 5, 5.00, 'ATIVA'), (3, 6, 3.00, 'ATIVA');

INSERT IGNORE INTO tb_vinculo_prof_disciplina
    (pk_id_vinculo, fk_id_professor, fk_id_turma, fk_id_disciplina, carga_horaria_semanal, status)
VALUES
(1, 1, 1, 1, 5.00, 'ATIVO'), (2, 1, 2, 1, 5.00, 'ATIVO'), (3, 1, 3, 4, 5.00, 'ATIVO'),
(4, 2, 1, 2, 5.00, 'ATIVO'), (5, 2, 2, 2, 5.00, 'ATIVO'), (6, 2, 3, 5, 5.00, 'ATIVO'),
(7, 3, 1, 3, 3.00, 'ATIVO'), (8, 3, 2, 3, 3.00, 'ATIVO'), (9, 3, 3, 6, 3.00, 'ATIVO');

INSERT IGNORE INTO tb_parametro_avaliacao
    (pk_id_parametro, fk_id_curso, descricao, peso, ordem, ano_letivo)
VALUES
(1, 1, '1º Bimestre', 1.00, 1, 2025), (2, 1, '2º Bimestre', 1.00, 2, 2025),
(3, 1, '3º Bimestre', 1.00, 3, 2025), (4, 1, '4º Bimestre', 1.00, 4, 2025),
(5, 2, '1º Bimestre', 1.00, 1, 2025), (6, 2, '2º Bimestre', 1.00, 2, 2025),
(7, 2, '3º Bimestre', 1.00, 3, 2025), (8, 2, '4º Bimestre', 1.00, 4, 2025);

INSERT IGNORE INTO tb_aluno
    (pk_id_aluno, fk_id_pessoa, rgm, data_ingresso)
VALUES
(1, 1, 'RGM-2025-001', '2022-02-01'), (2, 2, 'RGM-2025-002', '2021-02-01'),
(3, 3, 'RGM-2025-003', '2022-02-01'), (4, 4, 'RGM-2025-004', '2020-02-01'),
(5, 5, 'RGM-2025-005', '2021-02-01'), (6, 6, 'RGM-2025-006', '2022-02-01'),
(7, 7, 'RGM-2025-007', '2020-02-01'), (8, 8, 'RGM-2025-008', '2021-02-01');

INSERT IGNORE INTO tb_responsavel (fk_id_pessoa, fk_id_aluno, parentesco) VALUES
(15,1,'PAI'),(16,2,'MAE'),(17,3,'PAI'),(18,4,'MAE'),
(19,5,'PAI'),(20,6,'MAE'),(21,7,'PAI'),(22,8,'MAE');

INSERT IGNORE INTO tb_matricula
    (pk_id_matricula, fk_id_aluno, fk_id_turma, data_matricula, status_matricula)
VALUES
(1,1,1,'2025-02-01','ATIVA'),  (2,2,1,'2025-02-01','ATIVA'),
(3,3,1,'2025-02-01','ATIVA'),  (4,4,1,'2025-02-01','TRANCADA'),
(5,5,2,'2025-02-01','ATIVA'),  (6,6,2,'2025-02-01','ATIVA'),
(7,7,3,'2025-02-01','ATIVA'),  (8,8,3,'2025-02-01','CANCELADA');

INSERT IGNORE INTO tb_nota
    (pk_id_nota, fk_id_matricula, fk_id_turma, fk_id_disciplina, fk_id_parametro, valor_nota, status_aprovacao)
VALUES
(1, 1,1,1,1,7.50,'EM_ANDAMENTO'),(2, 1,1,1,2,8.00,'EM_ANDAMENTO'),
(3, 1,1,2,1,6.50,'EM_ANDAMENTO'),(4, 1,1,2,2,7.00,'EM_ANDAMENTO'),
(5, 1,1,3,1,9.00,'EM_ANDAMENTO'),(6, 1,1,3,2,8.50,'EM_ANDAMENTO'),
(7, 2,1,1,1,9.50,'EM_ANDAMENTO'),(8, 2,1,1,2,9.00,'EM_ANDAMENTO'),
(9, 2,1,2,1,8.50,'EM_ANDAMENTO'),(10,2,1,2,2,9.00,'EM_ANDAMENTO'),
(11,2,1,3,1,7.00,'EM_ANDAMENTO'),(12,2,1,3,2,7.50,'EM_ANDAMENTO'),
(13,3,1,1,1,5.00,'EM_ANDAMENTO'),(14,3,1,1,2,4.50,'EM_ANDAMENTO'),
(15,3,1,2,1,6.00,'EM_ANDAMENTO'),(16,3,1,2,2,5.50,'EM_ANDAMENTO'),
(17,3,1,3,1,4.00,'EM_ANDAMENTO'),(18,3,1,3,2,5.00,'EM_ANDAMENTO'),
(19,5,2,1,1,8.00,'EM_ANDAMENTO'),(20,5,2,1,2,7.50,'EM_ANDAMENTO'),
(21,5,2,2,1,7.00,'EM_ANDAMENTO'),(22,5,2,2,2,8.00,'EM_ANDAMENTO'),
(23,5,2,3,1,6.50,'EM_ANDAMENTO'),(24,5,2,3,2,7.00,'EM_ANDAMENTO'),
(25,6,2,1,1,6.00,'EM_ANDAMENTO'),(26,6,2,1,2,5.50,'EM_ANDAMENTO'),
(27,6,2,2,1,7.50,'EM_ANDAMENTO'),(28,6,2,2,2,8.00,'EM_ANDAMENTO'),
(29,6,2,3,1,5.00,'EM_ANDAMENTO'),(30,6,2,3,2,6.00,'EM_ANDAMENTO'),
(31,7,3,4,5,8.50,'EM_ANDAMENTO'),(32,7,3,4,6,9.00,'EM_ANDAMENTO'),
(33,7,3,5,5,7.00,'EM_ANDAMENTO'),(34,7,3,5,6,7.50,'EM_ANDAMENTO'),
(35,7,3,6,5,8.00,'EM_ANDAMENTO'),(36,7,3,6,6,8.50,'EM_ANDAMENTO');

INSERT IGNORE INTO tb_frequencia
    (pk_id_frequencia, fk_id_matricula, fk_id_turma, fk_id_disciplina, data_aula, status_presenca)
VALUES
(1, 1,1,1,'2025-02-10','PRESENTE'),(2, 1,1,1,'2025-02-17','PRESENTE'),
(3, 1,1,1,'2025-02-24','AUSENTE'), (4, 1,1,1,'2025-03-03','PRESENTE'),
(5, 1,1,1,'2025-03-10','PRESENTE'),(6, 1,1,2,'2025-02-11','PRESENTE'),
(7, 1,1,2,'2025-02-18','AUSENTE'), (8, 1,1,2,'2025-02-25','PRESENTE'),
(9, 1,1,2,'2025-03-04','JUSTIFICADO'),(10,1,1,2,'2025-03-11','PRESENTE'),
(11,2,1,1,'2025-02-10','PRESENTE'),(12,2,1,1,'2025-02-17','PRESENTE'),
(13,2,1,1,'2025-02-24','PRESENTE'),(14,2,1,1,'2025-03-03','PRESENTE'),
(15,2,1,1,'2025-03-10','PRESENTE'),(16,3,1,1,'2025-02-10','AUSENTE'),
(17,3,1,1,'2025-02-17','AUSENTE'), (18,3,1,1,'2025-02-24','AUSENTE'),
(19,3,1,1,'2025-03-03','PRESENTE'),(20,3,1,1,'2025-03-10','AUSENTE'),
(21,5,2,1,'2025-02-10','PRESENTE'),(22,5,2,1,'2025-02-17','PRESENTE'),
(23,5,2,1,'2025-02-24','PRESENTE'),(24,5,2,1,'2025-03-03','AUSENTE'),
(25,5,2,1,'2025-03-10','PRESENTE'),(26,6,2,1,'2025-02-10','PRESENTE'),
(27,6,2,1,'2025-02-17','AUSENTE'), (28,6,2,1,'2025-02-24','AUSENTE'),
(29,6,2,1,'2025-03-03','PRESENTE'),(30,6,2,1,'2025-03-10','PRESENTE'),
(31,7,3,4,'2025-02-10','PRESENTE'),(32,7,3,4,'2025-02-17','PRESENTE'),
(33,7,3,4,'2025-02-24','PRESENTE'),(34,7,3,4,'2025-03-03','PRESENTE'),
(35,7,3,4,'2025-03-10','AUSENTE');

INSERT IGNORE INTO tb_calendario_letivo
    (pk_id_calendario, fk_id_turma, data, tipo, descricao)
VALUES
(1,1,'2025-02-10','DIA_LETIVO','Início do 1º Bimestre'),
(2,1,'2025-04-18','FERIADO',  'Sexta-feira Santa'),
(3,1,'2025-06-19','RECESSO',  'Recesso Junino'),
(4,2,'2025-02-10','DIA_LETIVO','Início do 1º Bimestre'),
(5,2,'2025-04-18','FERIADO',  'Sexta-feira Santa'),
(6,3,'2025-02-10','DIA_LETIVO','Início do 1º Bimestre'),
(7,3,'2025-06-12','EVENTO',   'Feira de Ciências');

INSERT IGNORE INTO tb_historico_status_matricula
    (pk_id_historico, fk_id_matricula, fk_id_funcionario, status_anterior, status_novo, observacao)
VALUES
(1,4,4,'ATIVA','TRANCADA', 'Solicitação da família por motivo de saúde'),
(2,8,4,'ATIVA','CANCELADA','Transferência para outra instituição');

INSERT IGNORE INTO tb_documento_aluno
    (pk_id_documento, fk_id_aluno, tipo_documento, caminho_arquivo, status)
VALUES
(1,1,'RG',                    '/docs/aluno1/rg.pdf',          'VALIDADO'),
(2,1,'CERTIDAO_NASCIMENTO',   '/docs/aluno1/certidao.pdf',    'VALIDADO'),
(3,2,'RG',                    '/docs/aluno2/rg.pdf',          'VALIDADO'),
(4,3,'RG',                    '/docs/aluno3/rg.pdf',          'PENDENTE'),
(5,4,'COMPROVANTE_RESIDENCIA','/docs/aluno4/comprovante.pdf', 'VALIDADO'),
(6,5,'RG',                    '/docs/aluno5/rg.pdf',          'VALIDADO'),
(7,6,'RG',                    '/docs/aluno6/rg.pdf',          'REJEITADO'),
(8,7,'RG',                    '/docs/aluno7/rg.pdf',          'VALIDADO');

INSERT IGNORE INTO tb_ocorrencia_disciplinar
    (pk_id_ocorrencia, fk_id_aluno, fk_id_funcionario, tipo, descricao, data_ocorrencia, ciencia_responsavel)
VALUES
(1,3,4,'ADVERTENCIA','Comportamento inadequado em sala durante aula de Matemática','2025-03-05',TRUE),
(2,3,4,'SUSPENSAO',  'Reincidência de comportamento inadequado após advertência',  '2025-03-20',TRUE),
(3,1,5,'ELOGIO',     'Representou a escola na olimpíada de matemática regional',   '2025-04-10',FALSE);

-- ------------------------------------------------------------
--  MÓDULO FINANCEIRO
-- ------------------------------------------------------------
INSERT IGNORE INTO tb_contrato_educacional
    (pk_id_contrato, fk_id_matricula, fk_id_responsavel_pessoa, fk_id_responsavel_aluno,
     data_inicio, data_fim, valor_mensalidade, desconto_percentual, total_parcelas, status_contrato)
VALUES
(1,1,15,1,'2025-02-01','2025-12-31',1200.00, 0.00, 11,'ATIVO'),
(2,2,16,2,'2025-02-01','2025-12-31',1200.00,10.00, 11,'ATIVO'),
(3,3,17,3,'2025-02-01','2025-12-31',1200.00, 0.00, 11,'ATIVO'),
(4,4,18,4,'2025-02-01','2025-12-31',1200.00, 0.00, 11,'SUSPENSO'),
(5,5,19,5,'2025-02-01','2025-12-31',1350.00, 0.00, 11,'ATIVO'),
(6,6,20,6,'2025-02-01','2025-12-31',1350.00, 5.00, 11,'ATIVO'),
(7,7,21,7,'2025-02-01','2025-12-31',1500.00,15.00, 11,'ATIVO');

INSERT IGNORE INTO tb_mensalidade
    (pk_id_mensalidade, fk_id_contrato, numero_parcela, data_vencimento, valor_original, valor_desconto, status_mensalidade)
VALUES
(1, 1,1,'2025-02-10',1200.00,  0.00,'PAGO'),
(2, 1,2,'2025-03-10',1200.00,  0.00,'PAGO'),
(3, 1,3,'2025-04-10',1200.00,  0.00,'PENDENTE'),
(4, 2,1,'2025-02-10',1200.00,120.00,'PAGO'),
(5, 2,2,'2025-03-10',1200.00,120.00,'PAGO'),
(6, 2,3,'2025-04-10',1200.00,120.00,'PAGO'),
(7, 3,1,'2025-02-10',1200.00,  0.00,'PAGO'),
(8, 3,2,'2025-03-10',1200.00,  0.00,'INADIMPLENTE'),
(9, 3,3,'2025-04-10',1200.00,  0.00,'INADIMPLENTE'),
(10,4,1,'2025-02-10',1200.00,  0.00,'PAGO'),
(11,4,2,'2025-03-10',1200.00,  0.00,'INADIMPLENTE'),
(12,4,3,'2025-04-10',1200.00,  0.00,'INADIMPLENTE'),
(13,5,1,'2025-02-10',1350.00,  0.00,'PAGO'),
(14,5,2,'2025-03-10',1350.00,  0.00,'PAGO'),
(15,5,3,'2025-04-10',1350.00,  0.00,'PENDENTE'),
(16,6,1,'2025-02-10',1350.00, 67.50,'PAGO'),
(17,6,2,'2025-03-10',1350.00, 67.50,'PAGO'),
(18,6,3,'2025-04-10',1350.00, 67.50,'PAGO'),
(19,7,1,'2025-02-10',1500.00,225.00,'PAGO'),
(20,7,2,'2025-03-10',1500.00,225.00,'PAGO'),
(21,7,3,'2025-04-10',1500.00,225.00,'PENDENTE');

INSERT IGNORE INTO tb_pagamento
    (pk_id_pagamento, fk_id_mensalidade, data_pagamento, valor_pago, forma_pagamento, comprovante)
VALUES
(1, 1, '2025-02-08',1200.00,'PIX',           'comp_001.pdf'),
(2, 2, '2025-03-09',1200.00,'PIX',           'comp_002.pdf'),
(3, 4, '2025-02-07',1080.00,'BOLETO',        'comp_003.pdf'),
(4, 5, '2025-03-08',1080.00,'BOLETO',        'comp_004.pdf'),
(5, 6, '2025-04-07',1080.00,'BOLETO',        'comp_005.pdf'),
(6, 7, '2025-02-10',1200.00,'CARTAO_DEBITO', 'comp_006.pdf'),
(7, 10,'2025-02-09',1200.00,'DINHEIRO',      'comp_007.pdf'),
(8, 13,'2025-02-08',1350.00,'PIX',           'comp_008.pdf'),
(9, 14,'2025-03-07',1350.00,'PIX',           'comp_009.pdf'),
(10,16,'2025-02-06',1282.50,'CARTAO_CREDITO','comp_010.pdf'),
(11,17,'2025-03-06',1282.50,'CARTAO_CREDITO','comp_011.pdf'),
(12,18,'2025-04-05',1282.50,'CARTAO_CREDITO','comp_012.pdf'),
(13,19,'2025-02-08',1275.00,'PIX',           'comp_013.pdf'),
(14,20,'2025-03-08',1275.00,'PIX',           'comp_014.pdf');

INSERT IGNORE INTO tb_inadimplencia
    (pk_id_inadimplencia, fk_id_contrato, qtd_mensalidades_atraso, data_primeiro_atraso, status_negociacao)
VALUES
(1,3,2,'2025-03-11','EM_NEGOCIACAO'),
(2,4,2,'2025-03-11','PENDENTE');

INSERT IGNORE INTO tb_conta_pagar
    (pk_id_conta_pagar, fk_id_vinculo, fk_id_funcionario, descricao, valor,
     data_vencimento, data_pagamento, status_pagamento, tipo_provento)
VALUES
(1, NULL,1, 'Salário Março/2025 — Coordenadora',         7000.00,'2025-03-31','2025-03-31','PAGO',    'SALARIO'),
(2, NULL,5, 'Salário Março/2025 — Secretário',           3500.00,'2025-03-31','2025-03-31','PAGO',    'SALARIO'),
(3, NULL,6, 'Salário Março/2025 — Aux. Administrativo',  2800.00,'2025-03-31','2025-03-31','PAGO',    'SALARIO'),
(4, NULL,4, 'Salário Abril/2025 — Coordenadora',         7000.00,'2025-04-30', NULL,       'PENDENTE','SALARIO'),
(5, 1,  1, 'Hora-aula Março/2025 — Prof. Carlos Mat T1', 1700.00,'2025-03-31','2025-03-31','PAGO',   'HORA_AULA'),
(6, 2,  1, 'Hora-aula Março/2025 — Prof. Carlos Mat T2', 1700.00,'2025-03-31','2025-03-31','PAGO',   'HORA_AULA'),
(7, 4,  2, 'Hora-aula Março/2025 — Prof. Ana Port T1',   1800.00,'2025-03-31','2025-03-31','PAGO',   'HORA_AULA'),
(8, 7,  3, 'Hora-aula Março/2025 — Prof. Roberto Cie T1',1200.00,'2025-03-31', NULL,       'PENDENTE','HORA_AULA');


-- ============================================================
--  PASSO 5 — CONTAGEM DEPOIS DA CARGA
--  Compare com a contagem do PASSO 4
--  Números IGUAIS = idempotência confirmada ✔
--  Números MAIORES = duplicação detectada ✗
-- ============================================================
SELECT 'CONTAGEM DEPOIS DA CARGA' AS momento;
SELECT 'tb_pessoa'                     AS tabela, COUNT(*) AS total FROM tb_pessoa          UNION ALL
SELECT 'tb_funcionario',                           COUNT(*) FROM tb_funcionario             UNION ALL
SELECT 'tb_professor',                             COUNT(*) FROM tb_professor               UNION ALL
SELECT 'tb_vinculo_prof_disciplina',               COUNT(*) FROM tb_vinculo_prof_disciplina UNION ALL
SELECT 'tb_aluno',                                 COUNT(*) FROM tb_aluno                   UNION ALL
SELECT 'tb_responsavel',                           COUNT(*) FROM tb_responsavel             UNION ALL
SELECT 'tb_curso',                                 COUNT(*) FROM tb_curso                   UNION ALL
SELECT 'tb_turma',                                 COUNT(*) FROM tb_turma                   UNION ALL
SELECT 'tb_disciplina',                            COUNT(*) FROM tb_disciplina              UNION ALL
SELECT 'tb_grade_curricular',                      COUNT(*) FROM tb_grade_curricular        UNION ALL
SELECT 'tb_parametro_avaliacao',                   COUNT(*) FROM tb_parametro_avaliacao     UNION ALL
SELECT 'tb_matricula',                             COUNT(*) FROM tb_matricula               UNION ALL
SELECT 'tb_nota',                                  COUNT(*) FROM tb_nota                    UNION ALL
SELECT 'tb_frequencia',                            COUNT(*) FROM tb_frequencia              UNION ALL
SELECT 'tb_calendario_letivo',                     COUNT(*) FROM tb_calendario_letivo       UNION ALL
SELECT 'tb_historico_status_matricula',            COUNT(*) FROM tb_historico_status_matricula UNION ALL
SELECT 'tb_documento_aluno',                       COUNT(*) FROM tb_documento_aluno         UNION ALL
SELECT 'tb_ocorrencia_disciplinar',                COUNT(*) FROM tb_ocorrencia_disciplinar  UNION ALL
SELECT 'tb_contrato_educacional',                  COUNT(*) FROM tb_contrato_educacional    UNION ALL
SELECT 'tb_mensalidade',                           COUNT(*) FROM tb_mensalidade             UNION ALL
SELECT 'tb_pagamento',                             COUNT(*) FROM tb_pagamento               UNION ALL
SELECT 'tb_inadimplencia',                         COUNT(*) FROM tb_inadimplencia           UNION ALL
SELECT 'tb_conta_pagar',                           COUNT(*) FROM tb_conta_pagar;


-- ============================================================
--  PASSO 6 — VALIDAÇÃO FINAL DAS TABELAS CRIADAS
-- ============================================================
SELECT
    table_name    AS tabela,
    table_comment AS descricao
FROM information_schema.tables
WHERE table_schema = 'sisgesc'
ORDER BY table_name;

SELECT 'SisGESC instalado com sucesso! 23 tabelas criadas e dados carregados.' AS status;
