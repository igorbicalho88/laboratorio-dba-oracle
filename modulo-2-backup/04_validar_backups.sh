#!/bin/bash
# =====================================================================
# Módulo 2 | Script 04: os backups servem mesmo?
# O RMAN lê todos os backups como se fosse restaurar (sem gravar nada) e
# confere a integridade física e lógica de cada bloco.
# Rodar como oracle:  ./04_validar_backups.sh
# =====================================================================
source "$(dirname "$0")/comum.sh"
iniciar_log 04_validar_backups

inicio=$SECONDS
rman_cmd <<'EOF'
RESTORE DATABASE VALIDATE CHECK LOGICAL;
RESTORE ARCHIVELOG FROM TIME 'SYSDATE-1' VALIDATE;
REPORT NEED BACKUP;
REPORT OBSOLETE;
LIST BACKUP SUMMARY;
EOF
rc=$?
t=$((SECONDS - inicio))

etapa "Uso da Fast Recovery Area"
sql <<'EOF'
SELECT file_type, percent_space_used AS pct_usado, number_of_files AS arquivos FROM v$recovery_area_usage;
SELECT ROUND(space_limit/1024/1024/1024, 1) AS limite_gb, ROUND(space_used/1024/1024/1024, 1) AS usado_gb
  FROM v$recovery_file_dest;
COLUMN input_type FORMAT A15
COLUMN status FORMAT A12
SELECT TO_CHAR(start_time, 'DD/MM HH24:MI') AS inicio, input_type, status,
       ROUND(input_bytes/1024/1024) AS mb_lidos, ROUND(output_bytes/1024/1024) AS mb_gravados,
       time_taken_display AS duracao
  FROM v$rman_backup_job_details ORDER BY start_time;
EOF

[ $rc -eq 0 ] && resumo "Validação dos backups: OK em $(duracao $t), nenhum bloco corrompido" \
             || resumo "Validação dos backups: ERRO (código $rc)"
