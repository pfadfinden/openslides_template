# BdP OpenSlides 4 deployer

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fpfadfinden%2Fopenslides_template%2Fmain%2Fazuredeploy.json)

One-click deployment of a new [OpenSlides 4](https://openslides.com) instance on a dedicated Azure VM. The VM is fully configured by cloud-init — no manual installation needed.

## What you get

- Azure VM `Standard_B2ms` (2 vCPU / 8 GB RAM), Debian 12 (Gen2, 64 GB SSD), Trusted Launch with Secure Boot + vTPM
- Public IP (Standard, static), virtual network `10.0.0.0/16` with subnet `10.0.0.0/24`
- Network security group allowing inbound **22** (SSH), **80** and **443** (OpenSlides / auto-HTTPS)
- cloud-init installs Docker + the [OpenSlides manage tool](https://github.com/OpenSlides/openslides-manage-service), generates `docker-compose.yml`, starts the full OpenSlides 4 stack and creates the initial database

## Prerequisites

- An **Azure subscription** (a free trial works)
- A **domain/subdomain you control** — you need to create a DNS A record pointing to the VM's public IP (required for the automatic Let's Encrypt HTTPS certificate)
- **SMTP credentials** for outgoing e-mail (invites, password resets) — optional but recommended

## Deploy

1. Click the **Deploy to Azure** button above and sign in to the Azure portal.
2. **Basics**: choose your subscription, create a new resource group (e.g. `openslides-rg`) and pick a region (default: `germanywestcentral`).
3. **Settings**: only the **admin password** for the VM is required. Everything else is pre-filled (`Standard_B2ms`, Debian 12, user `os4user`, ports 22/80/443, cloud-init from this repo).
4. **Review + create** and wait ~5–10 minutes. The VM's **public IP** is shown in the deployment outputs.

### Parameters

| Parameter | Default | Description |
| --- | --- | --- |
| `location` | `germanywestcentral` | Azure region |
| `virtualMachineSize` | `Standard_B2ms` | VM size (2 vCPU / 8 GB) |
| `osDiskSizeGB` | `64` | OS disk size in GB |
| `adminUsername` | `os4user` | SSH user on the VM |
| `adminPassword` | *(required)* | SSH password — choose a strong one |
| `customData` | base64 of `cloud-init.yml` | VM bootstrap config (do not edit unless you know what you are doing) |

## After the deployment

The cloud-init runs once with placeholder values (`subdomain.pfadfinden.de`, empty SMTP password). Finalize the instance like this:

1. **DNS**: create an A record for your subdomain (e.g. `openslides.example.org`) pointing to the VM's public IP. Wait for it to propagate.
2. **SSH into the VM**: `ssh os4user@<public-ip>` (password from the deployment form).
3. **Edit the config**: `nano /home/os4user/my-config.yml`
   - replace every `subdomain.pfadfinden.de` with your subdomain (`EXTERNAL_ADDRESS` and `SYSTEM_URL`)
   - fill in your SMTP settings (`EMAIL_HOST`, `EMAIL_HOST_USER`, `EMAIL_HOST_PASSWORD`, `DEFAULT_FROM_EMAIL`, ...)
4. **Re-generate and restart the stack**:

   ```sh
   cd /home/os4user
   ./openslides setup --config my-config.yml /home/os4user
   sed -i '/      - 0.0.0.0:443:8000/i\      - 0.0.0.0:80:8001' docker-compose.yml
   docker compose pull
   docker compose up -d
   ```

5. **Create the initial data**: `./openslides initial-data -a <your-subdomain>:443`
6. Open `https://<your-subdomain>` and log in with **admin / admin** — change the password immediately (user menu → change password).

## Repository layout

| File | Purpose |
| --- | --- |
| `os4machine.bicep` | Source of the Azure infrastructure (VM, network, NSG, IP) |
| `azuredeploy.json` | Compiled ARM template — **this is what the button deploys** (the portal cannot deploy remote `.bicep` files) |
| `cloud-init.yml` | VM bootstrap; embedded base64-encoded as `customData` at build time |

After changing `os4machine.bicep` or `cloud-init.yml`, regenerate and commit the template:

```sh
bicep build os4machine.bicep --stdout > azuredeploy.json
```

## Costs and cleanup

The VM alone costs roughly **60–70 € per month** (on-demand, `germanywestcentral`), plus a few euros for disk and public IP. To stop all costs, delete the entire resource group in the Azure portal — everything created by this template lives in it.

## License

[MIT](LICENSE) © Bund der Pfadfinderinnen & Pfadfinder e.V.
