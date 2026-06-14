# Real Troubleshooting Stories

These are actual issues encountered during the lab build and exactly how they were fixed.
This is more valuable than any tutorial — real problems, real debugging, real solutions.

---

## DNS — SERVFAIL on .com Domains

**Problem:**
```
nslookup mail.urban.com 192.168.1.10
** server can't find mail.urban.com: SERVFAIL
```

web1.local resolved fine but urban.com returned SERVFAIL.

**Root Cause:**
`urban.com` is a real internet domain with DNSSEC signatures.
BIND was trying to validate those signatures against our local zone — they
didn't match so BIND refused to serve the record.

`.local` domains worked because they don't exist on the internet
so there's no DNSSEC chain to validate against.

**Fix:**
Added `dnssec-validation no` to /etc/named.conf options block:
```
options {
    directory "/var/named";
    dnssec-validation no;
    recursion yes;
    allow-query { any; };
};
```

**Lesson:**
When using real domain names (like .com) in a private lab,
DNSSEC will conflict. Always disable it in lab environments.
In production, use fake TLDs like .local or .internal.

---

## DNS — Zone Files Permission Denied

**Problem:**
```
zone urban.com/IN: loading from master file urban failed: permission denied
zone rural.com/IN: loading from master file rural failed: permission denied
```

web1.local and web2.local loaded fine. urban and rural did not.

**Root Cause:**
The urban and rural zone files were owned by root.
Named runs as the `named` user and couldn't read root-owned files.
web1 and web2 zone files happened to have correct ownership already.

**Fix:**
```bash
chown named:named /var/named/urban
chown named:named /var/named/rural
systemctl restart named
```

**Lesson:**
All zone files in /var/named/ must be owned by the `named` user.
When you create a new file as root, always fix ownership immediately.

---

## Postfix — Duplicate Directives in main.cf

**Problem:**
```
postconf: warning: /etc/postfix/main.cf, line 739: overriding earlier entry: myhostname=mail.urban.com
postconf: warning: /etc/postfix/main.cf, line 740: overriding earlier entry: mydomain=urban.com
myhostname = mail.lab.local
```

Postfix was using wrong hostname despite being configured correctly.

**Root Cause:**
main.cf had `myhostname` and `mydomain` defined twice.
The second definition (lower in the file) overrides the first.
Postfix uses the last value it finds.

**Fix:**
```bash
grep -n "myhostname" /etc/postfix/main.cf
grep -n "mydomain" /etc/postfix/main.cf
```
Found duplicate entries at lines 739-740. Deleted the duplicates,
kept only the correct first definitions.

**Lesson:**
main.cf is read top to bottom. Last value wins on duplicates.
Always grep for a directive before adding it — it may already exist.

---

## Postfix — Mail Not Routing to Server 2

**Problem:**
Mail sent to user@rural.com was not being delivered to Server 2.

**Root Cause:**
`relayhost = 192.168.1.20` was set in main.cf on Server 1.

relayhost forces ALL outgoing mail to one destination regardless of
the recipient domain. This bypasses DNS MX lookup entirely.
So mail to rural.com went to Server 2 (lucky) but mail to urban.com
also went to Server 2 (wrong — urban.com should deliver locally).

**Fix:**
Commented out relayhost:
```
#relayhost = 192.168.1.20
```

Postfix now uses DNS MX lookup automatically:
- urban.com in mydestination → deliver locally
- rural.com not in mydestination → look up MX → connect to Server 2

**Lesson:**
relayhost is for forwarding ALL mail through a smarthost (like Gmail SMTP).
Never use relayhost when you want DNS-based routing between your own servers.
Let DNS MX records do the routing — that's exactly what they're for.

---

## Postfix — Server 1 Can't Resolve Local Mail Domains

**Problem:**
Postfix on Server 1 couldn't route mail to rural.com even after
removing relayhost. MX lookup was failing silently.

