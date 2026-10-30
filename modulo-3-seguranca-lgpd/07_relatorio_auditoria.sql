-- =====================================================================
-- Módulo 3 - Segurança e LGPD | Script 07: relatório do encarregado (DPO)
-- Rodar como oracle, sem conectar antes:
--   sqlplus /nolog @07_relatorio_auditoria.sql
-- Conecta como AUDITOR_DPO, que lê a trilha de auditoria mas não os dados.
-- Responde: quem acessou dados pessoais? quem mudou regras de acesso?
-- houve tentativa de invasão?
-- =====================================================================
SET LINESIZE 220 PAGESIZE 200 TRIMSPOOL ON VERIFY OFF
ACCEPT senha CHAR PROMPT "Senha do AUDITOR_DPO: " HIDE
CONNECT auditor_dpo/"&senha"@//localhost:1521/FREEPDB1
SPOOL logs/07_relatorio_auditoria.log
COLUMN quando   FORMAT A17
COLUMN usuario  FORMAT A12
COLUMN acao     FORMAT A22
COLUMN objeto   FORMAT A24
COLUMN detalhe  FORMAT A60
COLUMN politica FORMAT A28

PROMPT
PROMPT ===== 1) Acessos a dados pessoais, por usuário =====
SELECT dbusername AS usuario, object_name AS objeto, action_name AS acao,
       COUNT(*) AS vezes, SUM(CASE WHEN return_code <> 0 THEN 1 ELSE 0 END) AS negados
  FROM unified_audit_trail
 WHERE unified_audit_policies LIKE '%LGPD_ACESSO_DADOS_PESSOAIS%'
 GROUP BY dbusername, object_name, action_name
 ORDER BY 1, 2, 3;

PROMPT
PROMPT ===== 2) Comandos exatos contra a tabela de clientes =====
SELECT TO_CHAR(event_timestamp, 'DD/MM HH24:MI:SS') AS quando, dbusername AS usuario,
       action_name AS acao, return_code AS erro, SUBSTR(sql_text, 1, 60) AS detalhe
  FROM unified_audit_trail
 WHERE unified_audit_policies LIKE '%LGPD_ACESSO_DADOS_PESSOAIS%' AND object_name = 'CLIENTES'
 ORDER BY event_timestamp;

PROMPT
PROMPT ===== 3) Mudanças nas regras de acesso (usuários, privilégios, políticas) =====
SELECT TO_CHAR(event_timestamp, 'DD/MM HH24:MI:SS') AS quando, dbusername AS usuario,
       action_name AS acao, NVL(object_name, target_user) AS objeto, SUBSTR(sql_text, 1, 60) AS detalhe
  FROM unified_audit_trail
 WHERE unified_audit_policies LIKE '%LGPD_MUDANCAS_SEGURANCA%'
 ORDER BY event_timestamp;

PROMPT
PROMPT ===== 4) Logins com falha =====
SELECT TO_CHAR(event_timestamp, 'DD/MM HH24:MI:SS') AS quando, dbusername AS usuario,
       return_code AS erro, os_username, userhost
  FROM unified_audit_trail
 WHERE action_name = 'LOGON' AND return_code <> 0
 ORDER BY event_timestamp;
SPOOL OFF
EXIT
