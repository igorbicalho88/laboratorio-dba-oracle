#!/bin/bash
# =====================================================================
# Módulo 2 | Rotina de backup (chamada à mão ou pelo cron)
# Uso (como oracle):  ./backup_rman.sh nivel0 | nivel1 | archivelog
#   nivel0     backup incremental nível 0: todos os blocos usados (base da semana)
#   nivel1     backup incremental nível 1: só os blocos alterados desde o último backup
#   archivelog só os archivelogs ainda sem backup (permite voltar a qualquer minuto)
# =====================================================================
source "$(dirname "$0")/comum.sh"
TIPO="${1:-}"
case "$TIPO" in
  nivel0)     CMD="BACKUP INCREMENTAL LEVEL 0 DATABASE PLUS ARCHIVELOG TAG NIVEL0;" ;;
  nivel1)     CMD="BACKUP INCREMENTAL LEVEL 1 DATABASE PLUS ARCHIVELOG TAG NIVEL1;" ;;
  archivelog) CMD="ALTER SYSTEM ARCHIVE LOG CURRENT;
BACKUP ARCHIVELOG ALL NOT BACKED UP 1 TIMES TAG ARCH;" ;;
  *) echo "Uso: $0 nivel0 | nivel1 | archivelog"; exit 1 ;;
esac
iniciar_log "backup_${TIPO}_$(date +%Y%m%d_%H%M)"

inicio=$SECONDS
rman_cmd <<EOF
CROSSCHECK BACKUP;
CROSSCHECK ARCHIVELOG ALL;
$CMD
DELETE NOPROMPT OBSOLETE;
DELETE NOPROMPT EXPIRED BACKUP;
LIST BACKUP SUMMARY;
EOF
rc=$?
t=$((SECONDS - inicio))

TAMANHO=$(valor "SELECT ROUND(SUM(output_bytes)/1024/1024) || ' MB gravados (' || ROUND(SUM(input_bytes)/1024/1024) || ' MB lidos)'
  FROM v\$rman_backup_job_details WHERE start_time >= SYSDATE - ($t + 60) / 86400;")
if [ $rc -eq 0 ]; then
  resumo "Backup $TIPO: OK em $(duracao $t), $TAMANHO"
else
  resumo "Backup $TIPO: ERRO (código $rc) - ver logs/backup_${TIPO}_*.log"
fi
exit $rc
