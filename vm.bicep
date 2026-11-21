// Modul: alle Ressourcen innerhalb der Ressourcengruppe (Scope = resourceGroup).
// Wird von os4machine.bicep (targetScope = subscription) mit scope: resourceGroup aufgerufen.

param networkInterfaceName string = 'openslides4-nic'
param networkSecurityGroupName string = 'openslides4-nsg'
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
param subnetName string = 'default'
param virtualNetworkName string = 'openslides4-vnet'
param addressPrefixes array = [
  '10.0.0.0/16'
]
param subnets array = [
  {
    name: subnetName
    properties: {
      addressPrefix: '10.0.0.0/24'
    }
  }
]
param publicIpAddressName string = 'openslides4-ip'
param publicIpAddressType string = 'Static'
param publicIpAddressSku string = 'Standard'
param pipDeleteOption string = 'Delete'
param virtualMachineName string = 'openslides4'
param virtualMachineComputerName string = 'openslides4'
param osDiskType string = 'StandardSSD_LRS'
param osDiskSizeGB int = 64
param osDiskDeleteOption string = 'Delete'
param virtualMachineSize string = 'Standard_B2ms'
param nicDeleteOption string = 'Delete'
param adminUsername string = 'os4user'

@secure()
param adminPassword string

param openslidesSubdomain string
param smtpHost string = ''
param smtpUser string = ''
@secure()
param smtpPassword string = ''
param alertEmail string = ''
param securityType string = 'TrustedLaunch'
param secureBoot bool = true
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
