# =====================================================================
# Módulo 2 - Backup e recuperação | funções comuns aos scripts
# Não rodar diretamente: os outros scripts carregam este arquivo.
# =====================================================================
source ~/.bash_profile >/dev/null 2>&1   # ORACLE_SID, ORACLE_HOME e PATH (necessário no cron)
PDB=FREEPDB1
PASTA="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$PASTA/logs"

# Grava tudo o que aparece na tela também em logs/<nome>.log
iniciar_log() {
  exec > >(tee "$PASTA/logs/$1.log") 2>&1
  echo "### $1 | $(date '+%d/%m/%Y %H:%M:%S') | $(hostname)"
}

etapa() { echo; echo "=================================================================="; echo ">>> $*"; echo "=================================================================="; }

# Bloco SQL como SYSDBA no CDB, mostrando cada comando no log.  Uso: sql <<'EOF' ... EOF
sql() {
  local f; f=$(mktemp /tmp/lab_XXXXXX.sql)
  { echo "SET ECHO ON FEEDBACK ON LINESIZE 200 PAGESIZE 100 TRIMSPOOL ON TAB OFF"; cat; echo "EXIT"; } > "$f"
  sqlplus -s / as sysdba @"$f"; local rc=$?; rm -f "$f"; return $rc
}

# Resultado único de uma consulta (sem cabeçalho).  Uso: X=$(valor "SELECT ...;")
valor() {
  sqlplus -s / as sysdba <<EOF | awk 'NF{$1=$1; print}'
SET HEADING OFF FEEDBACK OFF PAGESIZE 0 VERIFY OFF LINESIZE 300
$1
EXIT
EOF
}

# Comandos RMAN conectados ao CDB.  Uso: rman_cmd <<EOF ... EOF
rman_cmd() {
  local f; f=$(mktemp /tmp/lab_XXXXXX.rman)
  cat > "$f"
  rman target / cmdfile="$f"; local rc=$?; rm -f "$f"; return $rc
}

contar() {
  valor "ALTER SESSION SET CONTAINER = $PDB;
SELECT (SELECT COUNT(*) FROM lab.pedidos) || ' pedidos e '
    || (SELECT COUNT(*) FROM lab.itens_pedido) || ' itens' FROM dual;"
}

duracao() { printf '%d min %02d s' $(( $1 / 60 )) $(( $1 % 60 )); }

# Resumo de todos os cenários num só arquivo
resumo() { echo "$(date '+%d/%m %H:%M') | $*" | tee -a "$PASTA/logs/resumo.txt"; }

# Erro humano usado no cenário C: a rotina de expurgo deveria apagar pedidos
# antigos, mas rodou com a data errada e apagou o último mês (out/2025).
erro_expurgo() {
  sql <<EOF
ALTER SESSION SET CONTAINER = $PDB;
SET TIMING ON
DELETE FROM lab.itens_pedido
 WHERE pedido_id IN (SELECT pedido_id FROM lab.pedidos
                      WHERE data_pedido >= DATE '2025-10-01' AND data_pedido < DATE '2025-11-01');
DELETE FROM lab.pedidos
 WHERE data_pedido >= DATE '2025-10-01' AND data_pedido < DATE '2025-11-01';
COMMIT;
EOF
}
