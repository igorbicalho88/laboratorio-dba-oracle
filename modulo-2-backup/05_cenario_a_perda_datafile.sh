#!/bin/bash
# =====================================================================
# Módulo 2 | Cenário A: o arquivo de dados da aplicação some do disco
# (falha de disco, exclusão acidental). Recuperação com RMAN só da
# tablespace afetada, com o restante do banco no ar.
# Rodar como oracle:  ./05_cenario_a_perda_datafile.sh
# =====================================================================
source "$(dirname "$0")/comum.sh"
iniciar_log 05_cenario_a_perda_datafile

ARQ=$(valor "ALTER SESSION SET CONTAINER = $PDB;
SELECT file_name FROM dba_data_files WHERE tablespace_name = 'LAB_DADOS';")
etapa "Situação normal"
ls -lh "$ARQ"
echo "Dados: $(contar)"

etapa "DESASTRE: o arquivo $ARQ é apagado"
rm -f "$ARQ"
ls -lh "$ARQ"

etapa "Efeito: a aplicação recebe erro; o resto do PDB continua no ar"
sql <<EOF
ALTER SYSTEM FLUSH BUFFER_CACHE;
ALTER SESSION SET CONTAINER = $PDB;
SELECT COUNT(*) FROM lab.pedidos;
SELECT COUNT(*) AS usuarios_do_pdb FROM dba_users;
EOF

etapa "RECUPERAÇÃO: tablespace offline -> RESTORE -> RECOVER -> online"
inicio=$SECONDS
sql <<EOF
ALTER SESSION SET CONTAINER = $PDB;
ALTER TABLESPACE lab_dados OFFLINE IMMEDIATE;
EOF
rman_cmd <<EOF
RESTORE TABLESPACE $PDB:LAB_DADOS;
RECOVER TABLESPACE $PDB:LAB_DADOS;
EOF
sql <<EOF
ALTER SESSION SET CONTAINER = $PDB;
ALTER TABLESPACE lab_dados ONLINE;
EOF
t=$((SECONDS - inicio))

etapa "Depois da recuperação"
ls -lh "$ARQ"
DEPOIS=$(contar)
echo "Dados: $DEPOIS"
resumo "Cenário A (perda do arquivo de dados): recuperado em $(duracao $t), sem perda de dados ($DEPOIS)"
