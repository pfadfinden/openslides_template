// Modul: alle Ressourcen innerhalb der Ressourcengruppe (Scope = resourceGroup).
// Wird von os4machine.bicep (targetScope = subscription) mit scope: resourceGroup aufgerufen.

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

@description('SSH-Passwort für den VM-Benutzer — bitte ein starkes Passwort wählen')
@secure()
param adminPassword string

@description('Deine Subdomain, z. B. openslides.example.org — wird in EXTERNAL_ADDRESS und SYSTEM_URL eingetragen')
param openslidesSubdomain string
@description('SMTP-Server für ausgehende E-Mails (Einladungen, Passwort-Reset), z. B. smtp.example.org')
param smtpHost string = ''
@description('SMTP-Benutzername, wird auch als DEFAULT_FROM_EMAIL verwendet')
param smtpUser string = ''
@description('SMTP-Passwort')
@secure()
param smtpPassword string = ''
@description('E-Mail-Adresse für Monitoring-Alerts (leer = keine Alerts). Meldet dauerhaft hohe CPU-Last — die B2ms-VM ist burstable und drosselt, sobald die CPU-Credits aufgebraucht sind.')
param alertEmail string = ''
@description('Sicherheitstyp der VM — TrustedLaunch aktiviert Secure Boot + vTPM (empfohlen)')
param securityType string = 'TrustedLaunch'
@description('Secure Boot aktivieren (nur mit TrustedLaunch)')
param secureBoot bool = true
@description('virtuelles TPM (vTPM) aktivieren (nur mit TrustedLaunch)')
param vTPM bool = true

var nsgId = resourceId(resourceGroup().name, 'Microsoft.Network/networkSecurityGroups', networkSecurityGroupName)
var vnetId = resourceId(resourceGroup().name, 'Microsoft.Network/virtualNetworks', virtualNetworkName)
var subnetRef = '${vnetId}/subnets/${subnetName}'

var cloudInitYaml = loadTextContent('cloud-init.yml')
var smtpPasswordPlaceholder = concat('EMAIL_HOST_PASSWORD: ', '''', '''')
var smtpPasswordLine = 'EMAIL_HOST_PASSWORD: "${smtpPassword}"'
var cloudInitRendered = replace(replace(replace(replace(cloudInitYaml, 'subdomain.pfadfinden.de', openslidesSubdomain), 'smtpHostHier.pfadfinden.de', smtpHost), 'mailAddyHier@pfadfinden.de', smtpUser), smtpPasswordPlaceholder, smtpPasswordLine)

resource networkInterface 'Microsoft.Network/networkInterfaces@2021-08-01' = {
  name: networkInterfaceName
  location: resourceGroup().location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetRef
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: resourceId(resourceGroup().name, 'Microsoft.Network/publicIpAddresses', publicIpAddressName)
            properties: {
              deleteOption: pipDeleteOption
            }
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: nsgId
    }
  }
  dependsOn: [
    networkSecurityGroup
    virtualNetwork
    publicIpAddress
  ]
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2019-02-01' = {
  name: networkSecurityGroupName
  location: resourceGroup().location
  properties: {
    securityRules: networkSecurityGroupRules
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-07-01' = {
  name: virtualNetworkName
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
    subnets: subnets
  }
}

resource publicIpAddress 'Microsoft.Network/publicIpAddresses@2020-08-01' = {
  name: publicIpAddressName
  location: resourceGroup().location
  properties: {
    publicIPAllocationMethod: publicIpAddressType
  }
  sku: {
    name: publicIpAddressSku
  }
}

resource virtualMachine 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: virtualMachineName
  location: resourceGroup().location
  properties: {
    hardwareProfile: {
      vmSize: virtualMachineSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'fromImage'
        diskSizeGB: osDiskSizeGB
        managedDisk: {
          storageAccountType: osDiskType
        }
        deleteOption: osDiskDeleteOption
      }
      imageReference: {
        publisher: 'debian'
        offer: 'debian-12'
        sku: '12-gen2'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
          properties: {
            deleteOption: nicDeleteOption
          }
        }
      ]
    }
    osProfile: {
      computerName: virtualMachineComputerName
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        patchSettings: {
          patchMode: 'ImageDefault'
        }
      }
      customData: base64(cloudInitRendered)
    }
    securityProfile: {
      securityType: securityType
      uefiSettings: {
        secureBootEnabled: secureBoot
        vTpmEnabled: vTPM
      }
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

resource alertActionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = if (alertEmail != '') {
  name: '${virtualMachineName}-alerts'
  location: 'global'
  properties: {
    groupShortName: 'os4alerts'
    enabled: true
    emailReceivers: [
      {
        name: 'admin'
        emailAddress: alertEmail
        useCommonAlertSchema: true
      }
    ]
  }
}

resource highCpuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = if (alertEmail != '') {
  name: '${virtualMachineName}-high-cpu'
  location: 'global'
  properties: {
    description: 'Dauerhaft hohe CPU-Last: Die B2ms-VM ist burstable und drosselt, sobald die CPU-Credits aufgebraucht sind.'
    severity: 2
    enabled: true
    scopes: [
      virtualMachine.id
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          name: 'HighAverageCpu'
          metricName: 'Percentage CPU'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
          dimensions: []
        }
      ]
    }
    actions: [
      {
        actionGroupId: alertActionGroup.id
      }
    ]
  }
}

output adminUsername string = adminUsername
output publicIpAddress string = publicIpAddress.properties.ipAddress
