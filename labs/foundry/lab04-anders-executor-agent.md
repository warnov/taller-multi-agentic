# Lab 04: Anders — Executor Agent

## Introducción

Anders es el **agente ejecutor** de la arquitectura multi-agéntica de Contoso Retail. Su rol es recibir solicitudes de acciones operativas — como la generación y publicación de reportes de órdenes — y ejecutarlas interactuando con servicios externos como la Azure Function `FxContosoRetail`.

Para que Anders pueda interactuar con la API de Contoso Retail, definiremos una **OpenAPI Tool** que permite al agente descubrir e invocar automáticamente los endpoints de la Function App a partir de su especificación OpenAPI. Adicionalmente, agregaremos soporte **OpenAPI** a la Function App para documentar la API y facilitar la exploración de sus endpoints.

### ¿Qué vamos a hacer en este lab?

| Paso | Descripción |
|------|-------------|
| **4.1** | Agregar soporte OpenAPI a la Azure Function `FxContosoRetail` |
| **4.2** | Redesplegar la Function App con los cambios |
| **4.3** | Verificar la especificación OpenAPI |
| **4.4** | Entender, configurar, ejecutar y probar el agente Anders |

### Prerrequisitos

#### Herramientas en tu máquina

| Herramienta | Descripción | Descarga |
|-------------|-------------|----------|
| **.NET 8 SDK** | Compilar y ejecutar la Function App y el agente Anders | [Descargar](https://dotnet.microsoft.com/download/dotnet/8.0) |
| **Azure CLI** | Autenticarse en Azure, desplegar recursos y asignar roles RBAC | [Instalar](https://learn.microsoft.com/cli/azure/install-azure-cli) |
| **Azure Functions Core Tools** | Publicar la Function App a Azure (opción recomendada) | [Instalar](https://learn.microsoft.com/azure/azure-functions/functions-run-local#install-the-azure-functions-core-tools) |
| **PowerShell** | Ejecutar scripts de despliegue | Windows: incluido · macOS/Linux: [Instalar PowerShell 7+](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) |
| **Git** | Clonar el repositorio del taller | [Descargar](https://git-scm.com/downloads) |

> [!TIP]
> En **macOS**, puedes instalar las herramientas con Homebrew:
> ```bash
> brew install dotnet-sdk azure-cli azure-functions-core-tools@4 powershell git
> ```

#### Infraestructura Azure

- Haber completado el **setup de infraestructura** descrito en el [README de Foundry](README.md)
- Tener anotados **todos los valores generados en el despliegue** de la infraestructura (nombres de recursos, URLs, sufijo, endpoint de AI Foundry, etc.)

#### Permisos RBAC

Tu usuario necesita el rol **Cognitive Services User** sobre el recurso de AI Services para poder crear y ejecutar agentes. Como tu usuario es **Owner del tenant**, puedes asignarte el rol tú mismo.

Ejecuta los siguientes comandos (reemplaza `{suffix}` con tu sufijo de 5 caracteres):

```powershell
# 1. Obtener tu nombre de usuario (UPN)
$upn = az account show --query "user.name" -o tsv

# 2. Obtener el nombre del recurso de AI Services (si no lo recuerdas)
az cognitiveservices account list --resource-group rg-contoso-retail --query "[].name" -o tsv

# 3. Asignar el rol Cognitive Services User
az role assignment create `
    --assignee $upn `
    --role "Cognitive Services User" `
    --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/rg-contoso-retail/providers/Microsoft.CognitiveServices/accounts/ais-contosoretail-{suffix}"
```

> **Nota:** La propagación de RBAC puede tardar hasta 1 minuto. Espera antes de continuar con el lab.

---

## 4.1 — Agregar soporte OpenAPI a la Function App

La Azure Function `FxContosoRetail` actualmente expone dos endpoints HTTP (`HolaMundo` y `OrdersReporter`), pero no genera una especificación OpenAPI. Sin esta especificación, Azure AI Foundry no puede descubrir automáticamente los endpoints ni sus contratos de datos para usarlos como tools de un agente.

Vamos a agregar el paquete **`Microsoft.Azure.Functions.Worker.Extensions.OpenApi`** y decorar los endpoints con atributos OpenAPI.

### Paso 1: Agregar el paquete NuGet

Abre una terminal en la carpeta del proyecto de la Function App y agrega el paquete:

```powershell
cd labs\foundry\code\api\FxContosoRetail
dotnet add package Microsoft.Azure.Functions.Worker.Extensions.OpenApi
```

Esto agregará la referencia en `FxContosoRetail.csproj`. Puedes verificar que aparece en el archivo:

```xml
<PackageReference Include="Microsoft.Azure.Functions.Worker.Extensions.OpenApi" Version="..." />
```

### Paso 2: Agregar los `using` necesarios

Abre el archivo `FxContosoRetail.cs` y agrega las siguientes directivas `using` al inicio del archivo, junto a las existentes:

```csharp
using Microsoft.Azure.Functions.Worker.Extensions.OpenApi.Extensions;
using Microsoft.Azure.WebJobs.Extensions.OpenApi.Core.Attributes;
using Microsoft.Azure.WebJobs.Extensions.OpenApi.Core.Enums;
using Microsoft.OpenApi.Models;
using System.Net;
```

### Paso 3: Decorar el endpoint `OrdersReporter`

Agrega los atributos OpenAPI justo encima del atributo `[Function("OrdersReporter")]`:

```csharp
[OpenApiOperation(operationId: "ordersReporter", tags: new[] { "Reportes" },
    Summary = "Genera un reporte HTML de órdenes",
    Description = "Recibe líneas de órdenes de un cliente, genera un reporte HTML con el detalle, lo sube a Blob Storage y retorna la URL con SAS para descargarlo.")]
[OpenApiRequestBody(
    contentType: "application/json",
    bodyType: typeof(OrdersReportRequest),
    Required = true,
    Description = "Datos del cliente y líneas de órdenes a incluir en el reporte")]
[OpenApiResponseWithBody(
    statusCode: HttpStatusCode.OK,
    contentType: "application/json",
    bodyType: typeof(object),
    Description = "Objeto JSON con la propiedad 'reportUrl' que contiene la URL SAS del reporte generado")]
[OpenApiResponseWithBody(
    statusCode: HttpStatusCode.BadRequest,
    contentType: "text/plain",
    bodyType: typeof(string),
    Description = "Mensaje de error cuando el JSON es inválido o no contiene órdenes")]
[Function("OrdersReporter")]
public async Task<IActionResult> OrdersReporter(
    [HttpTrigger(AuthorizationLevel.Anonymous, "post")] HttpRequest req)
{
    // ... código existente sin cambios ...
}
```

### Paso 4: Verificar compilación

Comprueba que el proyecto compila sin errores:

```powershell
dotnet build
```

> **Nota:** El paquete OpenAPI registra automáticamente endpoints adicionales en la Function App. No necesitas modificar `Program.cs`.

> [!IMPORTANT]
> **Sobre la autenticación de los endpoints**
>
> En este taller usamos `AuthorizationLevel.Anonymous` para simplificar la configuración y permitir que Azure AI Foundry pueda invocar la Function App directamente como OpenAPI Tool sin necesidad de gestionar secrets ni configurar autenticación adicional.
>
> **En un entorno de producción, esto no es recomendable.** La práctica correcta es proteger la Function App con **Azure Entra ID (Easy Auth)** y hacer que Foundry se autentique usando **Managed Identity**. El flujo sería:
>
> 1. **Registrar una aplicación en Entra ID** que represente la Function App, obteniendo un Application (client) ID y un Application ID URI (por ejemplo, `api://<client-id>`).
> 2. **Habilitar Easy Auth** en la Function App con `az webapp auth update`, configurándola para validar tokens emitidos por Entra ID contra la app registration. Esto protege todos los endpoints a nivel de plataforma — las peticiones sin un bearer token válido se rechazan con 401 antes de llegar al código.
> 3. **Asignar permisos a la Managed Identity** del recurso de AI Services (`ais-contosoretail-{suffix}`) como principal autorizado en la app registration, ya sea agregándola como miembro de un app role o como identidad permitida en la configuración de Easy Auth.
> 4. **Usar `OpenApiManagedAuthDetails`** en el código del agente en lugar de `OpenApiAnonymousAuthDetails`, especificando el audience de la app registration:
>    ```csharp
>    openApiAuthentication: new OpenApiManagedAuthDetails(
>        audience: "api://<app-registration-client-id>")
>    ```
>
> Con esta configuración, cuando Foundry necesita llamar a la Function App, obtiene un token de Entra ID usando la managed identity del recurso de AI Services, lo envía como `Authorization: Bearer <token>`, y Easy Auth lo valida automáticamente. Los endpoints de la Function pueden mantener `AuthorizationLevel.Anonymous` en el código C# porque la autenticación ocurre en la capa de plataforma.

### Endpoints OpenAPI generados

Una vez desplegada, la Function App expondrá estos endpoints adicionales:

| Endpoint | Descripción |
|----------|-------------|
| `/api/openapi/v3.json` | Especificación OpenAPI 3.0 en formato JSON |
| `/api/swagger/ui` | Interfaz Swagger UI interactiva |

---

## 4.2 — Redesplegar la Function App

La infraestructura ya está desplegada desde el setup inicial. Solo necesitas **publicar el código actualizado** de la Function App.

### Opción A: Usando Azure Functions Core Tools (recomendada)

Si tienes instalado [Azure Functions Core Tools](https://learn.microsoft.com/azure/azure-functions/functions-run-local#install-the-azure-functions-core-tools), el redespliegue es un solo comando:

```powershell
cd labs\foundry\code\api\FxContosoRetail
func azure functionapp publish func-contosoretail-<suffix>
```

> Reemplaza `<suffix>` con el sufijo de 5 caracteres que obtuviste durante el setup (por ejemplo, `func-contosoretail-a1b2c`).

### Opción B: Usando Azure CLI

Si no tienes `func` CLI, puedes publicar manualmente con `az`:

```powershell
# 1. Compilar el proyecto
cd labs\foundry\code\api\FxContosoRetail
dotnet publish --configuration Release --output bin\publish

# 2. Crear el paquete zip
Compress-Archive -Path "bin\publish\*" -DestinationPath "$env:TEMP\fxcontosoretail.zip" -Force

# 3. Desplegar a Azure
az functionapp deployment source config-zip `
    --resource-group rg-contoso-retail `
    --name func-contosoretail-<suffix> `
    --src "$env:TEMP\fxcontosoretail.zip"

# 4. Limpiar archivos temporales
Remove-Item "$env:TEMP\fxcontosoretail.zip" -Force
Remove-Item "bin\publish" -Recurse -Force
```

---

## 4.3 — Verificar la especificación OpenAPI

Una vez desplegada, verifica que los endpoints OpenAPI están disponibles.

### Obtener la especificación JSON

Abre en el navegador o con `curl`:

```
https://func-contosoretail-<suffix>.azurewebsites.net/api/openapi/v3.json
```

Deberías ver un JSON con la estructura OpenAPI que describe los endpoints `HolaMundo` y `OrdersReporter`, incluyendo los esquemas de request/response.

### Explorar el Swagger UI

Navega a:

```
https://func-contosoretail-<suffix>.azurewebsites.net/api/swagger/ui
```

Desde la interfaz de Swagger UI puedes explorar los endpoints y probarlos interactivamente.

> **Importante:** La especificación OpenAPI documenta la API y sirve como referencia para entender qué parámetros enviar y qué respuesta esperar. El agente Anders usará esta información indirectamente a través de la Function Tool que definiremos en el siguiente paso.

---

## 4.4 — El agente Anders (Azure AI Agents Persistent + OpenAPI Tool)

El código del agente Anders ya está incluido en el repositorio, en la carpeta `labs/foundry/code/agents/AndersAgent`. En esta sección vamos a entender cómo funciona, configurarlo con los datos de tu entorno, ejecutarlo y probarlo.

| Concepto | Descripción |
|----------|-------------|
| **Azure AI Agents Persistent** | SDK para crear agentes persistentes en Azure AI Foundry, gestionar threads de conversación y ejecutar runs |
| **OpenAPI Tool** | Herramienta que recibe una especificación OpenAPI y permite al agente descubrir e invocar automáticamente los endpoints descritos en ella |
| **Azure AI Foundry** | Plataforma cloud donde el agente se registra y ejecuta. El proyecto de Foundry proporciona acceso al modelo GPT-4.1 |

### Entendiendo el código

Abre el archivo `labs/foundry/code/agents/AndersAgent/Program.cs` y observa que está organizado en **3 fases claramente separadas**:

#### Fase 1 — Descargar la especificación OpenAPI

```csharp
var openApiSpecUrl = $"{functionAppBaseUrl}/openapi/v3.json";
var openApiSpec = await httpClient.GetStringAsync(openApiSpecUrl);
```

El programa descarga la especificación OpenAPI de la Function App **en tiempo de ejecución**. Esto significa que si la API cambia (nuevos endpoints, nuevos parámetros), el agente lo detecta automáticamente al reiniciarse.

#### Fase 2 — Buscar o crear el agente en Foundry

Esta fase tiene dos partes importantes:

**Definición de la herramienta OpenAPI:**

```csharp
var openApiTool = new OpenApiToolDefinition(
    new OpenApiFunctionDefinition(
        name: "ContosoRetailAPI",
        spec: BinaryData.FromString(openApiSpec),
        openApiAuthentication: new OpenApiAnonymousAuthDetails())
    {
        Description = "API de Contoso Retail para generar reportes de órdenes de compra"
    });
```

Aquí se crea una `OpenApiToolDefinition` que envuelve la especificación descargada. Con `OpenApiAnonymousAuthDetails`, Foundry invocará la API sin enviar credenciales (la Function App usa `AuthorizationLevel.Anonymous`).

**Instrucciones del agente (system prompt):**

El system prompt incluye el schema JSON exacto que Anders debe construir al invocar la API:

```json
{
  "customerName": "Nombre del Cliente",
  "startDate": "YYYY-MM-DD",
  "endDate": "YYYY-MM-DD",
  "orders": [
    {
      "orderNumber": "código de la orden",
      "orderDate": "YYYY-MM-DD",
      "orderLineNumber": 1,
      "productName": "nombre del producto",
      "brandName": "nombre de la marca",
      "categoryName": "nombre de la categoría",
      "quantity": 1.0,
      "unitPrice": 0.00,
      "lineTotal": 0.00
    }
  ]
}
```

> [!TIP]
> Incluir el schema en las instrucciones es una buena práctica cuando el agente debe construir payloads complejos. Aunque la especificación OpenAPI ya describe el schema, reforzarlo en el system prompt reduce significativamente los errores de formato.

**Reutilización del agente:**

```csharp
await foreach (var existingAgent in agentsClient.Administration.GetAgentsAsync())
{
    if (existingAgent.Name == "Anders - Agente Ejecutor")
    {
        agent = existingAgent;
        break;
    }
}
```

Antes de crear un agente nuevo, el programa busca si ya existe uno con el mismo nombre. Esto permite reiniciar la aplicación sin duplicar agentes en Foundry.

#### Fase 3 — Chat interactivo con polling

```csharp
ThreadRun run = (await agentsClient.Runs.CreateRunAsync(thread, agent)).Value;

while (run.Status == RunStatus.Queued || run.Status == RunStatus.InProgress)
{
    await Task.Delay(TimeSpan.FromSeconds(1));
    run = (await agentsClient.Runs.GetRunAsync(thread.Id, run.Id)).Value;
}
```

El patrón de interacción sigue este ciclo:
1. Se crea un `PersistentAgentThread` (la conversación)
2. El mensaje del usuario se agrega con `CreateMessageAsync()`
3. Se crea un `ThreadRun` que ejecuta el agente, asociándolo al thread
4. Se hace **polling** cada segundo hasta que el run termina
5. Se leen los mensajes de respuesta del agente

> **¿Qué pasa durante el run?** Cuando el modelo decide que necesita llamar a la API, Foundry ejecuta la llamada HTTP automáticamente usando la especificación OpenAPI. El resultado se envía de vuelta al modelo, que formula la respuesta final al usuario. Todo esto ocurre dentro del run — el código solo espera el resultado.

**Limpieza al salir:**

Al escribir `salir`, solo se elimina el thread de conversación. El agente **persiste** en Foundry y se reutiliza automáticamente en la siguiente ejecución.

### Paso 1: Configurar `appsettings.json`

Abre el archivo `labs/foundry/code/agents/AndersAgent/appsettings.json` y reemplaza los valores con los de tu entorno:

```json
{
  "FoundryProjectEndpoint": "<TU-AI-FOUNDRY-PROJECT-ENDPOINT>",
  "ModelDeploymentName": "gpt-4.1",
  "FunctionAppBaseUrl": "https://func-contosoretail-<suffix>.azurewebsites.net/api"
}
```

> **¿Dónde encuentro estos valores?**
> - **FoundryProjectEndpoint**: El `AI Foundry Endpoint` de la salida del despliegue.
> - **ModelDeploymentName**: `gpt-4.1` (nombre del deployment creado por el Bicep).
> - **FunctionAppBaseUrl**: La URL de tu Function App + `/api`.

### Paso 2: Compilar y ejecutar

```powershell
cd labs\foundry\code\agents\AndersAgent
dotnet build
```

Asegúrate de que no haya errores de compilación. Luego ejecuta:

```powershell
dotnet run
```

Verás en consola que el agente se crea en Foundry (o se reutiliza si ya existía).

### Paso 3: Inspeccionar el agente en Azure AI Foundry

**Antes de interactuar con Anders**, ve al portal para inspeccionar lo que se creó:

1. Abre [Azure AI Foundry](https://ai.azure.com) y navega a tu proyecto
2. En el menú lateral, selecciona **Agents**
3. Busca el agente **"Anders - Agente Ejecutor"** y haz clic en él

Observa dos cosas clave:

- **System prompt (instrucciones):** Verás las instrucciones completas que le dimos al agente, incluyendo el schema JSON. Esto es lo que guía su comportamiento al decidir cuándo y cómo invocar la API.
- **Tools (herramientas):** Verás **ContosoRetailAPI** listada como herramienta OpenAPI. Puedes expandirla para ver la especificación completa con el endpoint `ordersReporter`, los schemas de request/response, y la configuración de autenticación anónima.

> [!TIP]
> El system prompt y las tools son los dos pilares que determinan qué puede hacer un agente y cómo lo hace. Entender esta relación es clave para diseñar agentes efectivos.

### Paso 4: Probar el agente

De vuelta en la consola, pruébalo primero con un saludo:

```
Tú: Hola Anders, ¿qué puedes hacer?
```

Anders debería responder explicando que puede generar reportes de órdenes. Luego, prueba con datos reales (pega todo en una sola línea):

```
Tú: Genera un reporte para Izabella Celma (periodo: 1-31 enero 2026). Orden ORD-CID-069-001 (2026-01-04): Sport-100 Helmet Black, Contoso Outdoor, Helmets, 6x$34.99=$209.94 | HL Road Frame Red 62, Contoso Outdoor, Road Frames, 10x$1431.50=$14315.00 | Long-Sleeve Logo Jersey S, Contoso Outdoor, Jerseys, 8x$49.99=$399.92. Orden ORD-CID-069-003 (2026-01-08): HL Road Frame Black 58, Contoso Outdoor, Road Frames, 3x$1431.50=$4294.50 | HL Road Frame Red 44, Contoso Outdoor, Road Frames, 7x$1431.50=$10020.50. Orden ORD-CID-069-002 (2026-01-17): HL Road Frame Red 62, Contoso Outdoor, Road Frames, 2x$1431.50=$2863.00 | LL Road Frame Black 60, Contoso Outdoor, Road Frames, 4x$337.22=$1348.88.
```

Lo que ocurre internamente:
1. Anders analiza el mensaje y decide que necesita llamar al endpoint `ordersReporter`
2. **Foundry ejecuta la llamada HTTP** automáticamente a la Function App con los datos estructurados según el schema
3. La Function App genera el reporte HTML, lo sube a Blob Storage y retorna la URL
4. Foundry envía el resultado de vuelta al modelo
5. Anders formula su respuesta y presenta la URL al usuario

Abre la URL del reporte en el navegador para verificar que se generó correctamente.

Ahora prueba con un caso más sencillo — un solo pedido con dos productos:

```
Tú: Genera un reporte para Marco Rivera (periodo: 5-10 febrero 2026). Orden ORD-CID-112-001 (2026-02-07): Mountain Bike Socks M, Contoso Outdoor, Socks, 3x$9.50=$28.50 | Water Bottle 30oz, Contoso Outdoor, Bottles and Cages, 1x$6.99=$6.99.
```

> **Nota:** Al escribir `salir`, solo se elimina el thread de conversación. El agente **persiste** en Foundry y se reutiliza automáticamente en la siguiente ejecución.

---

## Siguiente paso

Continúa con el [Lab 5 — Julie (Planner Agent)](lab05-julie-planner-agent.md).
