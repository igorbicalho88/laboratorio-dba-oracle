-- =====================================================================
-- Módulo 1 - Tuning | Script 00: tablespace e usuário do laboratório
-- Rodar como SYSDBA:  sqlplus / as sysdba  @00_criar_usuario.sql
-- =====================================================================
WHENEVER SQLERROR EXIT FAILURE
ALTER SESSION SET CONTAINER = FREEPDB1;

-- Tablespace própria, criada na mesma pasta dos arquivos de dados do PDB
DECLARE
  v_pasta VARCHAR2(500);
BEGIN
  SELECT SUBSTR(file_name, 1, INSTR(file_name, '/', -1))
    INTO v_pasta
    FROM dba_data_files
   WHERE tablespace_name = 'SYSTEM';
  EXECUTE IMMEDIATE 'CREATE TABLESPACE lab_dados DATAFILE ''' || v_pasta ||
                    'lab_dados01.dbf'' SIZE 512M AUTOEXTEND ON NEXT 128M MAXSIZE 6G';
END;
/

-- Usuário do laboratório (a senha é digitada na hora e não fica no script)
ACCEPT senha_lab CHAR PROMPT "Senha para o usuario LAB: " HIDE
CREATE USER lab IDENTIFIED BY &senha_lab
  DEFAULT TABLESPACE lab_dados QUOTA UNLIMITED ON lab_dados;

GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE PROCEDURE, CREATE SEQUENCE TO lab;
-- Necessário para o SET AUTOTRACE (estatísticas de execução) e o DBMS_XPLAN
GRANT SELECT_CATALOG_ROLE TO lab;

SELECT tablespace_name, file_name, ROUND(bytes/1024/1024) AS mb
  FROM dba_data_files WHERE tablespace_name = 'LAB_DADOS';
EXIT
