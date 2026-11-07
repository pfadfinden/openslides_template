# BdP OpenSlides4 deployer

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fpfadfinden%2Fopenslides_template%2Fmain%2Fazuredeploy.json)

Deploys a `Standard_B2ms` VM (Debian 11) and configures it via `cloud-init.yml` (passed as base64 `customData`).

`azuredeploy.json` is generated from `os4machine.bicep`. After changing the bicep file or `cloud-init.yml`, regenerate and commit it:

```sh
bicep build os4machine.bicep --stdout > azuredeploy.json
```