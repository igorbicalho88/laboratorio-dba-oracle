#!/bin/bash
# =====================================================================
# Módulo 2 | Cenário B: UPDATE sem WHERE em produção
# Uma promoção de um produto foi aplicada ao catálogo inteiro.
# Diagnóstico com Flashback Query e correção com Flashback Table:
# só a tabela volta no tempo, sem restaurar backup e sem parar o banco.
# Rodar como oracle:  ./06_cenario_b_update_sem_where.sh
# =====================================================================
source "$(dirname "$0")/comum.sh"
iniciar_log 06_cenario_b_update_sem_where

sql <<'EOF'
ALTER SESSION SET CONTAINER = FREEPDB1;
-- Lição da primeira execução: o Flashback Table refaz as linhas de PRODUTOS
-- (apaga e insere), e para cada linha o Oracle confere a chave estrangeira em
-- ITENS_PEDIDO. Sem índice em itens_pedido.produto_id, seriam 5 mil leituras
-- completas de 10 milhões de linhas: o comando "travou". O índice resolve.
SET TIMING ON
CREATE INDEX IF NOT EXISTS lab.ix_itens_produto ON lab.itens_pedido (produto_id) ONLINE;
SET TIMING OFF
-- Pré-requisito do Flashback Table: permitir que as linhas mudem de lugar
ALTER TABLE lab.produtos ENABLE ROW MOVEMENT;
COLUMN scn_antes NEW_VALUE scn_antes
SELECT TO_CHAR(current_scn) AS scn_antes FROM v$database;

PROMPT
PROMPT >>> Situação normal
SELECT COUNT(*) AS produtos, MIN(preco), MAX(preco), SUM(preco) AS soma_precos FROM lab.produtos;

PROMPT
PROMPT >>> ERRO: a promoção era só para o produto 42, mas o WHERE ficou de fora
UPDATE lab.produtos SET preco = 9.90;
COMMIT;
SELECT COUNT(*) AS produtos, MIN(preco), MAX(preco), SUM(preco) AS soma_precos FROM lab.produtos;

PROMPT
PROMPT >>> Diagnóstico com Flashback Query: o que mudou e quando
SELECT versions_operation AS op, versions_starttime AS quando, preco
  FROM lab.produtos VERSIONS BETWEEN SCN &scn_antes AND MAXVALUE
 WHERE produto_id = 1 ORDER BY versions_startscn NULLS FIRST;
SELECT produto_id, preco AS preco_antes FROM lab.produtos AS OF SCN &scn_antes WHERE produto_id <= 5 ORDER BY 1;

PROMPT
PROMPT >>> CORREÇÃO: a tabela volta ao momento anterior ao erro
SET TIMING ON
FLASHBACK TABLE lab.produtos TO SCN &scn_antes;
SET TIMING OFF
SELECT COUNT(*) AS produtos, MIN(preco), MAX(preco), SUM(preco) AS soma_precos FROM lab.produtos;
EOF

resumo "Cenário B (UPDATE sem WHERE): Flashback Table, ver tempo em logs/06_cenario_b_update_sem_where.log"
