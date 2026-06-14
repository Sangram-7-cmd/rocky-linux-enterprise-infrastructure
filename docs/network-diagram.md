# Network Diagram

## Lab Network Layout

```
Internet
    │
    │ (gateway)
192.168.1.1
    │
    └──────────────────────────────────────────────────────┐
                    192.168.1.0/24                         │
                                                           │
    ┌──────────────────────────────────────────────────────┘
    │
    ├── 192.168.1.10   SERVER 1 (Primary)
    │       ├── DNS      (BIND9 — port 53)
    │       ├── HTTP     (Apache — port 80)
    │       ├── HTTPS    (Apache + SSL — port 443)
    │       ├── NFS      (nfs-server — port 2049)
    │       ├── Samba    (smbd — ports 139, 445)
    │       ├── NIS      (ypserv — port 111)
    │       ├── SMTP     (Postfix — port 25)
    │       └── SSH      (OpenSSH — port 22)
    │
    ├── 192.168.1.20   SERVER 2 (Secondary)
    │       ├── FTP      (vsftpd — port 21)
    │       ├── DHCP     (dhcpd — port 67/68)
    │       ├── SMTP     (Postfix — port 25)
    │       ├── SSH      (OpenSSH — port 22)
    │       └── Backup   (rsync receiver from Server 1)
    │
    ├── 192.168.1.101  CLIENT 1 (Rocky Linux)
    │       ├── Mounts NFS from Server 1
    │       ├── Authenticates via NIS (Server 1)
    │       ├── Autofs mounts on demand
    │       └── Receives DHCP from Server 2
    │
    ├── 192.168.1.102  CLIENT 2 (Ubuntu)
    │       ├── Mounts NFS from Server 1
    │       └── Uses Server 1 as DNS
    │
    └── 192.168.1.103  CLIENT 3 (Windows)
            └── Accesses Samba share on Server 1

DHCP Pool: 192.168.1.150 — 192.168.1.200
           (assigned dynamically to any new client)
```

---

## DNS Zones

```
Server 1 BIND9 (192.168.1.10) is authoritative for:

web1.local
├── dashboard.web1.local  → 192.168.1.10
├── portfolio.web1.local  → 192.168.1.10
└── devops.web1.local     → 192.168.1.10

web2.local
├── coffee.web2.local     → 192.168.1.10
└── notes.web2.local      → 192.168.1.10

urban.com
├── mail.urban.com        → 192.168.1.10  (MX record)
└── ns1.urban.com         → 192.168.1.10

rural.com
├── mail.rural.com        → 192.168.1.20  (MX record)
└── ns1.rural.com         → 192.168.1.10
```

---

## Mail Flow

```
Client (192.168.1.101)
        │
        │  sends to user@rural.com
        │  connects to Server 1 port 25
        ▼
Server 1 — Postfix (mail.urban.com)
        │
        │  rural.com not in mydestination
        │  DNS MX lookup for rural.com
        │  → mail.rural.com → 192.168.1.20
        │
        └──port 25──► Server 2 — Postfix (mail.rural.com)
                            │
                            │  rural.com in mydestination
                            │  deliver to local mailbox
                            ▼
                       /home/user/Maildir/
```

---

## Backup Flow

```
Every night at 2 AM:

Server 1 (192.168.1.10)
        │
        │  tar packs /etc /home /srv /var/named /var/www
        │  creates /tmp/server1_backup_DATE.tar.gz
        │
        ├──rsync over SSH──► Server 2 /backup/server1/
        │                    (OS disk — copy 1)
        │
        └──rsync over SSH──► Server 2 /mnt/backup_disk/server1/
                             (external disk — copy 2)

Retention: 7 days
           backups older than 7 days auto-deleted
```

---

## Storage Layout — Server 2

```
/dev/sda  (OS Disk — 20GB)
├── /           OS and services
├── /backup/    backup copy 1 (from Server 1)
└── swap

/dev/sdb  (External Backup Disk — 20GB)
└── /mnt/backup_disk/    backup copy 2 (from Server 1)
                         survives OS disk failure
```
