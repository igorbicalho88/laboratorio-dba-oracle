-- =====================================================================
-- Módulo 3 - Segurança e LGPD | Script 02: auditoria unificada
-- Rodar como SYSDBA:  sqlplus / as sysdba @02_auditoria.sql
-- Ligada ANTES das políticas de mascaramento e de segurança por linha, para
-- que a própria configuração de segurança também fique registrada.
-- =====================================================================
SET LINESIZE 200 PAGESIZE 100 TRIMSPOOL ON ECHO ON
SPOOL logs/02_auditoria.log
ALTER SESSION SET CONTAINER = FREEPDB1;

-- 1) Quem leu ou alterou dados pessoais (exceto a aplicação, que geraria volume enorme)
CREATE AUDIT POLICY lgpd_acesso_dados_pessoais
  ACTIONS SELECT ON lab.clientes, UPDATE ON lab.clientes, DELETE ON lab.clientes,
          SELECT ON lab.vw_clientes_analise;
AUDIT POLICY lgpd_acesso_dados_pessoais EXCEPT app_loja, lab;

-- 2) Mudanças nas regras de acesso: usuários, papéis, privilégios e políticas de segurança
CREATE AUDIT POLICY lgpd_mudancas_seguranca
  ACTIONS CREATE USER, ALTER USER, DROP USER, CREATE ROLE, DROP ROLE, GRANT, REVOKE,
          CREATE PROFILE, ALTER PROFILE,
          EXECUTE ON sys.dbms_redact, EXECUTE ON sys.dbms_rls;
AUDIT POLICY lgpd_mudancas_seguranca;

-- 3) Tentativas de login com falha (política pronta do Oracle)
AUDIT POLICY ora_logon_failures WHENEVER NOT SUCCESSFUL;

COLUMN policy_name FORMAT A30
COLUMN entity_name FORMAT A12
SELECT policy_name, enabled_option, entity_name, entity_type, success, failure
  FROM audit_unified_enabled_policies
 WHERE policy_name LIKE 'LGPD%' OR policy_name = 'ORA_LOGON_FAILURES'
 ORDER BY 1;
SPOOL OFF
EXIT
