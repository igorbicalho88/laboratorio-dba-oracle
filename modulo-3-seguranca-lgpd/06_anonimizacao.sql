-- =====================================================================
-- Módulo 3 - Segurança e LGPD | Script 06: direito à eliminação (art. 18)
-- Rodar como SYSDBA:  sqlplus / as sysdba @06_anonimizacao.sql
-- O titular pede a exclusão dos seus dados. Os pedidos precisam ser mantidos
-- (obrigação fiscal, art. 16, I), então o cliente é ANONIMIZADO: os dados que
-- o identificam somem, e o histórico de compras continua para as análises.
-- =====================================================================
SET LINESIZE 200 PAGESIZE 100 TRIMSPOOL ON ECHO ON
WHENEVER SQLERROR EXIT FAILURE
SPOOL logs/06_anonimizacao.log
ALTER SESSION SET CONTAINER = FREEPDB1;

-- Registro de cada solicitação atendida (prova de cumprimento, sem dado pessoal)
CREATE TABLE seg_admin.solicitacoes_titular (
  protocolo     VARCHAR2(20) CONSTRAINT pk_solicitacoes PRIMARY KEY,
  cliente_id    NUMBER       NOT NULL,
  tipo          VARCHAR2(20) NOT NULL,
  atendida_em   TIMESTAMP    DEFAULT SYSTIMESTAMP NOT NULL,
  executada_por VARCHAR2(128) DEFAULT SYS_CONTEXT('USERENV', 'SESSION_USER') NOT NULL
);

-- SELECT também é exigido: o UPDATE filtra por cliente_id (SQL92_SECURITY)
GRANT SELECT, UPDATE ON lab.clientes TO seg_admin;

CREATE OR REPLACE PROCEDURE seg_admin.anonimizar_cliente (p_cliente_id NUMBER, p_protocolo VARCHAR2)
AS
BEGIN
  UPDATE lab.clientes
     SET nome  = 'Titular anonimizado',
         cpf   = 'X' || LPAD(p_cliente_id, 10, '0'),   -- continua único, mas não é um CPF
         email = NULL
   WHERE cliente_id = p_cliente_id;
  IF SQL%ROWCOUNT = 0 THEN
    RAISE_APPLICATION_ERROR(-20001, 'Cliente ' || p_cliente_id || ' nao encontrado');
  END IF;
  INSERT INTO seg_admin.solicitacoes_titular (protocolo, cliente_id, tipo)
  VALUES (p_protocolo, p_cliente_id, 'ELIMINACAO');
  COMMIT;
END;
/
SHOW ERRORS PROCEDURE seg_admin.anonimizar_cliente

COLUMN nome FORMAT A20
COLUMN cpf FORMAT A12
COLUMN email FORMAT A24
PROMPT >>> Antes
SELECT cliente_id, nome, cpf, email, uf, data_cadastro FROM lab.clientes WHERE cliente_id = 4242;
SELECT COUNT(*) AS pedidos, SUM(valor_total) AS total_comprado FROM lab.pedidos WHERE cliente_id = 4242;

EXEC seg_admin.anonimizar_cliente(4242, 'LGPD-2026-0001')

PROMPT >>> Depois: o titular não é mais identificável; o histórico de compras continua
SELECT cliente_id, nome, cpf, email, uf, data_cadastro FROM lab.clientes WHERE cliente_id = 4242;
SELECT COUNT(*) AS pedidos, SUM(valor_total) AS total_comprado FROM lab.pedidos WHERE cliente_id = 4242;
SELECT * FROM seg_admin.solicitacoes_titular;

PROMPT >>> Atenção: o dado antigo ainda existe no UNDO (Flashback Query) e nos backups.
PROMPT >>> Ele some sozinho quando o UNDO é reaproveitado e os backups saem da janela de 7 dias.
SELECT cliente_id, nome, cpf, email FROM lab.clientes
  AS OF TIMESTAMP (SYSTIMESTAMP - INTERVAL '30' SECOND) WHERE cliente_id = 4242;
SPOOL OFF
EXIT
