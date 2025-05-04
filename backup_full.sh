#!/bin/bash

# --- Configurações ---
BACKUP_BASE_DIR="/var/lib/mysqltmp/Percona"
# Formato YYYY-MM-DD para o diretório da data
DATE=$(date +%Y-%m-%d)
# Formato HHMM para o nome do backup
TIME=$(date +%H%M)
# Diretório de destino do backup FULL
TARGET_DIR="$BACKUP_BASE_DIR/$DATE/FULL-$TIME"
# Arquivo de log para esta execução
LOG_FILE="$TARGET_DIR/backup_full.log"
# Usuário e senha do MySQL (use .my.cnf é mais seguro!)
#MYSQL_USER="seu_usuario_mysql"
#MYSQL_PASSWORD="sua_senha_mysql" # <--- Use .my.cnf em produção!

# --- Preparação ---

# Garante que o diretório base existe
mkdir -p "$BACKUP_BASE_DIR"

echo "--- Iniciando Backup FULL em $(date) ---" > "$LOG_FILE"
echo "Diretorio de destino: $TARGET_DIR" | tee -a "$LOG_FILE"

# Cria o diretório de destino para este backup
if mkdir "$TARGET_DIR"; then
    echo "Diretorio criado: $TARGET_DIR" | tee -a "$LOG_FILE"
else
    echo "ERRO: Falha ao criar o diretorio de destino: $TARGET_DIR" | tee -a "$LOG_FILE"
    exit 1 # Sai com erro se não conseguir criar o diretório
fi

# --- Executa XtraBackup (FULL) ---
# Se estiver usando .my.cnf, remova --user e --password
xtrabackup --backup \
           --target-dir="$TARGET_DIR" \
           --compress \
           --compress-threads=4 \
           #--user="$MYSQL_USER" \ # Descomente se não usar .my.cnf
           #--password="$MYSQL_PASSWORD" \ # Descomente se não usar .my.cnf
           >> "$LOG_FILE" 2>&1 # Redireciona stdout e stderr para o log

EXIT_STATUS=$? # Captura o código de saída do xtrabackup

if [ $EXIT_STATUS -eq 0 ]; then
    echo "--- Backup FULL Concluido com Sucesso em $(date) ---" | tee -a "$LOG_FILE"
else
    echo "--- ERRO: Backup FULL Falhou em $(date) com codigo de saida $EXIT_STATUS ---" | tee -a "$LOG_FILE"
    # Você pode adicionar aqui um comando para enviar um alerta (email, etc.)
fi

# --- Limpeza (Opcional - Pode ser um script separado) ---
# Exemplo: Remover diretorios de backup (FULL ou INC) com mais de 7 dias
#echo "--- Iniciando Limpeza (removendo backups com mais de 7 dias) em $(date) ---" | tee -a "$LOG_FILE"
# Encontra diretorios de backup (FULL-* ou INC-*) com mais de 7 dias e os remove
#find "$BACKUP_BASE_DIR" -maxdepth 2 -type d \( -name "FULL-*" -o -name "INC-*" \) -mtime +7 -print >> "$LOG_FILE"
#find "$BACKUP_BASE_DIR" -maxdepth 2 -type d \( -name "FULL-*" -o -name "INC-*" \) -mtime +7 -exec echo "Removendo {}" \; -exec rm -rf {} \; >> "$LOG_FILE" 2>&1
#echo "--- Limpeza Concluida em $(date) ---" | tee -a "$LOG_FILE"


exit $EXIT_STATUS # Sai com o código de saída do xtrabackup