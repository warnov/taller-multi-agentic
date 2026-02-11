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
| **4.4** | Crear el agente Anders con **Azure AI Agents Persistent SDK** y una **OpenAPI Tool** que invoca la API |

### Prerrequisitos

- Haber completado el **setup de infraestructura** descrito en el [README de Foundry](README.md)
- Haber asignado el rol **Azure AI Developer** sobre el recurso de AI Services (ver sección "Permisos RBAC" en el [README](README.md#permisos-rbac-para-azure-ai-foundry))
- Tener anotada la **URL de la Function App** y el **nombre de la Function App** (`func-contosoretail-{suffix}`) de la salida del despliegue
- **.NET 8 SDK** instalado ([descargar](https://dotnet.microsoft.com/download/dotnet/8.0))

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

## 4.4 — Crear el agente Anders (Azure AI Agents Persistent + OpenAPI Tool)

En este paso vamos a crear el agente Anders usando el **SDK de Azure AI Agents Persistent** con una **OpenAPI Tool** que permite al agente invocar directamente los endpoints de la Function App de Contoso Retail.

| Concepto | Descripción |
|----------|-------------|
| **Azure AI Agents Persistent** | SDK para crear agentes persistentes en Azure AI Foundry, gestionar threads de conversación y ejecutar runs |
| **OpenAPI Tool** | Herramienta que recibe una especificación OpenAPI y permite al agente descubrir e invocar automáticamente los endpoints descritos en ella |
| **Azure AI Foundry** | Plataforma cloud donde el agente se registra y ejecuta. El proyecto de Foundry proporciona acceso al modelo GPT-4.1 |

El flujo será:

1. **Descargar la especificación OpenAPI** de la Function App en tiempo de ejecución
2. Definir una **OpenAPI Tool** a partir de la especificación descargada
3. **Crear el agente** en Foundry con `agentsClient.Administration.CreateAgentAsync()` pasándole la tool
4. **Interactuar** con el agente usando threads y runs con polling

> **¿Cómo funciona?** Cuando el usuario pide un reporte, el modelo GPT-4.1 analiza las herramientas disponibles y decide invocar el endpoint `ordersReporter` descrito en la especificación OpenAPI. El servicio de Foundry ejecuta la llamada HTTP a la Function App automáticamente y envía el resultado de vuelta al modelo para que formule su respuesta al usuario.

### Paso 1: Crear el proyecto de consola

Desde la raíz del repositorio:

```powershell
mkdir labs\foundry\code\agents
cd labs\foundry\code\agents
dotnet new console -n AndersAgent --framework net8.0
cd AndersAgent
```

### Paso 2: Agregar los paquetes NuGet

```powershell
dotnet add package Azure.AI.Agents.Persistent --prerelease
dotnet add package Azure.AI.Projects --prerelease
dotnet add package Azure.Identity
dotnet add package Microsoft.Extensions.Configuration.Json
```

- **`Azure.AI.Agents.Persistent`** — SDK de agentes persistentes de Azure AI (incluye `OpenApiToolDefinition`, `PersistentAgentsClient`, threads y runs)
- **`Azure.AI.Projects`** — Foundry SDK (necesario para `AIProjectClient`)
- **`Azure.Identity`** — Autenticación con `DefaultAzureCredential` (reutiliza tu `az login`)
- **`Microsoft.Extensions.Configuration.Json`** — Para cargar `appsettings.json`

> **Nota:** Ambos SDKs de Azure AI están en prerelease. El flag `--prerelease` es necesario.

### Paso 3: Agregar el proyecto a la solución

Desde la raíz del repositorio:

```powershell
cd ..\..\..\..\..
dotnet sln taller-multi-agentic.sln add labs\foundry\code\agents\AndersAgent\AndersAgent.csproj
```

### Paso 4: Crear el archivo de configuración

Crea un archivo `appsettings.json` en la carpeta `AndersAgent`:

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

Configura el archivo para que se copie al directorio de salida. Abre `AndersAgent.csproj` y agrega un **nuevo `<ItemGroup>`** después del que ya existe (el de los paquetes NuGet), pero antes de `</Project>`:

```xml
<ItemGroup>
  <None Update="appsettings.json">
    <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
  </None>
</ItemGroup>
```

> **No lo agregues dentro del `<ItemGroup>` existente** que contiene los `<PackageReference>`. Debe ser un bloque `<ItemGroup>` separado.

### Paso 5: Implementar `Program.cs`

Reemplaza el contenido de `Program.cs` con lo siguiente:

```csharp
using Azure.AI.Projects;
using Azure.AI.Agents.Persistent;
using Azure.Identity;
using Microsoft.Extensions.Configuration;

#pragma warning disable CA2252 // API en preview

// --- Cargar configuración ---
var config = new ConfigurationBuilder()
    .AddJsonFile("appsettings.json")
    .Build();

var foundryEndpoint = config["FoundryProjectEndpoint"]
    ?? throw new InvalidOperationException("Falta FoundryProjectEndpoint en appsettings.json");
var modelDeployment = config["ModelDeploymentName"]
    ?? throw new InvalidOperationException("Falta ModelDeploymentName en appsettings.json");
var functionAppBaseUrl = config["FunctionAppBaseUrl"]
    ?? throw new InvalidOperationException("Falta FunctionAppBaseUrl en appsettings.json");

// =====================================================================
//  FASE 1: Obtener la especificación OpenAPI de la Function App
// =====================================================================

Console.WriteLine("[OpenAPI] Descargando especificación desde la Function App...");

var httpClient = new HttpClient();
var openApiSpecUrl = $"{functionAppBaseUrl}/openapi/v3.json";
var openApiSpec = await httpClient.GetStringAsync(openApiSpecUrl);

Console.WriteLine($"[OpenAPI] Especificación descargada ({openApiSpec.Length} bytes)");

// =====================================================================
//  FASE 2: Crear agente con herramienta OpenAPI en Foundry
// =====================================================================

// Cliente del proyecto Foundry
var projectClient = new AIProjectClient(
    new Uri(foundryEndpoint),
    new DefaultAzureCredential());

// Obtener el cliente de agentes persistentes
var agentsClient = projectClient.GetPersistentAgentsClient();

// Definir la herramienta OpenAPI a partir de la especificación descargada
var openApiTool = new OpenApiToolDefinition(
    new OpenApiFunctionDefinition(
        name: "ContosoRetailAPI",
        spec: BinaryData.FromString(openApiSpec),
        openApiAuthentication: new OpenApiAnonymousAuthDetails())
    {
        Description = "API de Contoso Retail para generar reportes de órdenes de compra"
    });

// Instrucciones del agente Anders
var andersInstructions = """
    Eres Anders, el agente ejecutor de Contoso Retail.

    Tu responsabilidad es ejecutar acciones operativas concretas cuando se te soliciten.
    Tu principal capacidad es generar reportes de órdenes de compra de clientes
    usando la API de Contoso Retail disponible como herramienta OpenAPI.

    Cuando recibas datos de órdenes, debes construir el JSON del request body
    con EXACTAMENTE este schema para invocar el endpoint ordersReporter:

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

    Reglas:
    - TODOS los campos son obligatorios para cada línea de orden.
    - Si una orden tiene múltiples productos, cada producto es un elemento
      separado en el array "orders" con el mismo "orderNumber" y "orderDate"
      pero diferente "orderLineNumber" (secuencial: 1, 2, 3...).
    - Las fechas deben estar en formato ISO: YYYY-MM-DD.
    - "quantity", "unitPrice" y "lineTotal" son numéricos (double).

    Siempre confirma la acción realizada al usuario, incluyendo la URL del reporte.
    Si los datos son insuficientes o inválidos, explica qué falta.
    Responde en español.
    """;

Console.WriteLine("[Foundry] Buscando agente Anders existente...");

PersistentAgent? agent = null;

// Buscar si ya existe un agente con el mismo nombre
await foreach (var existingAgent in agentsClient.Administration.GetAgentsAsync())
{
    if (existingAgent.Name == "Anders - Agente Ejecutor")
    {
        agent = existingAgent;
        Console.WriteLine($"[Foundry] Agente existente encontrado: {agent.Name} (ID: {agent.Id})");
        break;
    }
}

if (agent is null)
{
    Console.WriteLine("[Foundry] Creando agente Anders con herramienta OpenAPI...");

    agent = (await agentsClient.Administration.CreateAgentAsync(
        model: modelDeployment,
        name: "Anders - Agente Ejecutor",
        description: "Agente ejecutor de Contoso Retail con herramienta OpenAPI",
        instructions: andersInstructions,
        tools: new List<ToolDefinition> { openApiTool })).Value;

    Console.WriteLine($"[Foundry] Agente creado: {agent.Name} (ID: {agent.Id})");
}

// =====================================================================
//  FASE 3: Interactuar con el agente (threads & runs)
// =====================================================================

PersistentAgentThread thread = (await agentsClient.Threads.CreateThreadAsync()).Value;
Console.WriteLine($"[Foundry] Thread creado: {thread.Id}");
Console.WriteLine();
Console.WriteLine("=== Chat con Anders (escribe 'salir' para terminar) ===");
Console.WriteLine();

while (true)
{
    Console.Write("Tú: ");
    var input = Console.ReadLine();

    if (string.IsNullOrWhiteSpace(input) ||
        input.Equals("salir", StringComparison.OrdinalIgnoreCase))
        break;

    // Enviar mensaje del usuario al thread
    await agentsClient.Messages.CreateMessageAsync(
        threadId: thread.Id,
        role: MessageRole.User,
        content: input);

    // Ejecutar el agente sobre el thread
    ThreadRun run = (await agentsClient.Runs.CreateRunAsync(thread, agent)).Value;

    // Esperar a que el run termine (polling)
    Console.Write("Anders: ");
    while (run.Status == RunStatus.Queued || run.Status == RunStatus.InProgress)
    {
        await Task.Delay(TimeSpan.FromSeconds(1));
        run = (await agentsClient.Runs.GetRunAsync(thread.Id, run.Id)).Value;
    }

    // Procesar resultado
    if (run.Status == RunStatus.Completed)
    {
        // Obtener mensajes del thread (los más recientes primero)
        var messages = agentsClient.Messages.GetMessagesAsync(threadId: thread.Id);

        await foreach (PersistentThreadMessage message in messages)
        {
            // Solo mostrar la primera respuesta del agente (la más reciente)
            if (message.Role == MessageRole.Agent)
            {
                foreach (MessageContent contentItem in message.ContentItems)
                {
                    if (contentItem is MessageTextContent textContent)
                    {
                        Console.WriteLine(textContent.Text);
                    }
                }
                break;
            }
        }
    }
    else
    {
        Console.WriteLine($"\n[Error] Run terminó con estado: {run.Status}");
        if (run.LastError != null)
            Console.WriteLine($"[Error] {run.LastError.Code}: {run.LastError.Message}");
    }
    Console.WriteLine();
}

// =====================================================================
//  Limpieza del thread (el agente persiste para reutilizarse)
// =====================================================================

Console.WriteLine("[Foundry] Limpiando thread...");
await agentsClient.Threads.DeleteThreadAsync(thread.Id);
Console.WriteLine($"[Foundry] Thread eliminado. El agente '{agent.Name}' (ID: {agent.Id}) permanece disponible.");
```

> **Observa las 3 fases claramente separadas:**
>
> | Fase | Qué hace |
> |------|----------|
> | **1 — Descargar OpenAPI** | Descarga la especificación OpenAPI de la Function App en tiempo de ejecución y la usa para definir una `OpenApiToolDefinition` |
> | **2 — Buscar o crear agente** | Busca un agente existente con `GetAgentsAsync()`. Si no existe, lo crea con `CreateAgentAsync()` en Foundry con el modelo, instrucciones y la herramienta OpenAPI |
> | **3 — Chat con polling** | Crea un `PersistentAgentThread`, envía mensajes con `CreateMessageAsync()`, ejecuta runs con `CreateRunAsync()` y espera resultados con polling |

### Paso 6: Compilar y verificar

```powershell
cd labs\foundry\code\agents\AndersAgent
dotnet build
```

Asegúrate de que no haya errores de compilación antes de continuar.

### Paso 7: Ejecutar al agente Anders

```powershell
dotnet run
```

Verás el prompt interactivo. Pruébalo primero con un saludo:

```
Tú: Hola Anders, ¿qué puedes hacer?
```

Anders debería responder explicando que puede generar reportes de órdenes. Luego, prueba con datos reales:

```
Tú: Genera un reporte para Izabella Celma (periodo: 1-31 enero 2026). Orden ORD-CID-069-001 (2026-01-04): Sport-100 Helmet Black, Contoso Outdoor, Helmets, 6x$34.99=$209.94 | HL Road Frame Red 62, Contoso Outdoor, Road Frames, 10x$1431.50=$14315.00 | Long-Sleeve Logo Jersey S, Contoso Outdoor, Jerseys, 8x$49.99=$399.92. Orden ORD-CID-069-003 (2026-01-08): HL Road Frame Black 58, Contoso Outdoor, Road Frames, 3x$1431.50=$4294.50 | HL Road Frame Red 44, Contoso Outdoor, Road Frames, 7x$1431.50=$10020.50. Orden ORD-CID-069-002 (2026-01-17): HL Road Frame Red 62, Contoso Outdoor, Road Frames, 2x$1431.50=$2863.00 | LL Road Frame Black 60, Contoso Outdoor, Road Frames, 4x$337.22=$1348.88.
```

> **Formato del prompt:** Cada orden se separa con un punto (`.`). Dentro de cada orden, las líneas se separan con pipe (`|`). Cada línea tiene: producto, marca, categoría, cantidad x precio unitario = total.

Lo que ocurre internamente:
1. Anders analiza el mensaje y decide que necesita llamar al endpoint `ordersReporter` de la API OpenAPI
2. **Foundry ejecuta la llamada HTTP** automáticamente a la Function App con los datos del cliente y las órdenes
3. La Function App genera el reporte HTML, lo sube a Blob Storage, y retorna la URL
4. Foundry envía el resultado de vuelta al modelo
5. Anders formula su respuesta y presenta la URL al usuario

Verás en la consola los mensajes `[OpenAPI]` y `[Foundry]` indicando el progreso.

Puedes abrir la URL del reporte en el navegador para verificar que se generó correctamente.

Ahora prueba con un caso más sencillo — un solo pedido con dos productos:

```
Tú: Genera un reporte para Marco Rivera (periodo: 5-10 febrero 2026). Orden ORD-CID-112-001 (2026-02-07): Mountain Bike Socks M, Contoso Outdoor, Socks, 3x$9.50=$28.50 | Water Bottle 30oz, Contoso Outdoor, Bottles and Cages, 1x$6.99=$6.99.
```

> **Nota:** Al escribir `salir`, solo se elimina el thread de conversación. El agente **persiste** en Foundry y se reutiliza automáticamente en la siguiente ejecución.

---

## Siguiente paso

Continúa con el [Lab 5 — Julie (Planner Agent)](lab05-julie-planner-agent.md).
