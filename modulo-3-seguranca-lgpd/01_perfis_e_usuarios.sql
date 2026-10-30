-- =====================================================================
-- Módulo 3 - Segurança e LGPD | Script 01: menor privilégio
-- Rodar como SYSDBA:  sqlplus / as sysdba @01_perfis_e_usuarios.sql
-- Cada perfil de acesso vira um papel (role); ninguém recebe acesso direto às
-- tabelas. A senha dos usuários de teste é digitada na hora: mín. 8 caracteres,
-- com letra, número e um caractere especial (ex.: Lab2026#teste; evite @, " e &).
-- =====================================================================
SET LINESIZE 200 PAGESIZE 100 TRIMSPOOL ON ECHO ON VERIFY OFF
WHENEVER SQLERROR EXIT FAILURE
SPOOL logs/01_perfis_e_usuarios.log
ALTER SESSION SET CONTAINER = FREEPDB1;

-- Recomeço limpo, caso o script seja executado de novo (erros aqui são ignorados)
WHENEVER SQLERROR CONTINUE
SET ECHO OFF TERMOUT OFF
DROP USER app_loja;
DROP USER atend_mg;
DROP USER atend_sp;
DROP USER analista_bi;
DROP USER auditor_dpo;
DROP USER seg_admin CASCADE;
DROP ROLE lgpd_dados_completos;
DROP ROLE app_loja_role;
DROP ROLE atendimento;
DROP ROLE analista;
DROP PROFILE perfil_lgpd;
SET ECHO ON TERMOUT ON
WHENEVER SQLERROR EXIT FAILURE

-- Política de senhas: bloqueio após 5 erros, troca a cada 90 dias, sem repetir as 5 últimas
CREATE PROFILE perfil_lgpd LIMIT
  FAILED_LOGIN_ATTEMPTS    5
  PASSWORD_LOCK_TIME       1/24
  PASSWORD_LIFE_TIME       90
  PASSWORD_GRACE_TIME      7
  PASSWORD_REUSE_MAX       5
  PASSWORD_REUSE_TIME      365
  INACTIVE_ACCOUNT_TIME    60
  PASSWORD_VERIFY_FUNCTION ora12c_verify_function;

-- Esquema que guarda as regras de segurança: sem senha, ninguém faz login nele
CREATE USER seg_admin NO AUTHENTICATION DEFAULT TABLESPACE lab_dados QUOTA 10M ON lab_dados;

-- Papéis (roles) por função
-- (no SQL*Plus, comentário na mesma linha depois do ";" impede a execução: ficam sempre acima)
-- lgpd_dados_completos: marcador; quem tem este papel vê CPF e e-mail sem máscara
CREATE ROLE lgpd_dados_completos;
-- app_loja_role: a aplicação da loja
CREATE ROLE app_loja_role;
-- atendimento: só clientes da sua UF, com CPF e e-mail mascarados
CREATE ROLE atendimento;
-- analista: BI, com pedidos e uma visão de clientes SEM dados pessoais
CREATE ROLE analista;

GRANT SELECT, INSERT, UPDATE ON lab.clientes     TO app_loja_role;
GRANT SELECT, INSERT, UPDATE ON lab.pedidos      TO app_loja_role;
GRANT SELECT, INSERT, UPDATE ON lab.itens_pedido TO app_loja_role;
GRANT SELECT                 ON lab.produtos     TO app_loja_role;

GRANT SELECT ON lab.clientes TO atendimento;
-- O atendimento pode corrigir o e-mail, e só isso
GRANT UPDATE (email) ON lab.clientes TO atendimento;
GRANT SELECT ON lab.pedidos      TO atendimento;
GRANT SELECT ON lab.itens_pedido TO atendimento;
GRANT SELECT ON lab.produtos     TO atendimento;

CREATE OR REPLACE VIEW lab.vw_clientes_analise AS
SELECT cliente_id, uf, EXTRACT(YEAR FROM data_cadastro) AS ano_cadastro FROM lab.clientes;
GRANT SELECT ON lab.vw_clientes_analise TO analista;
GRANT SELECT ON lab.pedidos      TO analista;
GRANT SELECT ON lab.itens_pedido TO analista;
GRANT SELECT ON lab.produtos     TO analista;

-- O dono dos dados continua vendo tudo (usado pelos outros módulos)
GRANT lgpd_dados_completos TO lab;

-- Usuários de teste
ACCEPT senha CHAR PROMPT "Senha para os usuarios de teste: " HIDE
-- Dentro de um bloco PL/SQL, um erro não reimprime o comando com a senha na tela/log
BEGIN
  FOR u IN (SELECT column_value AS nome
              FROM TABLE(sys.odcivarchar2list('APP_LOJA', 'ATEND_MG', 'ATEND_SP', 'ANALISTA_BI', 'AUDITOR_DPO'))) LOOP
    EXECUTE IMMEDIATE 'CREATE USER ' || u.nome || ' IDENTIFIED BY "&senha" PROFILE perfil_lgpd';
  END LOOP;
END;
/

GRANT CREATE SESSION TO app_loja, atend_mg, atend_sp, analista_bi, auditor_dpo;
GRANT app_loja_role, lgpd_dados_completos TO app_loja;
GRANT atendimento TO atend_mg, atend_sp;
GRANT analista    TO analista_bi;
-- O encarregado lê a trilha de auditoria, não os dados
GRANT audit_viewer TO auditor_dpo;

SET ECHO OFF
COLUMN grantee FORMAT A14
COLUMN granted_role FORMAT A22
SELECT grantee, granted_role FROM dba_role_privs
 WHERE grantee IN ('LAB', 'APP_LOJA', 'ATEND_MG', 'ATEND_SP', 'ANALISTA_BI', 'AUDITOR_DPO')
 ORDER BY 1, 2;
COLUMN username FORMAT A14
COLUMN profile FORMAT A12
SELECT username, account_status, profile, authentication_type FROM dba_users
 WHERE username IN ('APP_LOJA', 'ATEND_MG', 'ATEND_SP', 'ANALISTA_BI', 'AUDITOR_DPO', 'SEG_ADMIN')
 ORDER BY 1;
SPOOL OFF
EXIT
