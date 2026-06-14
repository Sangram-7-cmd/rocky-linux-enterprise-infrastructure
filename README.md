# Linux Infrastructure Lab — Rocky Linux

A complete client-server infrastructure built from scratch on Rocky Linux,
simulating a real-world enterprise environment across 5 virtual machines.

---

## Infrastructure Overview

```
192.168.1.0/24
│
├── 192.168.1.10   Server 1  →  DNS, Web, NFS, Samba, Mail, NIS, Autofs
├── 192.168.1.20   Server 2  →  FTP, DHCP, Backup
├── 192.168.1.102  Client 1  →  Rocky Linux Client
├── 192.168.1.104  Client 2  →  Ubuntu Client
└── 192.168.1.107  Client 3  →  Windows Client
```

| Machine  | OS          | IP             | Role                              |
|----------|-------------|----------------|-----------------------------------|
| Server 1 | Rocky Linux | 192.168.1.10   | DNS, Web, NFS, Samba, Mail, NIS   |
| Server 2 | Rocky Linux | 192.168.1.20   | FTP, DHCP, Backup, Disk Quota     |
| Client 1 | Rocky Linux | 192.168.1.101  | Linux Client                      |
| Client 2 | Ubuntu      | 192.168.1.102  | Linux Client                      |
| Client 3 | Windows     | 192.168.1.103  | Windows Client                    |

---

## Services Configured

### Server 1 — Primary Server

| Service    | Tool    | Details                                               |
|------------|---------|-------------------------------------------------------|
| DNS        | BIND9   | 4 zones: urban.com, rural.com, web1.local, web2.local |
| Web        | Apache  | 5 virtual hosts — 3 HTTP, 2 HTTPS with mod_ssl        |
| File Share | NFS     | Shared directories mounted on Linux clients            |
| Mail       | Postfix | Two domains, inter-server delivery via DNS MX          |
| Autofs     | autofs  | Automatic NFS mount on client access                   |
| SSH        | OpenSSH | Key-based auth, hardened sshd_config                   |

### Server 2 — Secondary Server

| Service    | Tool      | Details                                          |
|------------|-----------|--------------------------------------------------|
| FTP        | vsftpd    | File transfer with user isolation                |
| DHCP       | dhcpd     | IP range 192.168.1.150-200, DNS + gateway push   |
| Backup     | rsync     | Automated daily backup from Server 1             |
| Ext Backup | rsync     | Second copy on separate disk /mnt/backup_disk    |
| Disk Quota | XFS Quota | Per-user storage limits on /home                 |

---

## Project Structure

```
linux-infrastructure-lab/
├── README.md
├── scripts/
│   └── backup.sh               ← automated backup script
├── configs/
│   ├── dns/                    ← BIND9 named.conf + zone files
│   ├── apache/                 ← virtual host configs
│   ├── postfix/                ← main.cf
│   ├── samba/                  ← smb.conf
│   ├── nfs/                    ← /etc/exports
│   ├── dhcp/                   ← dhcpd.conf
│   ├── ftp/                    ← vsftpd.conf
│   ├── autofs/                 ← auto.master + map files
│   └── ssh/                    ← sshd_config
└── docs/
    ├── step-by-step.md         ← what was done at each step
    ├── troubleshooting.md      ← real issues hit and how they were fixed
    └── network-diagram.md      ← full network layout
```

---

## Key Skills Demonstrated

- Linux system administration (Rocky Linux 8 / RHEL family)
- Network services configuration and integration
- Bash shell scripting (automated backup with logging and retention)
- DNS zone management and DNSSEC troubleshooting
- SELinux policy and context management
- Firewalld rules per service
- SSH hardening and key-based authentication
- XFS filesystem quota management
- LVM partition management
- Centralized authentication concepts (NIS)
- Mail server routing via DNS MX records
- Multi-service troubleshooting methodology

---

## How to Navigate This Repo

- Start with `docs/step-by-step.md` for the full build walkthrough
- See `docs/troubleshooting.md` for real debugging stories
- Config files in `configs/` are sanitized (passwords removed)
- `scripts/backup.sh` is the full working backup automation script

---

---

*Built as a hands-on Linux infrastructure lab targeting DevOps engineering skills.*
