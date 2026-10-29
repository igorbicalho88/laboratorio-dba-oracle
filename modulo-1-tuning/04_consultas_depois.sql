-- =====================================================================
-- Módulo 1 - Tuning | Script 04: consultas DEPOIS do tuning
-- Rodar como LAB, dentro da pasta modulo-1-tuning:
--   sqlplus lab/<senha>@//localhost:1521/FREEPDB1 @04_consultas_depois.sql
-- Para cada cenário: plano de execução + estatísticas (2 execuções; vale a 2ª,
-- com o cache já aquecido). Resultado salvo em logs/depois.log
-- =====================================================================
SET LINESIZE 200 PAGESIZE 200 TRIMSPOOL ON
SET TIMING ON
SPOOL logs/depois.log

PROMPT
PROMPT ===================================================================
PROMPT CENARIO 1: Itens de um pedido (chave estrangeira sem indice)
PROMPT ===================================================================
EXPLAIN PLAN FOR
SELECT i.item_id, p.nome, i.quantidade, i.preco_unitario
  FROM itens_pedido i JOIN produtos p ON p.produto_id = i.produto_id
 WHERE i.pedido_id = 1234567;
SELECT plan_table_output FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, NULL, 'TYPICAL'));
SET AUTOTRACE TRACEONLY STATISTICS
SELECT i.item_id, p.nome, i.quantidade, i.preco_unitario
  FROM itens_pedido i JOIN produtos p ON p.produto_id = i.produto_id
 WHERE i.pedido_id = 1234567;
SELECT i.item_id, p.nome, i.quantidade, i.preco_unitario
  FROM itens_pedido i JOIN produtos p ON p.produto_id = i.produto_id
 WHERE i.pedido_id = 1234567;
SET AUTOTRACE OFF

PROMPT
PROMPT ===================================================================
PROMPT CENARIO 2: Ultimos 20 pedidos de um cliente
PROMPT ===================================================================
EXPLAIN PLAN FOR
SELECT pedido_id, data_pedido, status, valor_total
  FROM pedidos
 WHERE cliente_id = 4242
 ORDER BY data_pedido DESC
 FETCH FIRST 20 ROWS ONLY;
SELECT plan_table_output FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, NULL, 'TYPICAL'));
SET AUTOTRACE TRACEONLY STATISTICS
SELECT pedido_id, data_pedido, status, valor_total
  FROM pedidos
 WHERE cliente_id = 4242
 ORDER BY data_pedido DESC
 FETCH FIRST 20 ROWS ONLY;
SELECT pedido_id, data_pedido, status, valor_total
  FROM pedidos
 WHERE cliente_id = 4242
 ORDER BY data_pedido DESC
 FETCH FIRST 20 ROWS ONLY;
SET AUTOTRACE OFF

PROMPT
PROMPT ===================================================================
PROMPT CENARIO 3: Pedidos de um dia (funcao TRUNC na coluna) - depois: intervalo de datas
PROMPT ===================================================================
EXPLAIN PLAN FOR
SELECT COUNT(*), SUM(valor_total)
  FROM pedidos
 WHERE data_pedido >= DATE '2025-03-15'
   AND data_pedido <  DATE '2025-03-16';
SELECT plan_table_output FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, NULL, 'TYPICAL'));
SET AUTOTRACE TRACEONLY STATISTICS
SELECT COUNT(*), SUM(valor_total)
  FROM pedidos
 WHERE data_pedido >= DATE '2025-03-15'
   AND data_pedido <  DATE '2025-03-16';
SELECT COUNT(*), SUM(valor_total)
  FROM pedidos
 WHERE data_pedido >= DATE '2025-03-15'
   AND data_pedido <  DATE '2025-03-16';
SET AUTOTRACE OFF

PROMPT
PROMPT ===================================================================
PROMPT CENARIO 4: Busca por CPF (comparacao com numero) - depois: comparacao com texto
PROMPT ===================================================================
EXPLAIN PLAN FOR
SELECT cliente_id, nome, email
  FROM clientes
 WHERE cpf = '10000156954';
SELECT plan_table_output FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, NULL, 'TYPICAL'));
SET AUTOTRACE TRACEONLY STATISTICS
SELECT cliente_id, nome, email
  FROM clientes
 WHERE cpf = '10000156954';
SELECT cliente_id, nome, email
  FROM clientes
 WHERE cpf = '10000156954';
SET AUTOTRACE OFF

PROMPT
PROMPT ===================================================================
PROMPT CENARIO 5: Relatorio de um mes (tabela inteira x particao)
PROMPT ===================================================================
EXPLAIN PLAN FOR
SELECT TRUNC(data_pedido) AS dia, status, COUNT(*) AS qtd, SUM(valor_total) AS total
  FROM pedidos
 WHERE data_pedido >= DATE '2025-09-01'
   AND data_pedido <  DATE '2025-10-01'
 GROUP BY TRUNC(data_pedido), status
 ORDER BY 1, 2;
SELECT plan_table_output FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, NULL, 'TYPICAL'));
SET AUTOTRACE TRACEONLY STATISTICS
SELECT TRUNC(data_pedido) AS dia, status, COUNT(*) AS qtd, SUM(valor_total) AS total
  FROM pedidos
 WHERE data_pedido >= DATE '2025-09-01'
   AND data_pedido <  DATE '2025-10-01'
 GROUP BY TRUNC(data_pedido), status
 ORDER BY 1, 2;
SELECT TRUNC(data_pedido) AS dia, status, COUNT(*) AS qtd, SUM(valor_total) AS total
  FROM pedidos
 WHERE data_pedido >= DATE '2025-09-01'
   AND data_pedido <  DATE '2025-10-01'
 GROUP BY TRUNC(data_pedido), status
 ORDER BY 1, 2;
SET AUTOTRACE OFF

SPOOL OFF
EXIT
