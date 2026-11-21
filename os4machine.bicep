targetScope = 'subscription'

@description('Azure-Region, in der alles angelegt wird (z. B. germanywestcentral)')
param location string = 'germanywestcentral'
@description('Name der Ressourcengruppe — wird neu angelegt, falls sie noch nicht existiert (z. B. openslides-rg)')
param resourceGroupName string = 'openslides-rg'
@description('Name der Netzwerkkarte (NIC) der VM — nur ändern, wenn nötig')
param networkInterfaceName string = 'openslides4-nic'
@description('Name der Netzwerksicherheitsgruppe (NSG) — nur ändern, wenn nötig')
param networkSecurityGroupName string = 'openslides4-nsg'
@description('Eingangsregeln der Firewall: offen sind 22 (SSH), 80 und 443 (OpenSlides/HTTPS)')
param networkSecurityGroupRules array = [
  {
    name: 'allow-ssh'
    properties: {
      priority: 1000
      direction: 'Inbound'
      access: 'Allow'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '22'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: '*'
    }
  }
  {
    name: 'allow-http'
    properties: {
      priority: 1010
      direction: 'Inbound'
      access: 'Allow'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '80'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: '*'
    }
  }
  {
    name: 'allow-https'
    properties: {
      priority: 1020
      direction: 'Inbound'
      access: 'Allow'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '443'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: '*'
    }
  }
]
@description('Name des Subnetzes im VNet')
param subnetName string = 'default'
@description('Name des virtuellen Netzwerks (VNet)')
param virtualNetworkName string = 'openslides4-vnet'
@description('Adressbereich des VNet, z. B. 10.0.0.0/16')
param addressPrefixes array = [
  '10.0.0.0/16'
]
@description('Subnetze des VNet (Name + Adressbereich)')
param subnets array = [
  {
    name: subnetName
    properties: {
      addressPrefix: '10.0.0.0/24'
    }
  }
]
@description('Name der öffentlichen IP-Adresse der VM')
param publicIpAddressName string = 'openslides4-ip'
@description('Allokationsmethode der öffentlichen IP — Static empfohlen, damit die IP stabil bleibt')
param publicIpAddressType string = 'Static'
@description('SKU der öffentlichen IP — Standard ist Pflicht zusammen mit der NSG')
param publicIpAddressSku string = 'Standard'
@description('Was mit der öffentlichen IP passiert, wenn die VM gelöscht wird')
param pipDeleteOption string = 'Delete'
@description('Name der VM in Azure')
param virtualMachineName string = 'openslides4'
@description('Hostname innerhalb der VM')
param virtualMachineComputerName string = 'openslides4'
@description('Speichertyp der OS-Disk — StandardSSD_LRS ist günstig und für OpenSlides ausreichend')
param osDiskType string = 'StandardSSD_LRS'
@description('Größe der OS-Disk in GB — 64 GB empfohlen (Docker-Images + Datenbank)')
param osDiskSizeGB int = 64
@description('Was mit der OS-Disk passiert, wenn die VM gelöscht wird')
param osDiskDeleteOption string = 'Delete'
@description('VM-Größe — Standard_B2ms (2 vCPU / 8 GB, burstable: drosselt bei Dauerlast)')
param virtualMachineSize string = 'Standard_B2ms'
@description('Was mit der Netzwerkkarte passiert, wenn die VM gelöscht wird')
param nicDeleteOption string = 'Delete'
@description('SSH-Benutzername auf der VM')
param adminUsername string = 'os4user'

@secure()
@description('SSH-Passwort für den VM-Benutzer — bitte ein starkes Passwort wählen')
param adminPassword string

@description('Deine Subdomain, z. B. openslides.example.org — wird in EXTERNAL_ADDRESS und SYSTEM_URL eingetragen')
param openslidesSubdomain string
@description('SMTP-Server für ausgehende E-Mails (Einladungen, Passwort-Reset), z. B. smtp.example.org')
param smtpHost string = ''
@description('SMTP-Benutzername, wird auch als DEFAULT_FROM_EMAIL verwendet')
param smtpUser string = ''
@secure()
@description('SMTP-Passwort')
param smtpPassword string = ''
@description('E-Mail-Adresse für Monitoring-Alerts (leer = keine Alerts). Meldet dauerhaft hohe CPU-Last — die B2ms-VM ist burstable und drosselt, sobald die CPU-Credits aufgebraucht sind.')
param alertEmail string = ''
@description('Sicherheitstyp der VM — TrustedLaunch aktiviert Secure Boot + vTPM (empfohlen)')
param securityType string = 'TrustedLaunch'
@description('Secure Boot aktivieren (nur mit TrustedLaunch)')
param secureBoot bool = true
@description('virtuelles TPM (vTPM) aktivieren (nur mit TrustedLaunch)')
param vTPM bool = true

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
}

module vm 'vm.bicep' = {
  name: 'openslides4-deployment'
  scope: resourceGroup
  params: {
    networkInterfaceName: networkInterfaceName
    networkSecurityGroupName: networkSecurityGroupName
    networkSecurityGroupRules: networkSecurityGroupRules
    subnetName: subnetName
    virtualNetworkName: virtualNetworkName
    addressPrefixes: addressPrefixes
    subnets: subnets
    publicIpAddressName: publicIpAddressName
    publicIpAddressType: publicIpAddressType
    publicIpAddressSku: publicIpAddressSku
    pipDeleteOption: pipDeleteOption
    virtualMachineName: virtualMachineName
    virtualMachineComputerName: virtualMachineComputerName
    osDiskType: osDiskType
    osDiskSizeGB: osDiskSizeGB
    osDiskDeleteOption: osDiskDeleteOption
    virtualMachineSize: virtualMachineSize
    nicDeleteOption: nicDeleteOption
    adminUsername: adminUsername
    adminPassword: adminPassword
    openslidesSubdomain: openslidesSubdomain
    smtpHost: smtpHost
    smtpUser: smtpUser
    smtpPassword: smtpPassword
    alertEmail: alertEmail
    securityType: securityType
    secureBoot: secureBoot
    vTPM: vTPM
  }
}

output resourceGroupName string = resourceGroupName
output adminUsername string = vm.outputs.adminUsername
output publicIpAddress string = vm.outputs.publicIpAddress
