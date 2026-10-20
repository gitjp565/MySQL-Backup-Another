#!/bin/bash

# ================= 配置区域 =================
# MySQL 连接信息
DB_USER="root"
DB_PASS="Bsri@001" 
DB_NAME="propertymanagement"

# 备份文件存储配置
LOCAL_BACKUP_DIR="/backup/mysql_local"
REMOTE_IP="10.84.11.13"
REMOTE_USER="root"
REMOTE_DIR="/backup/mysql_remote"
# rsync -avz --password-file=/etc/rsync_client.pwd /backup/mysql_local backupuser@10.84.11.13::mysql_backup/

# 保留天数
RETENTION_DAYS=20

# 文件命名（包含日期）
DATE=$(date +%Y%m%d_%H%M%S)
FILENAME="backup_${DB_NAME}_${DATE}.sql.gz"
# ============================================

# 确保本地目录存在
mkdir -p "${LOCAL_BACKUP_DIR}"

# 1. 执行备份并压缩 (使用 --single-transaction 避免锁表)
mysqldump -u"${DB_USER}" -p"${DB_PASS}" --single-transaction "${DB_NAME}" | gzip > "${LOCAL_BACKUP_DIR}/${FILENAME}"

# 2. 检查备份是否成功（文件大小大于 0）
if [ -s "${LOCAL_BACKUP_DIR}/${FILENAME}" ]; then
    echo "$(date): 本地备份成功: ${FILENAME}"
    
	# 3. 清理本地过期备份 这个语句必须在 rsync 命令之前执行。因为 rsync 是根据本地现有文件来同步远程的，如果本地还没删，远程就不会删
	find "${LOCAL_BACKUP_DIR}" -name "backup_*.sql.gz" -type f -mtime +${RETENTION_DAYS} -exec rm {} \;
    # 4. 传输到远程服务器
    # 原 scp 命令
	# scp "${LOCAL_BACKUP_DIR}/${FILENAME}" "${REMOTE_USER}@${REMOTE_IP}:${REMOTE_DIR}/"

	# 替换为 rsync 将本地备份目录同步到远程，并强制保持一致（删除远程多余文件）
	rsync -avz --delete-delay --password-file=/etc/rsync_client.pwd \
  "${LOCAL_BACKUP_DIR}/" \
  backupuser@10.84.11.13::mysql_backup/
    
    if [ $? -eq 0 ]; then
        echo "$(date): 远程传输成功"
    else
        echo "$(date): 远程传输失败" >&2
    fi
else
    echo "$(date): 备份失败，文件为空" >&2
    # 可以在此处添加邮件报警
    exit 1
fi



# 5. 清理远程过期备份 (通过 SSH 在远端执行 find 命令)
#ssh "${REMOTE_USER}@${REMOTE_IP}" "find ${REMOTE_DIR} -name 'backup_*.sql.gz' -type f -mtime +${RETENTION_DAYS} -exec rm {} \;"