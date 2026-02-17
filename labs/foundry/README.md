# Azure AI Foundry — Taller Multi-Agéntico

## Introducción

Esta sección del taller cubre la **capa de razonamiento y ejecución** de la arquitectura multi-agéntica de Contoso Retail, implementada sobre **Azure AI Foundry**. Aquí se construyen los agentes inteligentes que interpretan datos y planifican acciones (ejecutando algunas),a partir de la información generada por la capa de datos (Microsoft Fabric).

### Agentes de esta capa

| Agente | Rol | Descripción |
|--------|-----|-------------|
| **Anders** | Executor Agent | Recibe solicitudes de acciones operativas (como la generación de reportes o renderizado de facturas) y las ejecuta interactuando con servicios externos como la Azure Function `FxContosoRetail`. Tipo: `kind: "prompt"` con herramienta OpenAPI. |
| **Julie** | Planner Agent (Workflow) | Orquesta campañas de marketing personalizadas. Recibe una descripción de segmento de clientes y ejecuta un flujo de 5 pasos: (1) extrae el filtro de clientes, (2) invoca a **SqlAgent** para generar T-SQL, (3) ejecuta la consulta contra Fabric vía **Function App OpenAPI**, (4) invoca a **MarketingAgent** (con Bing Search) para generar mensajes por cliente, (5) organiza el resultado como JSON de campaña de correos. Tipo: `kind: "workflow"` con 3 herramientas (2 agentes + 1 OpenAPI). |

### Arquitectura general

La capa Foundry se ubica en el centro de la arquitectura de tres capas:

```
┌─────────────────────┐
│   Copilot Studio    │  ← Capa de interacción (Charles, Bill, Ric)
├─────────────────────┤
│  Azure AI Foundry   │  ← Capa de razonamiento (Anders, Julie) ★
├─────────────────────┤
│  Microsoft Fabric   │  ← Capa de datos (Mark, Amy)
└─────────────────────┘
```

Los agentes Anders y Julie utilizan modelos GPT-4.1 desplegados en Azure AI Services para razonar sobre la información del negocio. Anders consume directamente la API de `FxContosoRetail` vía herramienta OpenAPI. Julie orquesta un workflow multi-agente: usa **SqlAgent** (genera T-SQL), una **Function App** (ejecuta el SQL contra Fabric vía OpenAPI) y **MarketingAgent** (genera mensajes personalizados con Bing Search), coordinando todo de forma autónoma como un agente de tipo `workflow`.

---

## Laboratorios

| Lab | Archivo | Descripción |
|-----|---------|-------------|
| Lab 4 | [Anders — Executor Agent](lab04-anders-executor-agent.md) | Crear el agente ejecutor que genera reportes e interactúa con servicios de Contoso Retail. |
| Lab 5 | [Julie — Planner Agent](lab05-julie-planner-agent.md) | Crear el agente orquestador de campañas de marketing usando el patrón workflow con sub-agentes (SqlAgent, MarketingAgent) y herramienta OpenAPI. |

---

## Setup de infraestructura

Antes de iniciar los laboratorios, cada participante debe desplegar la infraestructura de Azure en su propia suscripción. El proceso es automatizado con Bicep y un script de PowerShell.

El proyecto ofrece **dos opciones de despliegue** ubicadas en carpetas hermanas bajo `setup/`. Ambas despliegan los mismos recursos lógicos y publican el mismo código C# de `FxContosoRetail`, pero difieren en el plan de hosting y modelo de seguridad.

| | Opción Flex Consumption ⭐ | Opción Consumption Clásico |
|---|---|---|
| **Carpeta** | `setup/op-flex` | `setup/op-consumption` |
| **Plan SKU** | FC1 / FlexConsumption | Y1 / Dynamic (Consumption) |
| **SO** | Linux | Windows |
| **Autenticación al Storage** | Managed Identity (sin secrets) | Connection string (SharedKey) |
| **File Share** | No requiere | Requiere file share pre-creado |
| **Seguridad** | `allowSharedKeyAccess: false` | `allowSharedKeyAccess: true` |

> **Recomendación:** Usa la opción **Flex Consumption** (`op-flex`). Es el modelo más moderno y seguro: no almacena secrets en app settings, usa Managed Identity para la autenticación al Storage y no requiere file shares.

### Prerrequisitos

