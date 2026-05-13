# TODO

- [ ] **Fail2ban in profile::base** — `profile::fail2ban` exists but is not included in base. Should be baseline for all nodes since SSH is exposed on every server.
- [ ] **Log rotation audit** — Verify nginx logs (especially custom vhost logs like vpn proxy) are properly rotated. Check if the nginx module handles this or if custom logrotate configs are needed.
- [ ] **DNS resolver pinning** — Manage `/etc/resolv.conf` explicitly instead of relying on DHCP defaults. Ensure consistent, reliable DNS across all nodes.
