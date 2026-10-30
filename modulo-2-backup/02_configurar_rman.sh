#!/bin/bash
# =====================================================================
# Módulo 2 | Script 02: política de backup do RMAN
# Rodar como oracle:  ./02_configurar_rman.sh
# =====================================================================
source "$(dirname "$0")/comum.sh"
iniciar_log 02_configurar_rman

rman_cmd <<'EOF'
# Guardar backups suficientes para voltar a qualquer momento dos últimos 7 dias
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 7 DAYS;
# Cópia automática do controlfile e do spfile a cada backup (essencial para recuperar do zero)
CONFIGURE CONTROLFILE AUTOBACKUP ON;
# Não copiar de novo arquivos idênticos já salvos (ex.: archivelogs)
CONFIGURE BACKUP OPTIMIZATION ON;
# Compressão BASIC: incluída na licença, sem custo extra
CONFIGURE DEVICE TYPE DISK BACKUP TYPE TO COMPRESSED BACKUPSET;
# Um archivelog só pode ser apagado depois de ter pelo menos um backup
CONFIGURE ARCHIVELOG DELETION POLICY TO BACKED UP 1 TIMES TO DISK;
SHOW ALL;
EOF
