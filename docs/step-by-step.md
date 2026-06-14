# Step-by-Step Build Log

This document covers what was configured at each step of the project.

---

## Step 1 — OS Installation

- Installed Rocky Linux (minimal) on both servers
- Server 1: 100GB disk, manual install
- Server 2: 20GB disk, automatic install
- Verified boot on both machines

---

## Step 2 — Network Configuration

Assigned static IPs using nmcli:

```bash
nmcli con mod "connection-name" ipv4.addresses 192.168.1.10/24
nmcli con mod "connection-name" ipv4.gateway 192.168.1.1
nmcli con mod "connection-name" ipv4.dns 192.168.1.10
nmcli con mod "connection-name" ipv4.method manual
nmcli con up "connection-name"
```

Set hostnames:
```bash
hostnamectl set-hostname server1.local   # on Server 1
hostnamectl set-hostname server2.local   # on Server 2
```

Verified connectivity:
```bash
ping -c 3 192.168.1.20    # from Server 1 to Server 2
ping -c 3 192.168.1.10    # from Server 2 to Server 1
```

---

## Step 3 — Package Management

Verified DNF repositories and updated both servers:
```bash
dnf update -y
dnf repolist
```

---

## Step 4 — SSH Configuration

Generated SSH key pairs:
```bash
sudo -i
ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa
ssh-copy-id root@192.168.1.20
```

Hardened /etc/ssh/sshd_config:
```
PermitRootLogin prohibit-password
PasswordAuthentication no
MaxAuthTries 3
X11Forwarding no
```

Validated before reload:
```bash
sshd -t
systemctl reload sshd
```

---

## Step 5 — DNS Server (BIND9)

Installed BIND9 on Server 1:
```bash
dnf install bind bind-utils -y
```

Configured /etc/named.conf with 4 zones:
- web1.local
- web2.local
- urban.com
- rural.com

Created zone files in /var/named/ for each domain.

Each zone file contains:
- SOA record
- NS record
- A records for hosts
- MX records for mail domains

Set correct ownership:
```bash
chown named:named /var/named/urban /var/named/rural
```

Opened firewall:
```bash
firewall-cmd --permanent --add-service=dns
firewall-cmd --reload
```

Configured clients to use Server 1 as DNS via resolv.conf.

---

## Step 6 — Web Server (Apache)

Installed Apache:
```bash
dnf install httpd mod_ssl -y
```

Created 5 virtual hosts:
- dashboard.web1.local (HTTP)
- portfolio.web1.local (HTTP)
- devops.web1.local (HTTP)
- coffee.web2.local (HTTPS)
- notes.web2.local (HTTPS)

Each virtual host had its own:
- Document root under /var/www/
- Config file under /etc/httpd/conf.d/
- SELinux context set with semanage + restorecon

Generated self-signed SSL certificates for HTTPS sites:
```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/pki/tls/private/site.key \
    -out /etc/pki/tls/certs/site.crt
```

Opened firewall:
```bash
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --reload
```

---

## Step 7 — NFS Server

Installed NFS:
```bash
dnf install nfs-utils -y
```

Created shared directories:
```bash
mkdir -p /srv/nfs/shared
```

Configured /etc/exports:
```
/srv/nfs/shared   192.168.1.0/24(rw,sync,no_root_squash)
```

Exported and started:
```bash
exportfs -av
systemctl enable --now nfs-server
```

Mounted on Linux clients:
```bash
mount -t nfs 192.168.1.10:/srv/nfs/shared /mnt/nfs
```

---

## Step 8 — Samba Server

Installed Samba:
```bash
dnf install samba samba-client -y
```

Configured /etc/samba/smb.conf with shared directory.

Created Samba user:
```bash
smbpasswd -a username
```

Opened firewall:
```bash
firewall-cmd --permanent --add-service=samba
firewall-cmd --reload
```

Verified from Windows client via \\192.168.1.10\sharename

---

## Step 9 — NIS Server

Installed NIS packages:
```bash
dnf install ypserv yp-tools ypbind -y
```

Set NIS domain:
```bash
nisdomainname lab.local
```

Initialized NIS database:
```bash
/usr/lib64/yp/ypinit -m
```

