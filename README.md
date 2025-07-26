# Proxmox LXC Support

This repository provides a basic `docker-compose.yml` that runs a Matrix Synapse container with a companion ClamAV service.

The Synapse container is configured so that all uploaded files are scanned by the ClamAV service. The key environment variables are set in `docker-compose.yml`:

```yaml
      - SYNAPSE_ANTIVIRUS_ENABLED=true
      - SYNAPSE_ANTIVIRUS_HOST=clamav
```

With the ClamAV service running, uploads to Synapse will be checked for malware before they are stored.

## Verifying scanning

To confirm that scanning is working you can test the ClamAV setup with the [EICAR](https://www.eicar.org/?page_id=3950) test file:

```bash
curl -L -o eicar.com.txt https://secure.eicar.org/eicar.com.txt
clamscan eicar.com.txt
```

A successful scan will report the file as infected:

```
/workspace/proxmox-lcx-support/eicar.com.txt: Win.Test.EICAR_HDB-1 FOUND
```

## Usage

Start the services with Docker Compose:

```bash
docker-compose up -d
```

Synapse will now reject uploads that contain malware detected by ClamAV.

