DROP database sisgesc;
CREATE DATABASE IF NOT EXISTS sisgesc;
USE sisgesc;
-- ============================================================
--  SisGESC — DDL OLTP Corrigido
--  Versão 2.0 — Entrega Final
--  Correções aplicadas vs. v1:
--    1. nome_completo decomposto em primeiro_nome + sobrenome (1FN)
--    2. ON DELETE RESTRICT explícito em todas as FKs (sem CASCADE)
--    3. Scripts organizados por módulo com comentários
--    4. Script de reset incluído no início
-- ============================================================

-- ============================================================
--  RESET (executar para limpar o banco antes de recriar)
-- ============================================================

SET FOREIGN_KEY_CHECKS = 0;

-- Módulo Financeiro
DROP TABLE IF EXISTS tb_conta_pagar;
DROP TABLE IF EXISTS tb_inadimplencia;
DROP TABLE IF EXISTS tb_pagamento;
DROP TABLE IF EXISTS tb_mensalidade;
DROP TABLE IF EXISTS tb_contrato_educacional;

-- Módulo Acadêmico
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

-- Módulo Recursos Humanos
DROP TABLE IF EXISTS tb_vinculo_prof_disciplina;
DROP TABLE IF EXISTS tb_professor;
DROP TABLE IF EXISTS tb_funcionario;

-- Módulo Transversal
DROP TABLE IF EXISTS tb_pessoa;

SET FOREIGN_KEY_CHECKS = 1;


-- ============================================================
--  MÓDULO TRANSVERSAL
-- ============================================================

CREATE TABLE tb_pessoa (
    pk_id_pessoa        INT             NOT NULL AUTO_INCREMENT,
    tipo_pessoa         VARCHAR(20)     NOT NULL COMMENT 'CHECK: ALUNO | PROFESSOR | FUNCIONARIO | RESPONSAVEL',
    -- CORREÇÃO 1FN: nome_completo decomposto em dois campos atômicos
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

    CONSTRAINT pk_pessoa PRIMARY KEY (pk_id_pessoa),
    CONSTRAINT uq_pessoa_cpf   UNIQUE (cpf),
    CONSTRAINT uq_pessoa_email UNIQUE (email),
    CONSTRAINT ck_pessoa_tipo   CHECK (tipo_pessoa IN ('ALUNO','PROFESSOR','FUNCIONARIO','RESPONSAVEL')),
    CONSTRAINT ck_pessoa_status CHECK (status IN ('ATIVO','INATIVO'))
) COMMENT 'Entidade central de todos os atores do sistema';


-- ============================================================
--  MÓDULO RECURSOS HUMANOS
-- ============================================================

CREATE TABLE tb_funcionario (
    pk_id_funcionario        INT             NOT NULL AUTO_INCREMENT,
    fk_id_pessoa             INT             NOT NULL,
    cargo                    VARCHAR(80)     NOT NULL,
    tipo_vinculo             VARCHAR(30)     NOT NULL COMMENT 'CHECK: CLT | PJ | ESTATUTARIO',
    salario_base             DECIMAL(10,2)   NOT NULL,
    carga_horaria_contratual DECIMAL(5,2)    NOT NULL,
    data_admissao            DATE            NOT NULL,
    status_funcionario       VARCHAR(20)     NOT NULL DEFAULT 'ATIVO' COMMENT 'CHECK: ATIVO | INATIVO | AFASTADO',
    data_criacao             TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ultima_atualizacao       TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT pk_funcionario PRIMARY KEY (pk_id_funcionario),
    CONSTRAINT fk_funcionario_pessoa FOREIGN KEY (fk_id_pessoa)
        REFERENCES tb_pessoa (pk_id_pessoa)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_funcionario_vinculo CHECK (tipo_vinculo IN ('CLT','PJ','ESTATUTARIO')),
    CONSTRAINT ck_funcionario_status  CHECK (status_funcionario IN ('ATIVO','INATIVO','AFASTADO'))
);


