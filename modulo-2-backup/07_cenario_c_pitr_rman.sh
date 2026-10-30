#!/bin/bash
# =====================================================================
# Módulo 2 | Cenário C, solução 1: recuperação até um ponto no tempo (PITR)
# A rotina de expurgo rodou com a data errada e apagou o último mês de
# pedidos e itens em várias tabelas. O PDB volta, com RMAN, ao instante
# anterior ao expurgo (restaura os arquivos e reaplica os archivelogs).
# Rodar como oracle:  ./07_cenario_c_pitr_rman.sh   (o PDB fica fechado alguns minutos)
# =====================================================================
source "$(dirname "$0")/comum.sh"
iniciar_log 07_cenario_c_pitr_rman

etapa "Antes da rotina: ponto de restauração (boa prática antes de qualquer processo em massa)"
sql <<'EOF'
CREATE RESTORE POINT antes_expurgo_1;
SELECT name, scn, time FROM v$restore_point;
EOF
SCN=$(valor "SELECT scn FROM v\$restore_point WHERE name = 'ANTES_EXPURGO_1';")
ANTES=$(contar)
echo "Dados: $ANTES | SCN do ponto de restauração: $SCN"

etapa "ERRO: expurgo apaga out/2025 em vez de dados antigos"
erro_expurgo
echo "Dados: $(contar)"

etapa "RECUPERAÇÃO com RMAN: fechar PDB -> RESTORE -> RECOVER UNTIL SCN -> OPEN RESETLOGS"
inicio=$SECONDS
sql <<EOF
WHENEVER SQLERROR EXIT FAILURE
ALTER PLUGGABLE DATABASE $PDB CLOSE IMMEDIATE;
EOF
rman_cmd <<EOF
RUN {
  SET UNTIL SCN $SCN;
  RESTORE PLUGGABLE DATABASE $PDB;
  RECOVER PLUGGABLE DATABASE $PDB;
}
EOF
sql <<EOF
ALTER PLUGGABLE DATABASE $PDB OPEN RESETLOGS;
SELECT name, open_mode FROM v\$pdbs;
EOF
t=$((SECONDS - inicio))
DEPOIS=$(contar)
echo "Dados: $DEPOIS"
resumo "Cenário C com RMAN PITR: PDB de volta em $(duracao $t) | antes do erro: $ANTES | depois: $DEPOIS"

etapa "Depois de um OPEN RESETLOGS, novo backup completo (boa prática)"
"$PASTA/backup_rman.sh" nivel0 >/dev/null
tail -1 "$PASTA/logs/resumo.txt"
