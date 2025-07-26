# Backup Guide

Use `pg_dump` to back up the Postgres database and copy Element configuration files.

```bash
pct exec <vmid> -- bash -c 'pg_dump -U synapse synapse > /backup/synapse.sql'
pct exec <vmid> -- bash -c 'tar czf /backup/element-config.tgz /opt/chat/element'
```

Restore by importing the SQL dump and untarring the config files.