**Root Cause:**
Server 1's /etc/resolv.conf pointed to Google DNS (8.8.8.8).
Google DNS has no knowledge of our local rural.com zone.
So MX lookup for rural.com returned NXDOMAIN and mail failed.

**Fix:**
Changed Server 1 to use itself as primary DNS:
```bash
nmcli con mod "connection-name" ipv4.dns "127.0.0.1 8.8.8.8"
nmcli con up "connection-name"
```

Now:
- rural.com MX lookup → asks 127.0.0.1 → BIND finds local zone → returns correct IP
- google.com lookup → asks 127.0.0.1 → not found locally → forwards to 8.8.8.8

**Lesson:**
A mail server must be able to resolve all domains it needs to deliver to.
If your mail server uses an external DNS that doesn't know your local domains,
inter-server mail delivery will silently fail.
Always point the mail server's DNS to a resolver that knows your local zones.

---

## XFS Quota — No Output from xfs_quota State

**Problem:**
After adding `uquota` to fstab and running `mount -o remount /home`,
`xfs_quota -x -c 'state' /home` returned no output.

**Root Cause:**
LVM-backed XFS partitions don't always pick up new mount options
via remount. The old options (noquota) were still active:
```
mount | grep home
/dev/mapper/rl-home on /home type xfs (...,noquota)
```

**Fix:**
Full reboot — fstab options apply cleanly on fresh mount:
```bash
sudo reboot
```
After reboot:
```
mount | grep home
/dev/mapper/rl-home on /home type xfs (...,usrquota)  ✓
```

**Lesson:**
XFS quota requires `uquota` in fstab + a reboot to activate.
`mount -o remount` is not reliable for LVM partitions.
Always verify with `mount | grep home` — look for `usrquota` not `noquota`.

---

## SSH — Backup Script Failing at 2 AM

**Problem:**
Backup cron job failed silently overnight. rsync was not connecting to Server 2.

**Root Cause:**
SSH key was generated as the regular user, stored in /home/user/.ssh/id_rsa.
But cron runs the backup script as root.
Root looked for its key in /root/.ssh/id_rsa — file not found.
SSH fell back to password auth — nobody there to type password — connection failed.

**Fix:**
Switched to root first, then generated key:
```bash
sudo -i
ssh-keygen         # saves to /root/.ssh/id_rsa
ssh-copy-id root@192.168.1.20
```

**Lesson:**
The user who RUNS the script must own the SSH key.
Whoever you log in as ≠ whoever runs the script.
cron runs jobs as the user whose crontab file it is.
Always generate and test SSH keys as root for root cron jobs.

---

## Apache — Virtual Host Not Serving Correct Site

**Problem:**
All virtual hosts were returning the default Apache page
instead of their own content.

**Root Cause:**
SELinux was blocking Apache from reading files in custom document roots.
Apache could technically access the files (Unix permissions were correct)
but SELinux context was wrong — files had default_t instead of httpd_sys_content_t.

**Fix:**
```bash
semanage fcontext -a -t httpd_sys_content_t "/var/www/sitename(/.*)?"
restorecon -Rv /var/www/sitename
```

**Lesson:**
SELinux context is a silent blocker — no obvious error in Apache logs.
Always check SELinux when a service has correct permissions but still fails.
`semanage fcontext` + `restorecon` is the permanent fix.
`chcon` is temporary and resets on relabel.

---

## General Debugging Approach Used Throughout

For every service issue, these six questions were asked in order:

```
1. Is the process running?         systemctl status servicename
2. What port is it listening on?   ss -tlnp | grep port
3. What do the logs say?           journalctl -u servicename -n 30
4. Is the firewall blocking it?    firewall-cmd --list-all
5. Is SELinux blocking it?         ausearch -m avc -ts recent
6. Is the config valid?            named-checkconf / sshd -t / apachectl configtest
```

Asking these six questions in order resolved every issue in this project.
