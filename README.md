# Proxmox LXC Support

This repository provides configuration snippets and helper scripts to maintain LXC containers within a Proxmox VE environment.

## Component Relationships

```mermaid
graph TD
    client["User / Client"]
    proxmox["Proxmox VE Node"]
    lxc["LXC Container"]
    app["Applications"]
    support["Support Scripts"]

    client --> proxmox
    proxmox --> lxc
    lxc --> app
    lxc --> support
```

## References

- [Proxmox VE Documentation](https://pve.proxmox.com/pve-docs/)
- [LXC Documentation](https://linuxcontainers.org/lxc/docs/)