CREATE TABLE tb_professor (
    pk_id_professor    INT             NOT NULL AUTO_INCREMENT,
    fk_id_funcionario  INT             NOT NULL,
    formacao_academica VARCHAR(100)    NOT NULL,
    especialidade      VARCHAR(100),
    valor_hora_aula    DECIMAL(8,2)    NOT NULL,

    CONSTRAINT pk_professor PRIMARY KEY (pk_id_professor),
    CONSTRAINT fk_professor_funcionario FOREIGN KEY (fk_id_funcionario)
        REFERENCES tb_funcionario (pk_id_funcionario)
        ON DELETE RESTRICT ON UPDATE CASCADE
);


CREATE TABLE tb_vinculo_prof_disciplina (
    pk_id_vinculo         INT             NOT NULL AUTO_INCREMENT,
    fk_id_professor       INT             NOT NULL,
    fk_id_turma           INT             NOT NULL,
    fk_id_disciplina      INT             NOT NULL,
    carga_horaria_semanal DECIMAL(5,2)    NOT NULL,
    status                VARCHAR(20)     NOT NULL DEFAULT 'ATIVO' COMMENT 'CHECK: ATIVO | ENCERRADO',
    data_criacao          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_vinculo PRIMARY KEY (pk_id_vinculo),
    CONSTRAINT fk_vinculo_professor  FOREIGN KEY (fk_id_professor)
        REFERENCES tb_professor (pk_id_professor)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT uq_vinculo UNIQUE (fk_id_professor, fk_id_turma, fk_id_disciplina),
    CONSTRAINT ck_vinculo_status CHECK (status IN ('ATIVO','ENCERRADO'))
);


-- ============================================================
--  MÓDULO ACADÊMICO
-- ============================================================

CREATE TABLE tb_aluno (
    pk_id_aluno   INT         NOT NULL AUTO_INCREMENT,
    fk_id_pessoa  INT         NOT NULL,
    rgm           VARCHAR(20) NOT NULL,
    data_ingresso DATE        NOT NULL,

    CONSTRAINT pk_aluno PRIMARY KEY (pk_id_aluno),
    CONSTRAINT uq_aluno_rgm UNIQUE (rgm),
    CONSTRAINT fk_aluno_pessoa FOREIGN KEY (fk_id_pessoa)
        REFERENCES tb_pessoa (pk_id_pessoa)
        ON DELETE RESTRICT ON UPDATE CASCADE
);


CREATE TABLE tb_responsavel (
    fk_id_pessoa INT         NOT NULL,
    fk_id_aluno  INT         NOT NULL,
    parentesco   VARCHAR(30) NOT NULL COMMENT 'CHECK: PAI | MAE | AVO | RESPONSAVEL_LEGAL | OUTRO',

    CONSTRAINT pk_responsavel PRIMARY KEY (fk_id_pessoa, fk_id_aluno),
    CONSTRAINT fk_responsavel_pessoa FOREIGN KEY (fk_id_pessoa)
        REFERENCES tb_pessoa (pk_id_pessoa)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_responsavel_aluno FOREIGN KEY (fk_id_aluno)
        REFERENCES tb_aluno (pk_id_aluno)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_responsavel_parentesco CHECK (parentesco IN ('PAI','MAE','AVO','RESPONSAVEL_LEGAL','OUTRO'))
);


CREATE TABLE tb_curso (
    pk_id_curso         INT          NOT NULL AUTO_INCREMENT,
    nome_curso          VARCHAR(100) NOT NULL,
    nivel_ensino        VARCHAR(30)  NOT NULL COMMENT 'CHECK: FUNDAMENTAL | MEDIO',
    carga_horaria_total INT          NOT NULL,
    status              VARCHAR(20)  NOT NULL DEFAULT 'ATIVO' COMMENT 'CHECK: ATIVO | INATIVO',

    CONSTRAINT pk_curso PRIMARY KEY (pk_id_curso),
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

    CONSTRAINT pk_turma PRIMARY KEY (pk_id_turma),
    CONSTRAINT fk_turma_curso FOREIGN KEY (fk_id_curso)
        REFERENCES tb_curso (pk_id_curso)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_turma_turno  CHECK (turno IN ('MANHA','TARDE','INTEGRAL')),
    CONSTRAINT ck_turma_status CHECK (status IN ('ATIVA','ENCERRADA','SUSPENSA'))
);