- **Azure CLI** instalado y actualizado ([instalar](https://aka.ms/installazurecli))
- **.NET 8 SDK** instalado ([descargar](https://dotnet.microsoft.com/download/dotnet/8.0))
- **PowerShell** 5.1 o superior (Windows) o PowerShell Core 7+ (macOS/Linux)
- Una **suscripción de Azure** activa con permisos de Owner o Contributor
- El **nombre del tenant temporal** asignado

### Iniciar sesión en Azure

Antes de ejecutar cualquier script de despliegue, debes autenticarte en Azure desde la terminal.

1. **Abrir una terminal en VS Code:** usa el menú **Terminal → New Terminal** o el atajo <kbd>Ctrl</kbd>+<kbd>`</kbd>.

2. **Iniciar sesión con Azure CLI:**

   ```powershell
   az login
   ```

   Esto abrirá el navegador para que te autentiques con tu cuenta de Azure. Una vez completado, la terminal mostrará la lista de suscripciones disponibles.

3. **Verificar la suscripción activa:**

   ```powershell
   az account show --output table
   ```

   Confirma que la suscripción mostrada es la correcta para el taller. Si necesitas cambiarla:

   ```powershell
   az account set --subscription "nombre-o-id-de-la-suscripcion"
   ```

> **Nota:** El script de despliegue también verifica automáticamente si hay una sesión activa y, en caso contrario, lanza `az login`. Sin embargo, es recomendable asegurarte de que estás autenticado antes de ejecutarlo para evitar interrupciones.

### Recursos que se crean

Ambas opciones provisionan los siguientes recursos dentro del Resource Group `rg-contoso-retail`:

| Recurso | Nombre | Descripción |
|---------|--------|-------------|
| Storage Account | `stcontosoretail{suffix}` | Almacenamiento para la Function App |
| App Service Plan | `asp-contosoretail-{suffix}` | Plan de hosting (FC1 en Flex, Y1 en Consumption) |
| Function App | `func-contosoretail-{suffix}` | API de Contoso Retail (.NET 8, dotnet-isolated) |
| AI Foundry Resource | `ais-contosoretail-{suffix}` | Recurso unificado de AI Foundry (AI Services + gestión de proyectos) con modelo GPT-4.1 desplegado |
| AI Foundry Project | `aip-contosoretail-{suffix}` | Proyecto de trabajo dentro del Foundry Resource |
| Blob Container | `reports` | Contenedor para reportes generados |

> **Nota:** El `{suffix}` es un identificador único de 5 caracteres generado automáticamente a partir del nombre de tu tenant. Esto garantiza que los nombres de los recursos no colisionen entre participantes.

---

### Opción 1 (Recomendada): Flex Consumption (`op-flex`)

Modelo moderno basado en Linux con autenticación por Managed Identity. El Storage Account no expone shared keys y la Function App se autentica mediante URIs de blob/queue/table con credencial de identidad administrada. Los permisos RBAC se asignan automáticamente vía `storage-rbac.bicep`.

> **Nota:** El endpoint SCM de Flex Consumption puede tardar en estar disponible (resolución DNS). El script de despliegue incluye lógica de reintentos y espera automática.

1. **Abrir una terminal PowerShell** en la raíz del repositorio.

2. **Navegar a la carpeta de Flex Consumption:**

   ```powershell
   cd labs\foundry\setup\op-flex
   ```

3. **Ejecutar el script de despliegue** con tu nombre de tenant:

   ```powershell
   .\deploy.ps1 -TenantName "tu-tenant-temporal"
   ```

4. **Revisar la salida.** Al finalizar, el script muestra los nombres y URLs de todos los recursos creados. Toma nota de estos valores, los necesitarás en los laboratorios.

---

### Opción 2: Consumption Clásico (`op-consumption`)

Modelo clásico basado en Windows con autenticación por connection string. Requiere un Azure Files share pre-creado (incluido en el Bicep) para evitar race conditions. Los app settings incluyen `WEBSITE_CONTENTAZUREFILECONNECTIONSTRING` y `WEBSITE_CONTENTSHARE`.

1. **Abrir una terminal PowerShell** en la raíz del repositorio.

2. **Navegar a la carpeta de Consumption:**

   ```powershell
   cd labs\foundry\setup\op-consumption
   ```

3. **Ejecutar el script de despliegue** con tu nombre de tenant:

   ```powershell
   .\deploy.ps1 -TenantName "tu-tenant-temporal"
   ```

4. **Revisar la salida.** Al finalizar, el script muestra los nombres y URLs de todos los recursos creados.

---

### Opciones adicionales (ambas variantes)

Puedes personalizar la región o el nombre del Resource Group:

```powershell
# Usar otra región
.\deploy.ps1 -TenantName "tu-tenant" -Location "eastus"

# Cambiar el nombre del Resource Group
.\deploy.ps1 -TenantName "tu-tenant" -ResourceGroupName "mi-rg-personalizado"
```

### Verificación

Después del despliegue, verifica que los recursos se crearon correctamente:

```powershell
az resource list --resource-group rg-contoso-retail --output table
```

---

### Permisos RBAC para Azure AI Foundry

Para que los agentes puedan crearse y ejecutarse en Azure AI Foundry, tu usuario necesita el rol **Cognitive Services User** sobre el recurso de AI Services. Este rol incluye el data action `Microsoft.CognitiveServices/*` necesario para operaciones de agentes. Si no lo tienes, obtendrás un error `PermissionDenied` al intentar crear agentes.

Ejecuta los siguientes comandos para asignar el rol (reemplaza `{suffix}` con tu sufijo de 5 caracteres):

```powershell
# Obtener tu nombre de usuario (UPN)
$upn = az account show --query "user.name" -o tsv

# Asignar el rol Cognitive Services User sobre el recurso de AI Services
az role assignment create `
    --assignee $upn `
    --role "Cognitive Services User" `
    --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/rg-contoso-retail/providers/Microsoft.CognitiveServices/accounts/ais-contosoretail-{suffix}"
```

> **Nota:** Si no conoces el nombre exacto del recurso, puedes averiguarlo con:
> ```powershell
> az cognitiveservices account list --resource-group rg-contoso-retail --query "[].name" -o tsv
> ```
>
> La propagación de RBAC puede tardar hasta 1 minuto. Espera antes de intentar crear agentes.

---

## Estructura del código

```
labs/foundry/
├── README.md                              ← Este archivo
├── lab04-anders-executor-agent.md          ← Lab 4: Agente Anders
├── lab05-julie-planner-agent.md           ← Lab 5: Agente Julie
├── setup/
│   ├── op-flex/                           ← ⭐ Opción recomendada (Flex Consumption / Linux)
│   │   ├── main.bicep
│   │   ├── storage-rbac.bicep
│   │   └── deploy.ps1
│   └── op-consumption/                    ← Opción clásica (Consumption Y1 / Windows)
│       ├── main.bicep
│       ├── storage-rbac.bicep
│       └── deploy.ps1
└── code/
    ├── api/
    │   └── FxContosoRetail/               ← Azure Function (API)
    │       ├── FxContosoRetail.cs          ← Endpoints: HolaMundo, OrdersReporter
    │       ├── Program.cs
    │       ├── Models/
    │       └── ...
    ├── agents/
    │   ├── AndersAgent/                   ← Console App: Agente Anders (kind: prompt + OpenAPI tool)
    │   │   ├── ms-foundry/                ← Versión Responses API (recomendada)
    │   │   │   ├── Program.cs
    │   │   │   └── appsettings.json
    │   │   └── ai-foundry/                ← Versión Persistent Agents API (alternativa)
    │   │       └── ...
    │   └── JulieAgent/                    ← Console App: Agente Julie (kind: workflow)
    │       ├── Program.cs                 ← Crea los 3 agentes + chat con Julie
    │       ├── JulieAgent.cs              ← Julie: workflow con 3 tools (SqlAgent, MarketingAgent, OpenAPI)
    │       ├── SqlAgent.cs                ← Sub-agente: genera T-SQL a partir de lenguaje natural
    │       ├── MarketingAgent.cs           ← Sub-agente: genera mensajes con Bing Search
    │       ├── db-structure.txt            ← DDL de la BD inyectada en SqlAgent
    │       └── appsettings.json
    └── tests/
        ├── bruno/                         ← Colección Bruno (REST client)
        │   ├── bruno.json
        │   ├── OrdersReporter.bru
        │   └── environments/
        │       └── local.bru
        └── http/
            └── FxContosoRetail.http       ← Archivo .http (VS Code REST Client)
```

---

## Siguiente paso

Una vez completado el setup, continúa con el [Lab 4 — Anders (Executor Agent)](lab04-anders-executor-agent.md).
