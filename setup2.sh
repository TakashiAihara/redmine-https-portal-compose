docker exec -it mysql mysql_config_editor set --host=localhost --user=redmine --password

cat << '_EOQ_' | docker exec --interactive mysql mysql redmine
UPDATE `roles` SET `permissions` = NULL WHERE `id` = '1' OR `id` = '2';
_EOQ_

# NETWORK=$(docker container inspect redmine --format='{{.HostConfig.NetworkMode}}') && \
# SUBNET=$(docker network inspect ${NETWORK} --format='{{range .IPAM.Config}}{{.Subnet}}{{end}}') && \
# GATEWAY=$(docker network inspect ${NETWORK} --format='{{range .IPAM.Config}}{{.Gateway}}{{end}}') && \
# sed -i.org /etc/postfix/main.cf \
    # -e "/^#mynetworks = 168.100.189.0\/28/ s/^#//" \
    # -e "/^mynetworks/ s|168.100.189.0/28|${SUBNET}|" \
    # -e "/^inet_interfaces/ s|localhost\$|localhost, 127.0.0.1, ${GATEWAY}|" && \
# echo ${NETWORK}, ${SUBNET}, ${GATEWAY} && \
# postconf -n | egrep "inet_interfaces|mynetworks" && \
# systemctl restart postfix 

docker exec redmine bundle install && \
docker exec redmine passenger-config restart-app /usr/src/redmine

cat << '_EOF_' > /etc/systemd/system/backup-redmine-db.service
[Unit]
Description=Backup Redmine database

[Service]
Type=oneshot
ExecStart=/bin/bash -c "docker exec mysql mysqldump redmine | gzip > /srv/redmine/backup/redmine_db_`date +%F`.sql.gz" && \
 find /srv/redmine/backup -name redmine_db_*.sql.gz -mtime +14 | xargs rm
_EOF_

cat << '_EOF_' > /etc/systemd/system/backup-redmine-db.timer
[Unit]
Description=Backup Redmine database

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
_EOF_

cat << '_EOF_' > /etc/systemd/system/backup-redmine-files.service
[Unit]
Description=Backup Redmine files

[Service]
Type=oneshot
ExecStart=/bin/bash -c "cd /srv/redmine && tar -cf backup/redmine_files_`date +%F`.tar.gz files" && \
 find /srv/redmine/backup -name redmine_files_*.tar.gz -mtime +14 | xargs rm
_EOF_

cat << '_EOF_' > /etc/systemd/system/backup-redmine-files.timer
[Unit]
Description=Backup Redmine files

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
_EOF_

mkdir --parents --verbose /srv/redmine/backup && \
systemctl daemon-reload && \
systemctl enable backup-redmine-{db,files}.timer && \
systemctl list-unit-files | egrep "STATE|backup" && \
systemctl list-timers --all
