#!/bin/bash
systemctl stop minio.service
systemctl disable minio.service
rm -f /etc/systemd/system/minio.service
rm -f /etc/default/minio
systemctl daemon-reload
rm -rf /data/minio
rpm -ivh minio-20231111081441.0.0.x86_64.rpm
rpm -qa | grep minio
rpm -e minio-20231111081441.0.0.x86_64
/usr/local/bin/minio
ls -l /usr/local/bin/minio
rm -f /usr/local/bin/minio
rm -f /var/log/minio.log