CREATE TABLE tb_disciplina (
    pk_id_disciplina INT          NOT NULL AUTO_INCREMENT,
    fk_id_curso      INT          NOT NULL,
    nome_disciplina  VARCHAR(100) NOT NULL,
    carga_horaria    INT          NOT NULL,
    status           VARCHAR(20)  NOT NULL DEFAULT 'ATIVA' COMMENT 'CHECK: ATIVA | INATIVA',

    CONSTRAINT pk_disciplina PRIMARY KEY (pk_id_disciplina),
    CONSTRAINT fk_disciplina_curso FOREIGN KEY (fk_id_curso)
        REFERENCES tb_curso (pk_id_curso)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_disciplina_status CHECK (status IN ('ATIVA','INATIVA'))
);


CREATE TABLE tb_grade_curricular (
    fk_id_turma           INT          NOT NULL,
    fk_id_disciplina      INT          NOT NULL,
    carga_horaria_semanal DECIMAL(5,2) NOT NULL,
    status                VARCHAR(20)  NOT NULL DEFAULT 'ATIVA' COMMENT 'CHECK: ATIVA | INATIVA',

    CONSTRAINT pk_grade PRIMARY KEY (fk_id_turma, fk_id_disciplina),
    CONSTRAINT fk_grade_turma FOREIGN KEY (fk_id_turma)
        REFERENCES tb_turma (pk_id_turma)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_grade_disciplina FOREIGN KEY (fk_id_disciplina)
        REFERENCES tb_disciplina (pk_id_disciplina)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_grade_status CHECK (status IN ('ATIVA','INATIVA'))
);

-- Adicionando as FKs compostas de tb_vinculo_prof_disciplina agora que tb_grade_curricular existe
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

    CONSTRAINT pk_parametro PRIMARY KEY (pk_id_parametro),
    CONSTRAINT fk_parametro_curso FOREIGN KEY (fk_id_curso)
        REFERENCES tb_curso (pk_id_curso)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT uq_parametro UNIQUE (fk_id_curso, ordem, ano_letivo)
);


CREATE TABLE tb_matricula (
    pk_id_matricula    INT         NOT NULL AUTO_INCREMENT,
    fk_id_aluno        INT         NOT NULL,
    fk_id_turma        INT         NOT NULL,
    data_matricula     DATE        NOT NULL,
    status_matricula   VARCHAR(20) NOT NULL DEFAULT 'ATIVA' COMMENT 'CHECK: ATIVA | TRANCADA | CANCELADA | CONCLUIDA',
    data_criacao       TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ultima_atualizacao TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT pk_matricula PRIMARY KEY (pk_id_matricula),
    CONSTRAINT uq_matricula UNIQUE (fk_id_aluno, fk_id_turma),
    CONSTRAINT fk_matricula_aluno FOREIGN KEY (fk_id_aluno)
        REFERENCES tb_aluno (pk_id_aluno)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_matricula_turma FOREIGN KEY (fk_id_turma)
        REFERENCES tb_turma (pk_id_turma)
        ON DELETE RESTRICT ON UPDATE CASCADE,
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

    CONSTRAINT pk_nota PRIMARY KEY (pk_id_nota),
    CONSTRAINT uq_nota UNIQUE (fk_id_matricula, fk_id_disciplina, fk_id_parametro),
    CONSTRAINT fk_nota_matricula FOREIGN KEY (fk_id_matricula)
        REFERENCES tb_matricula (pk_id_matricula)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_nota_parametro FOREIGN KEY (fk_id_parametro)
        REFERENCES tb_parametro_avaliacao (pk_id_parametro)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_nota_grade FOREIGN KEY (fk_id_turma, fk_id_disciplina)
        REFERENCES tb_grade_curricular (fk_id_turma, fk_id_disciplina)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_nota_valor    CHECK (valor_nota BETWEEN 0.00 AND 10.00),
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

    CONSTRAINT pk_frequencia PRIMARY KEY (pk_id_frequencia),
    -- Bug corrigido v3.0: índice único impede frequência duplicada no mesmo dia
    CONSTRAINT uq_frequencia UNIQUE (fk_id_matricula, fk_id_disciplina, data_aula),
    CONSTRAINT fk_frequencia_matricula FOREIGN KEY (fk_id_matricula)
        REFERENCES tb_matricula (pk_id_matricula)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_frequencia_grade FOREIGN KEY (fk_id_turma, fk_id_disciplina)
        REFERENCES tb_grade_curricular (fk_id_turma, fk_id_disciplina)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_frequencia_status CHECK (status_presenca IN ('PRESENTE','AUSENTE','JUSTIFICADO'))
);


