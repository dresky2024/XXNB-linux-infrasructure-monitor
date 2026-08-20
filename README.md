# Linux Infrastructure Monitor

Bash-мониторинг Linux-систем с автоматическим запуском через cron и развёртыванием через Ansible.

## Возможности

- проверка CPU и RAM;
- проверка дискового пространства и inode;
- проверка ping, TCP-порта и HTTP-сервиса;
- проверка systemd-служб SSH и Nginx;
- email- и Telegram-уведомления;
- защита от повторных уведомлений;
- уведомления о восстановлении;
- timestamp-логирование;
- ротация логов через logrotate;
- подготовка к развёртыванию на нескольких серверах через Ansible.

## Запуск

```bash
chmod +x resource-check.sh run-monitor.sh
./resource-check.sh

*/5 * * * * /home/trainee/linux-admin-lab/run-monitor.sh
