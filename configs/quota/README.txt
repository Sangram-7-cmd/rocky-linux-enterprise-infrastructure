Disk quota is configured on /home partition (XFS filesystem).

How it was enabled:
1. Added uquota to /etc/fstab (see fstab file)
2. Rebooted to apply mount options
3. Set limits per user using xfs_quota

Limits set:
- Soft limit: 800MB (warning threshold, 7 day grace period)
- Hard limit: 1GB  (absolute block, cannot write beyond this)

Commands used:
# Set limits
xfs_quota -x -c 'limit bsoft=800m bhard=1g USERNAME' /home

# View all limits
xfs_quota -x -c 'report -h' /home

# Check quota state
xfs_quota -x -c 'state' /home
