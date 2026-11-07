# BdP OpenSlides-4-Deployer

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fpfadfinden%2Fopenslides_template%2Fmain%2Fazuredeploy.json)

Ein-Klick-Deployment einer neuen [OpenSlides-4](https://openslides.com)-Instanz auf einer dedizierten Azure-VM. Die VM wird vollständig per cloud-init konfiguriert — keine manuelle Installation nötig.

## Was du bekommst

- Azure-VM `Standard_B2ms` (2 vCPU / 8 GB RAM), Debian 12 (Gen2, 64 GB SSD), Trusted Launch mit Secure Boot + vTPM
- Öffentliche IP (Standard, statisch), virtuelles Netzwerk `10.0.0.0/16` mit Subnetz `10.0.0.0/24`
- Netzwerksicherheitsgruppe mit eingehenden Ports **22** (SSH), **80** und **443** (OpenSlides / Auto-HTTPS)
- cloud-init installiert Docker und das [OpenSlides-Manage-Tool](https://github.com/OpenSlides/openslides-manage-service), erzeugt die `docker-compose.yml`, startet den kompletten OpenSlides-4-Stack und legt die initiale Datenbank an

## Voraussetzungen

- Ein **Azure-Subscription** (ein kostenloses Testabo reicht)
- Eine **Domain/Subdomain, die du kontrollierst** — du musst einen DNS-A-Record auf die öffentliche IP der VM setzen (Pflicht für das automatische Let's-Encrypt-HTTPS-Zertifikat)
- **SMTP-Zugangsdaten** für ausgehende E-Mails (Einladungen, Passwort-Reset) — optional, aber empfohlen

## Deployment

1. Klicke oben auf **Deploy to Azure** und melde dich im Azure-Portal an.
2. **Basics**: Subscription wählen, neue Ressourcengruppe anlegen (z. B. `openslides-rg`) und Region wählen (Default: `germanywestcentral`).
3. **Einstellungen**: Nur das **Admin-Passwort** der VM ist Pflicht. Alles andere ist bereits vorausgefüllt (`Standard_B2ms`, Debian 12, Benutzer `os4user`, Ports 22/80/443, cloud-init aus diesem Repo).
4. **Überprüfen + erstellen** und ca. 5–10 Minuten warten. Die **öffentliche IP** der VM steht in den Deployment-Outputs.

### Parameter

| Parameter | Default | Beschreibung |
| --- | --- | --- |
| `location` | `germanywestcentral` | Azure-Region |
| `virtualMachineSize` | `Standard_B2ms` | VM-Größe (2 vCPU / 8 GB) |
| `osDiskSizeGB` | `64` | Größe der OS-Disk in GB |
| `adminUsername` | `os4user` | SSH-Benutzer auf der VM |
| `adminPassword` | *(Pflicht)* | SSH-Passwort — bitte ein starkes wählen |
| `customData` | Base64 von `cloud-init.yml` | Bootstrap-Konfiguration der VM (nur anfassen, wer weiß, was er tut) |

## Nach dem Deployment

Das cloud-init läuft einmal mit Platzhalter-Werten durch (`subdomain.pfadfinden.de`, leeres SMTP-Passwort). So finalisierst du die Instanz:

1. **DNS**: Lege einen A-Record für deine Subdomain (z. B. `openslides.example.org`) an, der auf die öffentliche IP der VM zeigt. Warte, bis er propagiert ist.
2. **Per SSH auf die VM verbinden**: `ssh os4user@<öffentliche-ip>` (Passwort aus dem Deployment-Formular).
3. **Konfiguration anpassen**: `nano /home/os4user/my-config.yml`
   - ersetze jedes `subdomain.pfadfinden.de` durch deine Subdomain (`EXTERNAL_ADDRESS` und `SYSTEM_URL`)
   - trage deine SMTP-Daten ein (`EMAIL_HOST`, `EMAIL_HOST_USER`, `EMAIL_HOST_PASSWORD`, `DEFAULT_FROM_EMAIL`, ...)
4. **Stack neu generieren und starten**:

   ```sh
   cd /home/os4user
   ./openslides setup --config my-config.yml /home/os4user
   sed -i '/      - 0.0.0.0:443:8000/i\      - 0.0.0.0:80:8001' docker-compose.yml
   docker compose pull
   docker compose up -d
   ```

5. **Initiale Daten anlegen**: `./openslides initial-data -a <deine-subdomain>:443`
6. Rufe `https://<deine-subdomain>` auf und melde dich mit **admin / admin** an — ändere das Passwort sofort (Benutzermenü → Passwort ändern).
