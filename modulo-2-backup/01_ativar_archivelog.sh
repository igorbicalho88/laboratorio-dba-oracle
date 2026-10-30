#!/bin/bash
# =====================================================================
# Módulo 2 | Script 01: Fast Recovery Area, modo ARCHIVELOG e Flashback
# Rodar como oracle:  ./01_ativar_archivelog.sh
# O banco é reiniciado uma vez (alguns segundos fora do ar).
# =====================================================================
source "$(dirname "$0")/comum.sh"
iniciar_log 01_ativar_archivelog

FRA=/opt/oracle/fast_recovery_area
mkdir -p "$FRA"

etapa "Espaço em disco disponível para a Fast Recovery Area"
df -h /opt/oracle

etapa "Situação antes"
sql <<'EOF'
SELECT log_mode, flashback_on FROM v$database;
SELECT property_value AS local_undo FROM database_properties WHERE property_name = 'LOCAL_UNDO_ENABLED';
SHOW PARAMETER db_recovery_file_dest
EOF

etapa "Fast Recovery Area (backups, archivelogs e logs de flashback) e retenção do flashback (24 h)"
sql <<EOF
WHENEVER SQLERROR EXIT FAILURE
ALTER SYSTEM SET db_recovery_file_dest_size = 25G SCOPE = BOTH;
ALTER SYSTEM SET db_recovery_file_dest = '$FRA' SCOPE = BOTH;
ALTER SYSTEM SET db_flashback_retention_target = 1440 SCOPE = BOTH;
EOF

etapa "Reinício em MOUNT para ligar o ARCHIVELOG"
sql <<'EOF'
WHENEVER SQLERROR EXIT FAILURE
SHUTDOWN IMMEDIATE
STARTUP MOUNT
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;
ALTER DATABASE FLASHBACK ON;
ALTER PLUGGABLE DATABASE ALL OPEN;
ALTER PLUGGABLE DATABASE ALL SAVE STATE;
EOF

etapa "Situação depois"
sql <<'EOF'
ARCHIVE LOG LIST
SELECT log_mode, flashback_on FROM v$database;
SELECT name, open_mode FROM v$pdbs;
ALTER SYSTEM ARCHIVE LOG CURRENT;
COLUMN name FORMAT A100
SELECT name, ROUND(blocks * block_size / 1024 / 1024) AS mb FROM v$archived_log WHERE name IS NOT NULL;
EOF
