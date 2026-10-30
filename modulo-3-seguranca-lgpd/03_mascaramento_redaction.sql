-- =====================================================================
-- Módulo 3 - Segurança e LGPD | Script 03: mascaramento com Data Redaction
-- Rodar como SYSDBA:  sqlplus / as sysdba @03_mascaramento_redaction.sql
-- O dado continua íntegro na tabela; o Oracle mascara na hora de devolver o
-- resultado, para quem não tem o papel LGPD_DADOS_COMPLETOS. Nenhuma mudança
-- na aplicação ou nos relatórios.
-- =====================================================================
SET LINESIZE 200 PAGESIZE 100 TRIMSPOOL ON ECHO ON
WHENEVER SQLERROR EXIT FAILURE
SPOOL logs/03_mascaramento_redaction.log
ALTER SESSION SET CONTAINER = FREEPDB1;

BEGIN
  -- CPF: mostra só os 3 primeiros e os 2 últimos dígitos (10000000037 -> 100******37)
  DBMS_REDACT.ADD_POLICY(
    object_schema          => 'LAB',
    object_name            => 'CLIENTES',
    policy_name            => 'LGPD_MASCARA_CLIENTES',
    policy_description     => 'Mascara CPF e e-mail para quem nao tem o papel LGPD_DADOS_COMPLETOS',
    column_name            => 'CPF',
    function_type          => DBMS_REDACT.REGEXP,
    regexp_pattern         => '^(\d{3})\d{6}(\d{2})$',
    regexp_replace_string  => '\1******\2',
    regexp_position        => 1,
    regexp_occurrence      => 0,
    expression             => 'SYS_CONTEXT(''SYS_SESSION_ROLES'', ''LGPD_DADOS_COMPLETOS'') = ''FALSE''');

  -- E-mail: esconde o nome antes do @ (cliente42@exemplo.com -> xxxx@exemplo.com)
  DBMS_REDACT.ALTER_POLICY(
    object_schema          => 'LAB',
    object_name            => 'CLIENTES',
    policy_name            => 'LGPD_MASCARA_CLIENTES',
    action                 => DBMS_REDACT.ADD_COLUMN,
    column_name            => 'EMAIL',
    function_type          => DBMS_REDACT.REGEXP,
    regexp_pattern         => DBMS_REDACT.RE_PATTERN_EMAIL_ADDRESS,
    regexp_replace_string  => DBMS_REDACT.RE_REDACT_EMAIL_NAME,
    regexp_position        => DBMS_REDACT.RE_BEGINNING,
    regexp_occurrence      => DBMS_REDACT.RE_ALL);
END;
/

COLUMN object_name FORMAT A10
COLUMN column_name FORMAT A8
COLUMN function_type FORMAT A20
COLUMN regexp_pattern FORMAT A45
SELECT object_name, column_name, function_type, regexp_pattern FROM redaction_columns ORDER BY 2;
COLUMN expression FORMAT A75
SELECT policy_name, expression, enable FROM redaction_policies;

-- SYS é isento de mascaramento: aqui ainda aparece o dado real
SELECT cliente_id, cpf, email FROM lab.clientes WHERE cliente_id <= 3 ORDER BY 1;
SPOOL OFF
EXIT
