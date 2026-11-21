# BdP OpenSlides-4-Deployer

Ein-Klick-Deployment einer neuen [OpenSlides-4](https://openslides.com)-Instanz auf einer dedizierten Azure-VM. Die VM wird vollständig per cloud-init konfiguriert — keine manuelle Installation nötig.

Es gibt zwei Varianten — wähle die passende für deine Azure-Rechte:

**Variante 1: Neue Ressourcengruppe wird automatisch angelegt.** Du brauchst **Contributor auf der Subscription**. Den Namen der Ressourcengruppe gibst du im Formular im Feld `resourceGroupName` an (Default: `openslides-rg`).

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fpfadfinden%2Fopenslides_template%2Fmain%2Fazuredeploy.json)

**Variante 2: Deployment in eine bestehende Ressourcengruppe.** Du brauchst nur **Contributor auf dieser einen RG** — die RG muss bereits existieren (z. B. von einem Admin angelegt) und wird im Portal-Formular aus dem Dropdown ausgewählt.

[![Deploy into existing resource group](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fpfadfinden%2Fopenslides_template%2Fmain%2Fazuredeploy.rg.json)

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

1. Klicke oben auf den Button der passenden Variante (siehe Erklärungen direkt über den Buttons) und melde dich im Azure-Portal an.
2. **Basics**: Subscription und Region wählen (Default: `germanywestcentral`). Bei **Variante 1** wird die Ressourcengruppe automatisch neu angelegt — Name im Feld `resourceGroupName` (Default: `openslides-rg`). Bei **Variante 2** wählst du eine **existierende** Ressourcengruppe aus dem Dropdown.
3. **Einstellungen**: Pflicht sind das **Admin-Passwort** der VM und **`openslidesSubdomain`** (z. B. `openslides.example.org`). Optional trägst du direkt deine **SMTP-Daten** ein (`smtpHost`, `smtpUser`, `smtpPassword`) — dann verschickt OpenSlides E-Mails (Einladungen, Passwort-Reset) sofort. Alles andere ist bereits vorausgefüllt (`Standard_B2ms`, Debian 12, Benutzer `os4user`, Ports 22/80/443).
4. **Überprüfen + erstellen** und ca. 5–10 Minuten warten. Die **öffentliche IP** der VM steht in den Deployment-Outputs.

### Parameter

| Parameter | Default | Beschreibung |
| --- | --- | --- |
| `resourceGroupName` | `openslides-rg` | Name der Ressourcengruppe — wird neu angelegt, falls sie noch nicht existiert |
| `openslidesSubdomain` | *(Pflicht)* | Deine Subdomain, z. B. `openslides.example.org` — wird in die cloud-init eingetragen (`EXTERNAL_ADDRESS`, `SYSTEM_URL`) |
| `smtpHost` | `''` | SMTP-Server für ausgehende E-Mails |
| `smtpUser` | `''` | SMTP-Benutzername (auch als `DEFAULT_FROM_EMAIL`) |
| `smtpPassword` | `''` | SMTP-Passwort (secureString) |
| `alertEmail` | `''` | E-Mail für Monitoring-Alerts (leer = aus). Alert: CPU dauerhaft > 80 % (B2ms drosselt bei aufgebrauchten Credits) |
| `location` | `germanywestcentral` | Azure-Region |
| `virtualMachineSize` | `Standard_B2ms` | VM-Größe (2 vCPU / 8 GB) |
| `osDiskSizeGB` | `64` | Größe der OS-Disk in GB |
| `adminUsername` | `os4user` | SSH-Benutzer auf der VM |
| `adminPassword` | *(Pflicht)* | SSH-Passwort — bitte ein starkes wählen |

## Nach dem Deployment

Die cloud-init konfiguriert die VM bereits vollständig mit den Werten aus dem Formular — es ist **nichts mehr per SSH nachträglich zu editieren**. Es bleibt nur:

1. **DNS**: Lege einen A-Record für deine Subdomain (z. B. `openslides.example.org`) an, der auf die öffentliche IP der VM zeigt. Am besten *vor* dem Deployment, damit das Let's-Encrypt-Zertifikat (Auto-HTTPS) direkt ausgestellt werden kann.
2. Rufe `https://<deine-subdomain>` auf und melde dich mit **admin / admin** an — ändere das Passwort sofort (Benutzermenü → Passwort ändern).
