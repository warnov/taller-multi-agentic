// ============================================================================
// Contoso Retail - Infraestructura Azure
// Taller Multi-Agéntico
// ============================================================================
// Cada attendee despliega en su propia suscripción.
// El sufijo único (5 chars) se genera a partir del nombre del tenant temporal.
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// Parámetros
// ============================================================================

@description('Nombre del tenant temporal asignado al attendee (ej: "contoso-abc123tenant").')
param tenantName string

@description('Ubicación de los recursos. Por defecto: eastus.')
param location string = 'eastus'

@description('Nombre del modelo GPT a desplegar en AI Services.')
param gptModelName string = 'gpt-4.1'

@description('Versión del modelo GPT.')
param gptModelVersion string = '2025-04-14'

@description('Capacidad del deployment (tokens por minuto en miles).')
param gptDeploymentCapacity int = 30

// ============================================================================
// Variables - Sufijo y nombres
// ============================================================================

var suffix = substring(uniqueString(tenantName), 0, 5)

var storageAccountName = 'stcontosoretail${suffix}'
var appServicePlanName = 'asp-contosoretail-${suffix}'
var functionAppName = 'func-contosoretail-${suffix}'
var aiFoundryName = 'ais-contosoretail-${suffix}'
var aiProjectName = 'aip-contosoretail-${suffix}'

var tags = {
  project: 'taller-multi-agentic'
  environment: 'workshop'
}

// ============================================================================
// 1. Storage Account (AVM)
// ============================================================================

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true // requerido por Function App para el content file share
  }
}

// File share pre-creado para que la Function App no lo intente crear ella misma
// (evita 403 por timing: el data plane del Storage aún no está listo cuando ARM
// reporta el Storage Account como "Succeeded")
resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
}

resource contentShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01' = {
  parent: fileService
  name: toLower(functionAppName)
}

// ============================================================================
// 2. App Service Plan (Consumption Y1 - nativo)
// ============================================================================

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  kind: 'functionapp'
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {
    reserved: false
  }
}

// ============================================================================
// 3. Function App (nativo - evita sub-deployments del AVM)
// ============================================================================

var storageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: location
  tags: tags
  kind: 'functionapp'
  dependsOn: [contentShare] // esperar a que el file share exista antes de crear la Function App
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      netFrameworkVersion: 'v8.0'
      use32BitWorkerProcess: false
      ftpsState: 'Disabled'
      appSettings: [
        { name: 'AzureWebJobsStorage', value: storageConnectionString }
        { name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING', value: storageConnectionString }
        { name: 'WEBSITE_CONTENTSHARE', value: toLower(functionAppName) }
        { name: 'WEBSITE_SKIP_CONTENTSHARE_VALIDATION', value: '1' }
        { name: 'FUNCTIONS_EXTENSION_VERSION', value: '~4' }
        { name: 'FUNCTIONS_WORKER_RUNTIME', value: 'dotnet-isolated' }
        { name: 'bill-template', value: 'https://raw.githubusercontent.com/nicobytes/taller-multi-agentic/main/assets/bill-template.html' }
      ]
    }
  }
}

// ============================================================================
// 3b. Role Assignments - Function App → Storage Account
// ============================================================================
// La Function App usa Managed Identity para acceder al Storage desde código.
// Se requieren 3 roles:
//   - Storage Blob Data Owner       → triggers, bindings, blob storage
//   - Storage Queue Data Contributor → queue triggers
//   - Storage Account Contributor   → file share

module functionStorageRbac 'storage-rbac.bicep' = {
  name: 'functionStorageRbacDeployment'
  params: {
    storageAccountName: storageAccount.name
    principalId: functionApp.identity.principalId
  }
}

// ============================================================================
// 7. AI Foundry Resource (CognitiveServices/accounts con allowProjectManagement)
// ============================================================================
// Este recurso unifica AI Services + Foundry Hub en un solo recurso.
// Reemplaza el antiguo patrón Hub (MachineLearningServices/workspaces kind:Hub).
// Ref: https://learn.microsoft.com/azure/ai-foundry/how-to/create-resource-template

resource aiFoundry 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: aiFoundryName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'S0'
  }
  kind: 'AIServices'
  properties: {
    allowProjectManagement: true
    customSubDomainName: aiFoundryName
    disableLocalAuth: false
    publicNetworkAccess: 'Enabled'
  }
}

// ============================================================================
// 8. AI Foundry Project (hijo directo del Foundry Resource)
// ============================================================================

resource aiProject 'Microsoft.CognitiveServices/accounts/projects@2025-06-01' = {
  name: aiProjectName
  parent: aiFoundry
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {}
}

// ============================================================================
// 9. Model Deployment (GPT sobre el Foundry Resource)
// ============================================================================

resource gptDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = {
  parent: aiFoundry
  name: gptModelName
  sku: {
    name: 'Standard'
    capacity: gptDeploymentCapacity
  }
  properties: {
    model: {
      name: gptModelName
      format: 'OpenAI'
      version: gptModelVersion
    }
  }
}

// ============================================================================
// Outputs
// ============================================================================

output suffix string = suffix
output storageAccountName string = storageAccountName
output functionAppName string = functionAppName
output functionAppUrl string = 'https://${functionAppName}.azurewebsites.net'
output aiFoundryName string = aiFoundryName
output aiFoundryEndpoint string = aiFoundry.properties.endpoint
output aiProjectName string = aiProjectName
