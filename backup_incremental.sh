#!/bin/bash

# --- Configurações ---
BACKUP_BASE_DIR="/var/lib/mysqltmp/Percona"
DATE=$(date +%Y-%m-%d)
TIME=$(date +%H%M)
# Diretório de destino do backup INCREMENTAL
TARGET_DIR="$BACKUP_BASE_DIR/$DATE/INC-$TIME"
# Arquivo de log para esta execução
LOG_FILE="$TARGET_DIR/backup_incremental.log"
# Usuário e senha do MySQL (use .my.cnf é mais seguro!)
#MYSQL_USER="seu_usuario_mysql" # <--- Use .my.cnf em produção!
#MYSQL_PASSWORD="sua_senha_mysql" # <--- Use .my.cnf em produção!

# --- Preparação ---

# Garante que o diretório base existe
mkdir -p "$BACKUP_BASE_DIR"

echo "--- Iniciando Backup INCREMENTAL em $(date) ---" > "$LOG_FILE"
echo "Diretorio de destino: $TARGET_DIR" | tee -a "$LOG_FILE"

# --- Encontra o diretorio do backup base (FULL ou ultimo INCREMENTAL) ---
# Encontra todos os diretorios de backup (FULL-* ou INC-*) ordenados cronologicamente
# maxdepth 2: procura apenas em $BACKUP_BASE_DIR/YYYY-MM-DD/*
PREVIOUS_BACKUPS=$(find "$BACKUP_BASE_DIR" -maxdepth 2 -type d \( -name "FULL-*" -o -name "INC-*" \) 2>/dev/null | sort)

# Verifica se encontrou algum backup anterior
if [ -z "$PREVIOUS_BACKUPS" ]; then
    echo "ERRO: Nenhum backup anterior encontrado em $BACKUP_BASE_DIR. Nao foi possivel realizar o backup incremental." | tee -a "$LOG_FILE"
    echo "--- Backup INCREMENTAL Falhou em $(date) ---" | tee -a "$LOG_FILE"
    exit 1
fi

# Pega a ultima linha (o diretorio do backup mais recente)
PREVIOUS_BACKUP_DIR=$(echo "$PREVIOUS_BACKUPS" | tail -n 1)

if [ -z "$PREVIOUS_BACKUP_DIR" ]; then
     echo "ERRO: Nao foi possivel determinar o diretorio do backup mais recente." | tee -a "$LOG_FILE"
     echo "--- Backup INCREMENTAL Falhou em $(date) ---" | tee -a "$LOG_FILE"
     exit 1
fi

echo "Base para o incremental (--incremental-basedir): $PREVIOUS_BACKUP_DIR" | tee -a "$LOG_FILE"

# Cria o diretório de destino para este backup incremental
if mkdir "$TARGET_DIR"; then
    echo "Diretorio criado: $TARGET_DIR" | tee -a "$LOG_FILE"
else
    echo "ERRO: Falha ao criar o diretorio de destino: $TARGET_DIR" | tee -a "$LOG_FILE"
    echo "--- Backup INCREMENTAL Falhou em $(date) ---" | tee -a "$LOG_FILE"
    exit 1 # Sai com erro se não conseguir criar o diretório
fi


# --- Executa XtraBackup (INCREMENTAL) ---
# SEU COMANDO CORRIGIDO COM --incremental-basedir
# Se estiver usando .my.cnf, remova --user e --password
xtrabackup --backup \
           --target-dir="$TARGET_DIR" \
           --incremental-basedir="$PREVIOUS_BACKUP_DIR" \
           --compress \
           --compress-threads=4 \
           #--user="$MYSQL_USER" \ # Descomente se não usar .my.cnf
           #--password="$MYSQL_PASSWORD" \ # Descomente se não usar .my.cnf
           >> "$LOG_FILE" 2>&1 # Redireciona stdout e stderr para o log

EXIT_STATUS=$? # Captura o código de saída do xtrabackup

if [ $EXIT_STATUS -eq 0 ]; then
    echo "--- Backup INCREMENTAL Concluido com Sucesso em $(date) ---" | tee -a "$LOG_FILE"
else
    echo "--- ERRO: Backup INCREMENTAL Falhou em $(date) com codigo de saida $EXIT_STATUS ---" | tee -a "$LOG_FILE"
    # Você pode adicionar aqui um comando para enviar um alerta (email, etc.)
fi

# A limpeza será feita pelo script de limpeza ou pelo script full para evitar concorrência ou deleções acidentais no meio de uma cadeia incremental.

exit $EXIT_STATUS # Sai com o código de saída do xtrabackup