CREATE TABLE tb_calendario_letivo (
    pk_id_calendario INT          NOT NULL AUTO_INCREMENT,
    fk_id_turma      INT          NOT NULL,
    data             DATE         NOT NULL,
    tipo             VARCHAR(20)  NOT NULL COMMENT 'CHECK: DIA_LETIVO | FERIADO | RECESSO | EVENTO',
    descricao        VARCHAR(100),

    CONSTRAINT pk_calendario PRIMARY KEY (pk_id_calendario),
    CONSTRAINT uq_calendario UNIQUE (fk_id_turma, data),
    CONSTRAINT fk_calendario_turma FOREIGN KEY (fk_id_turma)
        REFERENCES tb_turma (pk_id_turma)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_calendario_tipo CHECK (tipo IN ('DIA_LETIVO','FERIADO','RECESSO','EVENTO'))
);


CREATE TABLE tb_historico_status_matricula (
    pk_id_historico   INT          NOT NULL AUTO_INCREMENT,
    fk_id_matricula   INT          NOT NULL,
    fk_id_funcionario INT          NOT NULL,
    status_anterior   VARCHAR(20)  NOT NULL,
    status_novo       VARCHAR(20)  NOT NULL,
    data_alteracao    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    observacao        VARCHAR(200),

    CONSTRAINT pk_historico PRIMARY KEY (pk_id_historico),
    -- RESTRICT explícito: histórico nunca deve ser removido em cascata
    CONSTRAINT fk_historico_matricula FOREIGN KEY (fk_id_matricula)
        REFERENCES tb_matricula (pk_id_matricula)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_historico_funcionario FOREIGN KEY (fk_id_funcionario)
        REFERENCES tb_funcionario (pk_id_funcionario)
        ON DELETE RESTRICT ON UPDATE CASCADE
);


CREATE TABLE tb_documento_aluno (
    pk_id_documento INT          NOT NULL AUTO_INCREMENT,
    fk_id_aluno     INT          NOT NULL,
    tipo_documento  VARCHAR(40)  NOT NULL COMMENT 'CHECK: RG | CPF | CERTIDAO_NASCIMENTO | COMPROVANTE_RESIDENCIA | LAUDO | OUTRO',
    caminho_arquivo VARCHAR(200) NOT NULL,
    data_upload     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status          VARCHAR(20)  NOT NULL DEFAULT 'PENDENTE' COMMENT 'CHECK: PENDENTE | VALIDADO | REJEITADO',

    CONSTRAINT pk_documento PRIMARY KEY (pk_id_documento),
    CONSTRAINT fk_documento_aluno FOREIGN KEY (fk_id_aluno)
        REFERENCES tb_aluno (pk_id_aluno)
        ON DELETE RESTRICT ON UPDATE CASCADE,
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

    CONSTRAINT pk_ocorrencia PRIMARY KEY (pk_id_ocorrencia),
    CONSTRAINT fk_ocorrencia_aluno FOREIGN KEY (fk_id_aluno)
        REFERENCES tb_aluno (pk_id_aluno)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_ocorrencia_funcionario FOREIGN KEY (fk_id_funcionario)
        REFERENCES tb_funcionario (pk_id_funcionario)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_ocorrencia_tipo CHECK (tipo IN ('ADVERTENCIA','SUSPENSAO','ELOGIO','OUTRO'))
);


