#!/bin/bash

# --- Configurações ---
BACKUP_BASE_DIR="/var/lib/mysqltmp/Percona"
RETENTION_DAYS=7 # Quantos dias manter os backups
# Arquivo de log para a limpeza
LOG_FILE="/var/log/xtrabackup_cleanup.log"

echo "--- Iniciando Limpeza de Backups em $(date) (Retendo $RETENTION_DAYS dias) ---" >> "$LOG_FILE"

# Encontra diretorios de backup (FULL-* ou INC-*) com mais de RETENTION_DAYS dias
# -maxdepth 2: procura apenas em $BACKUP_BASE_DIR/YYYY-MM-DD/*
# -mtime +N: encontra arquivos/diretorios modificados a mais de N*24 horas
OLD_BACKUP_DIRS=$(find "$BACKUP_BASE_DIR" -maxdepth 2 -type d \( -name "FULL-*" -o -name "INC-*" \) -mtime +$RETENTION_DAYS 2>/dev/null)

if [ -z "$OLD_BACKUP_DIRS" ]; then
    echo "Nenhum backup antigo encontrado para remocao." >> "$LOG_FILE"
else
    echo "Diretorios antigos encontrados para remocao:" >> "$LOG_FILE"
    echo "$OLD_BACKUP_DIRS" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    echo "Removendo diretorios antigos..." >> "$LOG_FILE"

    # Loop seguro para remover cada diretorio encontrado
    echo "$OLD_BACKUP_DIRS" | while read dir; do
        if [ -d "$dir" ]; then # Verifica se ainda é um diretorio (evita erros se algo for removido externamente)
            echo "Removendo: $dir" >> "$LOG_FILE"
            rm -rf "$dir"
            if [ $? -ne 0 ]; then
                echo "ERRO ao remover $dir" >> "$LOG_FILE"
            fi
        fi
    done

    # Opcional: Remover diretorios de data vazios após remover os backups internos
    find "$BACKUP_BASE_DIR" -maxdepth 1 -type d -empty -delete >> "$LOG_FILE" 2>&1
fi

echo "--- Limpeza Concluida em $(date) ---" >> "$LOG_FILE"

exit 0