Configured clients to bind to NIS server.

---

## Step 10 — Autofs

Installed autofs:
```bash
dnf install autofs -y
```

Configured /etc/auto.master:
```
/mnt/auto   /etc/auto.nfs
```

Configured /etc/auto.nfs:
```
shared   -rw,sync   192.168.1.10:/srv/nfs/shared
```

Started autofs:
```bash
systemctl enable --now autofs
```

Verified: accessing /mnt/auto/shared triggered automatic mount.

---

## Step 11 — Mail Server (Postfix)

Installed Postfix:
```bash
dnf install postfix -y
```

Configured /etc/postfix/main.cf on Server 1:
```
myhostname = mail.urban.com
mydomain = urban.com
mydestination = mail.urban.com, urban.com, localhost
mynetworks = 127.0.0.0/8 192.168.1.0/24
home_mailbox = Maildir/
```

Configured Server 2 for rural.com domain similarly.

DNS MX records handle routing between servers automatically.

Key fix: Server 1 must use itself (127.0.0.1) as DNS so it can
resolve local MX records for inter-server mail delivery.

Opened firewall:
```bash
firewall-cmd --permanent --add-service=smtp
firewall-cmd --reload
```

---

## Step 12 — FTP Server (vsftpd)

Installed vsftpd on Server 2:
```bash
dnf install vsftpd -y
```

Configured /etc/vsftpd/vsftpd.conf:
```
anonymous_enable=NO
local_enable=YES
write_enable=YES
chroot_local_user=YES
```

Opened firewall:
```bash
firewall-cmd --permanent --add-service=ftp
firewall-cmd --reload
```

---

## Step 13 — Backup System

Created backup script on Server 1 at /opt/scripts/backup.sh

Script performs:
1. tar archives /etc /home /srv /var/named /var/www
2. rsync sends archive to Server 2 /backup/server1/
3. Deletes local temp file
4. Purges backups older than 7 days on Server 2

Scheduled via root crontab:
```
0 2 * * * /opt/scripts/backup.sh >> /var/log/backup.log 2>&1
```

Set up passwordless SSH from Server 1 root to Server 2 root.

---

## Step 14 — External Backup

Added a second virtual disk to Server 2 in VMware (20GB).

Partitioned, formatted, and mounted:
```bash
fdisk /dev/sdb          # create partition
mkfs.xfs /dev/sdb1      # format
mkdir -p /mnt/backup_disk
mount /dev/sdb1 /mnt/backup_disk
```

Made permanent in /etc/fstab:
```
UUID=xxxx   /mnt/backup_disk   xfs   defaults   0 2
```

Updated backup script to send to both locations:
- /backup/server1/         (OS disk copy)
- /mnt/backup_disk/server1/ (external disk copy)

---

## Step 15 — Disk Quota (XFS)

/home was already on its own LVM partition (xfs).

Enabled quota in /etc/fstab:
```
/dev/mapper/rl-home   /home   xfs   defaults,uquota   0 0
```

Rebooted to apply mount options.

Verified quota active:
```bash
xfs_quota -x -c 'state' /home
# Accounting: ON / Enforcement: ON
```

Set limits on testuser:
```bash
xfs_quota -x -c 'limit bsoft=800m bhard=1g testuser' /home
```

Tested enforcement:
```bash
su - testuser
dd if=/dev/zero of=/home/testuser/testfile bs=1M count=1100
# Result: Disk quota exceeded — stopped at 1GB hard limit ✓
```

---

## Step 16 — DHCP Server

Installed dhcp-server on Server 2:
```bash
dnf install dhcp-server -y
```

Configured /etc/dhcp/dhcpd.conf:
```
subnet 192.168.1.0 netmask 255.255.255.0 {
    range 192.168.1.150 192.168.1.200;
    option routers 192.168.1.1;
    option domain-name-servers 192.168.1.10;
    default-lease-time 600;
    max-lease-time 7200;
}
```

Started DHCP server:
```bash
systemctl enable --now dhcpd
firewall-cmd --permanent --add-service=dhcp
firewall-cmd --reload
```

Verified: client set to DHCP received IP from 192.168.1.150-200 range.
