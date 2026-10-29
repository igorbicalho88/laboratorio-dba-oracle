-- =====================================================================
-- Módulo 1 - Tuning | Script 03: as otimizações
-- Rodar como LAB:  sqlplus lab/<senha>@//localhost:1521/FREEPDB1 @03_otimizacoes.sql
-- =====================================================================
WHENEVER SQLERROR EXIT FAILURE
SET TIMING ON
SET ECHO ON
SET LINESIZE 200 PAGESIZE 100
SPOOL logs/otimizacoes.log

-- Cenário 1: toda chave estrangeira usada em junções/consultas precisa de índice.
-- (Sem ele, além da lentidão, um DELETE no pedido trava a tabela de itens inteira.)
CREATE INDEX ix_itens_pedido ON itens_pedido (pedido_id);

-- Cenário 5: particionar PEDIDOS por mês, ONLINE (a tabela continua disponível
-- para leitura e escrita durante a operação). Novos meses viram partições sozinhos.
ALTER TABLE pedidos MODIFY
  PARTITION BY RANGE (data_pedido) INTERVAL (NUMTOYMINTERVAL(1, 'MONTH'))
  (PARTITION p_2023_01 VALUES LESS THAN (DATE '2023-02-01'))
  ONLINE UPDATE INDEXES;

-- Cenário 2: índice composto (cliente, data). Atende o filtro E a ordenação,
-- então o Oracle lê só as 20 linhas que precisa. Também cobre a FK de clientes.
CREATE INDEX ix_pedidos_cliente_data ON pedidos (cliente_id, data_pedido);

-- Cenário 3: índice por data, LOCAL (um pedaço de índice por partição).
-- O índice só é usado se a consulta não aplicar função na coluna:
-- a correção principal é reescrever o filtro como intervalo de datas.
CREATE INDEX ix_pedidos_data ON pedidos (data_pedido) LOCAL;

-- Cenário 4: não há o que criar. O índice do CPF já existe; a consulta é que
-- compara texto com número e força o Oracle a converter a coluna (TO_NUMBER),
-- o que impede o uso do índice. A correção é na aplicação: comparar com texto.

-- Estatísticas atualizadas depois das mudanças
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'PEDIDOS', cascade => TRUE)
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'ITENS_PEDIDO', cascade => TRUE)

SET ECHO OFF
PROMPT
PROMPT Partições criadas em PEDIDOS:
SELECT COUNT(*) AS particoes, SUM(num_rows) AS linhas
  FROM user_tab_partitions WHERE table_name = 'PEDIDOS';
COLUMN index_name FORMAT A28
SELECT index_name, partitioned, status FROM user_indexes
 WHERE table_name IN ('PEDIDOS', 'ITENS_PEDIDO') ORDER BY table_name, index_name;
SPOOL OFF
EXIT
