#!/bin/bash
# =====================================================================
# Módulo 2 | Cenário C, solução 2: o mesmo erro, resolvido com Flashback
# O Flashback Database desfaz as mudanças usando os logs de flashback,
# sem restaurar nenhum arquivo do backup. Comparar o tempo com o script 07.
# Rodar como oracle:  ./08_cenario_c_flashback_pdb.sh
# =====================================================================
source "$(dirname "$0")/comum.sh"
iniciar_log 08_cenario_c_flashback_pdb

etapa "Antes da rotina: ponto de restauração"
sql <<'EOF'
CREATE RESTORE POINT antes_expurgo_2;
SELECT name, scn, time FROM v$restore_point;
EOF
ANTES=$(contar)
echo "Dados: $ANTES"

etapa "ERRO: o mesmo expurgo com a data errada"
erro_expurgo
echo "Dados: $(contar)"

etapa "RECUPERAÇÃO com Flashback: fechar PDB -> FLASHBACK -> OPEN RESETLOGS"
inicio=$SECONDS
sql <<EOF
WHENEVER SQLERROR EXIT FAILURE
ALTER PLUGGABLE DATABASE $PDB CLOSE IMMEDIATE;
FLASHBACK PLUGGABLE DATABASE $PDB TO RESTORE POINT antes_expurgo_2;
ALTER PLUGGABLE DATABASE $PDB OPEN RESETLOGS;
SELECT name, open_mode FROM v\$pdbs;
EOF
t=$((SECONDS - inicio))
DEPOIS=$(contar)
echo "Dados: $DEPOIS"
resumo "Cenário C com Flashback PDB: PDB de volta em $(duracao $t) | antes do erro: $ANTES | depois: $DEPOIS"

etapa "Limpeza dos pontos de restauração"
sql <<'EOF'
DROP RESTORE POINT antes_expurgo_1;
DROP RESTORE POINT antes_expurgo_2;
EOF

echo; echo "===== RESUMO DO MÓDULO 2 ====="; cat "$PASTA/logs/resumo.txt"
