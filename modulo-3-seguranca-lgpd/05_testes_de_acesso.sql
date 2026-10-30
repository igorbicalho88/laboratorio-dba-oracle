-- =====================================================================
-- Módulo 3 - Segurança e LGPD | Script 05: a mesma consulta, cinco pessoas
-- Rodar como oracle, sem conectar antes:
--   sqlplus /nolog @05_testes_de_acesso.sql
-- Pede a senha dos usuários de teste (a mesma do script 01).
-- =====================================================================
SET LINESIZE 200 PAGESIZE 100 TRIMSPOOL ON VERIFY OFF
ACCEPT senha CHAR PROMPT "Senha dos usuarios de teste: " HIDE
SPOOL logs/05_testes_de_acesso.log
DEFINE banco = "//localhost:1521/FREEPDB1"
COLUMN nome  FORMAT A14
COLUMN cpf   FORMAT A12
COLUMN email FORMAT A24
COLUMN usuario FORMAT A12

PROMPT
PROMPT ================================================================
PROMPT 1) APP_LOJA (aplicacao): ve todos os clientes, com dados completos
PROMPT ================================================================
CONNECT app_loja/"&senha"@&banco
SET ECHO ON
SELECT cliente_id, nome, cpf, email, uf FROM lab.clientes WHERE cliente_id <= 5 ORDER BY 1;
SELECT COUNT(*) AS clientes_visiveis FROM lab.clientes;
SET ECHO OFF

PROMPT
PROMPT ================================================================
PROMPT 2) ATEND_MG (atendimento MG): so clientes de MG, CPF e e-mail mascarados
PROMPT ================================================================
CONNECT atend_mg/"&senha"@&banco
SET ECHO ON
SELECT cliente_id, nome, cpf, email, uf FROM lab.clientes WHERE cliente_id <= 30 ORDER BY 1;
SELECT uf, COUNT(*) AS clientes_visiveis FROM lab.clientes GROUP BY uf;
SELECT COUNT(*) AS pedidos_visiveis FROM lab.pedidos;
-- O atendente localiza o cliente pelo CPF informado ao telefone, mas não o vê inteiro
SELECT cliente_id, nome, cpf, uf FROM lab.clientes WHERE cpf = (SELECT MIN(cpf) FROM lab.clientes);
-- Tentativas fora do permitido
UPDATE lab.clientes SET email = 'novo@exemplo.com' WHERE uf = 'SP';
UPDATE lab.clientes SET nome = 'Outro nome' WHERE cliente_id = 1;
ROLLBACK;
SET ECHO OFF

PROMPT
PROMPT ================================================================
PROMPT 3) ATEND_SP (atendimento SP): mesma consulta, outro resultado
PROMPT ================================================================
CONNECT atend_sp/"&senha"@&banco
SET ECHO ON
SELECT cliente_id, nome, cpf, email, uf FROM lab.clientes WHERE cliente_id <= 30 ORDER BY 1;
SELECT uf, COUNT(*) AS clientes_visiveis FROM lab.clientes GROUP BY uf;
SET ECHO OFF

PROMPT
PROMPT ================================================================
PROMPT 4) ANALISTA_BI: analisa vendas sem acessar dados pessoais
PROMPT ================================================================
CONNECT analista_bi/"&senha"@&banco
SET ECHO ON
SELECT cliente_id, nome, cpf FROM lab.clientes WHERE cliente_id = 1;
SELECT c.uf, COUNT(*) AS pedidos, ROUND(SUM(p.valor_total)) AS faturamento
  FROM lab.pedidos p JOIN lab.vw_clientes_analise c ON c.cliente_id = p.cliente_id
 WHERE p.data_pedido >= DATE '2025-01-01'
 GROUP BY c.uf ORDER BY faturamento DESC;
SET ECHO OFF

PROMPT
PROMPT ================================================================
PROMPT 5) AUDITOR_DPO: le a auditoria, mas nao os dados
PROMPT ================================================================
CONNECT auditor_dpo/"&senha"@&banco
SET ECHO ON
SELECT COUNT(*) FROM lab.clientes;
SELECT COUNT(*) AS registros_de_auditoria FROM unified_audit_trail;
SET ECHO OFF

PROMPT
PROMPT ================================================================
PROMPT 6) Ataque de senha: 6 tentativas erradas no usuario ATEND_SP
PROMPT    (cada erro demora mais: o Oracle atrasa as tentativas seguidas)
PROMPT ================================================================
DISCONNECT
CONNECT atend_sp/SenhaErrada1@&banco
CONNECT atend_sp/SenhaErrada2@&banco
CONNECT atend_sp/SenhaErrada3@&banco
CONNECT atend_sp/SenhaErrada4@&banco
CONNECT atend_sp/SenhaErrada5@&banco
PROMPT >>> 6a tentativa, agora com a senha CERTA:
CONNECT atend_sp/"&senha"@&banco

PROMPT
PROMPT >>> O DBA confere e desbloqueia a conta
CONNECT / AS SYSDBA
ALTER SESSION SET CONTAINER = FREEPDB1;
SELECT username, account_status, lock_date FROM dba_users WHERE username = 'ATEND_SP';
ALTER USER atend_sp ACCOUNT UNLOCK;
SELECT username, account_status FROM dba_users WHERE username = 'ATEND_SP';
SPOOL OFF
EXIT
