param suffix string

var aiFoundryName = 'ais-contosoretail-${suffix}'
var bingGroundingName = 'bingsearch-${suffix}'
var bingConnectionName = '${aiFoundryName}-bingsearchconnection'

resource aiFoundry 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: aiFoundryName
}

resource bingGrounding 'Microsoft.Bing/accounts@2020-06-10' existing = {
  name: bingGroundingName
}

#disable-next-line BCP081
resource bingConnection 'Microsoft.CognitiveServices/accounts/connections@2025-04-01-preview' = {
  parent: aiFoundry
  name: bingConnectionName
  properties: {
    category: 'ApiKey'
    target: 'https://api.bing.microsoft.com/'
    authType: 'ApiKey'
    credentials: {
      key: bingGrounding.listKeys().key1
    }
    isSharedToAll: true
    metadata: {
      ApiType: 'Azure'
      Location: bingGrounding.location
      ResourceId: bingGrounding.id
    }
  }
}

output bingConnectionName string = bingConnection.name