-- ============================================================
--  MÓDULO FINANCEIRO
-- ============================================================

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

    CONSTRAINT pk_contrato PRIMARY KEY (pk_id_contrato),
    CONSTRAINT uq_contrato_matricula UNIQUE (fk_id_matricula),
    CONSTRAINT fk_contrato_matricula FOREIGN KEY (fk_id_matricula)
        REFERENCES tb_matricula (pk_id_matricula)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    -- RESTRICT explícito: dados financeiros nunca devem ser removidos em cascata
    CONSTRAINT fk_contrato_responsavel FOREIGN KEY (fk_id_responsavel_pessoa, fk_id_responsavel_aluno)
        REFERENCES tb_responsavel (fk_id_pessoa, fk_id_aluno)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_contrato_status CHECK (status_contrato IN ('ATIVO','SUSPENSO','ENCERRADO','CANCELADO'))
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

    CONSTRAINT pk_mensalidade PRIMARY KEY (pk_id_mensalidade),
    CONSTRAINT uq_mensalidade UNIQUE (fk_id_contrato, numero_parcela),
    -- RESTRICT explícito: histórico financeiro não pode ser apagado em cascata
    CONSTRAINT fk_mensalidade_contrato FOREIGN KEY (fk_id_contrato)
        REFERENCES tb_contrato_educacional (pk_id_contrato)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_mensalidade_status CHECK (status_mensalidade IN ('PENDENTE','PAGO','INADIMPLENTE','ISENTO'))
);


CREATE TABLE tb_pagamento (
    pk_id_pagamento   INT           NOT NULL AUTO_INCREMENT,
    fk_id_mensalidade INT           NOT NULL,
    data_pagamento    DATE          NOT NULL,
    valor_pago        DECIMAL(10,2) NOT NULL,
    forma_pagamento   VARCHAR(30)   NOT NULL COMMENT 'CHECK: PIX | BOLETO | CARTAO_CREDITO | CARTAO_DEBITO | DINHEIRO',
    comprovante       VARCHAR(100),
    data_criacao      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_pagamento PRIMARY KEY (pk_id_pagamento),
    -- RESTRICT explícito: registro de pagamento é dado histórico permanente
    CONSTRAINT fk_pagamento_mensalidade FOREIGN KEY (fk_id_mensalidade)
        REFERENCES tb_mensalidade (pk_id_mensalidade)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_pagamento_forma CHECK (forma_pagamento IN ('PIX','BOLETO','CARTAO_CREDITO','CARTAO_DEBITO','DINHEIRO'))
);


CREATE TABLE tb_inadimplencia (
    pk_id_inadimplencia     INT         NOT NULL AUTO_INCREMENT,
    fk_id_contrato          INT         NOT NULL,
    qtd_mensalidades_atraso INT         NOT NULL DEFAULT 0,
    data_primeiro_atraso    DATE        NOT NULL,
    status_negociacao       VARCHAR(30) NOT NULL DEFAULT 'PENDENTE' COMMENT 'CHECK: PENDENTE | EM_NEGOCIACAO | REGULARIZADO',
    ultima_atualizacao      TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT pk_inadimplencia PRIMARY KEY (pk_id_inadimplencia),
    CONSTRAINT fk_inadimplencia_contrato FOREIGN KEY (fk_id_contrato)
        REFERENCES tb_contrato_educacional (pk_id_contrato)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_inadimplencia_status CHECK (status_negociacao IN ('PENDENTE','EM_NEGOCIACAO','REGULARIZADO'))
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

    CONSTRAINT pk_conta_pagar PRIMARY KEY (pk_id_conta_pagar),
    CONSTRAINT fk_conta_vinculo FOREIGN KEY (fk_id_vinculo)
        REFERENCES tb_vinculo_prof_disciplina (pk_id_vinculo)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_conta_funcionario FOREIGN KEY (fk_id_funcionario)
        REFERENCES tb_funcionario (pk_id_funcionario)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_conta_status   CHECK (status_pagamento IN ('PENDENTE','PAGO','CANCELADO')),
    CONSTRAINT ck_conta_provento CHECK (tipo_provento IN ('HORA_AULA','SALARIO','BONUS','ENCARGO'))
);


-- ============================================================
--  VALIDAÇÃO — executar após criar as tabelas
-- ============================================================

SELECT
    table_name          AS tabela,
    table_rows          AS linhas_estimadas,
    table_comment       AS descricao
FROM information_schema.tables
WHERE table_schema = DATABASE()
ORDER BY table_name
