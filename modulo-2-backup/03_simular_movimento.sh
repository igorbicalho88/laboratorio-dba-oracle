#!/bin/bash
# =====================================================================
# Módulo 2 | Script 03: um "dia de operação" entre o nível 0 e o nível 1
# Novos pedidos de nov/2025 (o particionamento INTERVAL cria a partição
# sozinho) e atualização de status. Mostra que o nível 1 copia só o que mudou.
# Rodar como oracle:  ./03_simular_movimento.sh
# =====================================================================
source "$(dirname "$0")/comum.sh"
iniciar_log 03_simular_movimento

echo "Antes: $(contar)"
sql <<EOF
ALTER SESSION SET CONTAINER = $PDB;
SET TIMING ON
INSERT INTO lab.pedidos (pedido_id, cliente_id, data_pedido, status, canal, valor_total)
SELECT 5000000 + LEVEL, MOD(ORA_HASH(LEVEL), 200000) + 1,
       DATE '2025-11-01' + MOD(ORA_HASH(LEVEL * 7), 30) + MOD(ORA_HASH(LEVEL * 11), 86400) / 86400,
       'PENDENTE', 'SITE', ROUND(20 + MOD(ORA_HASH(LEVEL * 19), 98000) / 100, 2)
  FROM dual CONNECT BY LEVEL <= 50000;
INSERT INTO lab.itens_pedido (item_id, pedido_id, produto_id, quantidade, preco_unitario)
SELECT 10000000 + LEVEL, 5000000 + MOD(LEVEL, 50000) + 1, MOD(ORA_HASH(LEVEL), 5000) + 1,
       1, ROUND(10 + MOD(ORA_HASH(LEVEL * 37), 99000) / 100, 2)
  FROM dual CONNECT BY LEVEL <= 100000;
UPDATE lab.pedidos SET status = 'ENTREGUE'
 WHERE status = 'PENDENTE' AND data_pedido >= DATE '2025-09-01' AND data_pedido < DATE '2025-10-01';
COMMIT;
SET TIMING OFF
SELECT partition_name, high_value FROM dba_tab_partitions
 WHERE table_owner = 'LAB' AND table_name = 'PEDIDOS' AND partition_position >= 34;
EOF
echo "Depois: $(contar)"
