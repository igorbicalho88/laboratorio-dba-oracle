-- =====================================================================
-- Módulo 3 - Segurança e LGPD | Script 04: segurança por linha (VPD)
-- Rodar como SYSDBA:  sqlplus / as sysdba @04_seguranca_por_linha_vpd.sql
-- Cada atendente só enxerga os clientes (e os pedidos) da sua UF. O Oracle
-- acrescenta o filtro em TODA consulta, inclusive as feitas fora da aplicação.
-- Princípio da necessidade (LGPD, art. 6º, III).
--
-- Lição do primeiro teste: a 1ª versão da função perguntava
-- SYS_CONTEXT('SYS_SESSION_ROLES', 'ATENDIMENTO'). Dentro de uma função com
-- direitos do dono (definer rights) os papéis ficam DESATIVADOS, então a
-- resposta era sempre FALSE e o filtro nunca era aplicado: o atendente de MG
-- via os 200 mil clientes. Agora o papel é conferido no dicionário de dados.
--
-- Lição do segundo teste: o filtro de PEDIDOS tem uma subconsulta em CLIENTES e
-- dava ORA-28113. O predicado gerado pela função é validado com os privilégios
-- do DONO da função (SEG_ADMIN), e não do atendente: sem SELECT em LAB.CLIENTES
-- para o SEG_ADMIN, o predicado era inválido. Rodado à mão, funcionava.
-- =====================================================================
SET LINESIZE 200 PAGESIZE 100 TRIMSPOOL ON ECHO ON
SPOOL logs/04_seguranca_por_linha_vpd.log
ALTER SESSION SET CONTAINER = FREEPDB1;

-- Recomeço limpo, caso o script seja executado de novo (erros aqui são ignorados)
EXEC DBMS_RLS.DROP_POLICY('LAB', 'CLIENTES', 'LGPD_CLIENTES_POR_UF')
EXEC DBMS_RLS.DROP_POLICY('LAB', 'PEDIDOS', 'LGPD_PEDIDOS_POR_UF')
DROP TABLE seg_admin.acesso_regional PURGE;

WHENEVER SQLERROR EXIT FAILURE
-- Quem atende qual UF (mudar de região = mudar uma linha, sem tocar em código)
CREATE TABLE seg_admin.acesso_regional (
  usuario VARCHAR2(128) CONSTRAINT pk_acesso_regional PRIMARY KEY,
  uf      CHAR(2) NOT NULL
);
INSERT INTO seg_admin.acesso_regional VALUES ('ATEND_MG', 'MG');
INSERT INTO seg_admin.acesso_regional VALUES ('ATEND_SP', 'SP');
COMMIT;

-- A função consulta quem tem o papel ATENDIMENTO (privilégio direto, não via papel)
GRANT SELECT ON sys.dba_role_privs TO seg_admin;
-- O predicado de PEDIDOS consulta CLIENTES: o dono da função precisa poder ler a tabela
GRANT SELECT ON lab.clientes TO seg_admin;

-- Função que monta o filtro. Atendente sem região cadastrada não vê nada.
CREATE OR REPLACE FUNCTION seg_admin.filtro_por_uf (p_esquema VARCHAR2, p_objeto VARCHAR2)
  RETURN VARCHAR2
AS
  v_atendente NUMBER;
  v_uf        seg_admin.acesso_regional.uf%TYPE;
BEGIN
  SELECT COUNT(*) INTO v_atendente FROM sys.dba_role_privs
   WHERE grantee = SYS_CONTEXT('USERENV', 'SESSION_USER') AND granted_role = 'ATENDIMENTO'
     AND admin_option = 'NO';   -- quem criou o papel (SYS) também o recebe, com ADMIN OPTION
  IF v_atendente = 0 THEN
    RETURN NULL;
  END IF;
  SELECT uf INTO v_uf FROM seg_admin.acesso_regional
   WHERE usuario = SYS_CONTEXT('USERENV', 'SESSION_USER');
  IF p_objeto = 'CLIENTES' THEN
    RETURN 'uf = ''' || v_uf || '''';
  ELSE
    RETURN 'cliente_id IN (SELECT cliente_id FROM lab.clientes WHERE uf = ''' || v_uf || ''')';
  END IF;
EXCEPTION
  WHEN NO_DATA_FOUND THEN RETURN '1 = 0';
END;
/
SHOW ERRORS FUNCTION seg_admin.filtro_por_uf

BEGIN
  DBMS_RLS.ADD_POLICY(
    object_schema   => 'LAB',  object_name => 'CLIENTES',  policy_name => 'LGPD_CLIENTES_POR_UF',
    function_schema => 'SEG_ADMIN', policy_function => 'FILTRO_POR_UF',
    statement_types => 'SELECT, UPDATE, DELETE', update_check => TRUE);
  DBMS_RLS.ADD_POLICY(
    object_schema   => 'LAB',  object_name => 'PEDIDOS',   policy_name => 'LGPD_PEDIDOS_POR_UF',
    function_schema => 'SEG_ADMIN', policy_function => 'FILTRO_POR_UF',
    statement_types => 'SELECT, UPDATE, DELETE');
END;
/

COLUMN object_name FORMAT A10
COLUMN policy_name FORMAT A22
COLUMN function FORMAT A15
SELECT object_name, policy_name, function, sel, upd, del, enable FROM dba_policies
 WHERE object_owner = 'LAB' ORDER BY 1;
SPOOL OFF
EXIT
