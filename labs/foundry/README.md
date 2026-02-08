# Azure AI Foundry — Taller Multi-Agéntico

## Introducción

Esta sección del taller cubre la **capa de razonamiento y ejecución** de la arquitectura multi-agéntica de Contoso Retail, implementada sobre **Azure AI Foundry**. Aquí se construyen los agentes inteligentes que interpretan datos y planifican acciones (ejecutando algunas),a partir de la información generada por la capa de datos (Microsoft Fabric).

### Agentes de esta capa

| Agente | Rol | Descripción |
|--------|-----|-------------|
| **Anders** | Interpreter Agent | Recibe los hechos y analíticas de la capa Fabric y los interpreta para generar conclusiones accionables. Actúa como el puente entre los datos crudos y las decisiones de negocio. |
| **Julie** | Planner Agent | Toma las interpretaciones de Anders y elabora planes de acción concretos. Coordina qué pasos deben ejecutarse para cumplir los objetivos del negocio. |

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

Los agentes Anders y Julie consumen la API expuesta por la Azure Function (`FxContosoRetail`) y utilizan modelos GPT-4.1 desplegados en Azure AI Services para razonar sobre la información del negocio.

---

## Laboratorios

| Lab | Archivo | Descripción |
|-----|---------|-------------|
| Lab 4 | [Anders — Interpreter Agent](lab04-anders-interpreter-agent.md) | Crear el agente intérprete que analiza los datos de Contoso Retail. |
| Lab 5 | [Julie — Planner Agent](lab05-julie-planner-agent.md) | Crear el agente planificador que genera planes de acción. |

---

## Setup de infraestructura

Antes de iniciar los laboratorios, cada participante debe desplegar la infraestructura de Azure en su propia suscripción. El proceso es automatizado con Bicep y un script de PowerShell.

### Prerrequisitos

- **Azure CLI** instalado y actualizado ([instalar](https://aka.ms/installazurecli))
- **PowerShell** 5.1 o superior (Windows) o PowerShell Core 7+ (macOS/Linux)
- Una **suscripción de Azure** activa con permisos de Owner o Contributor
- El **nombre del tenant temporal** asignado

### Recursos que se crean

El despliegue provisiona los siguientes recursos dentro del Resource Group `rg-contoso-retail`:

| Recurso | Nombre | Descripción |
|---------|--------|-------------|
| Storage Account | `stcontosoretail{suffix}` | Almacenamiento para la Function App (conexión basada en identidad, sin claves) |
| App Service Plan | `asp-contosoretail-{suffix}` | Plan Consumption (Y1) para la Function App |
| Function App | `func-contosoretail-{suffix}` | API de Contoso Retail (.NET 8, dotnet-isolated) |
| AI Foundry Resource | `ais-contosoretail-{suffix}` | Recurso unificado de AI Foundry (AI Services + gestión de proyectos) con modelo GPT-4.1 desplegado |
| AI Foundry Project | `aip-contosoretail-{suffix}` | Proyecto de trabajo dentro del Foundry Resource |

> **Nota:** El `{suffix}` es un identificador único de 5 caracteres generado automáticamente a partir del nombre de tu tenant. Esto garantiza que los nombres de los recursos no colisionen entre participantes.

### Instrucciones de despliegue

1. **Abrir una terminal PowerShell** en la raíz del repositorio.

2. **Navegar a la carpeta de setup:**

   ```powershell
   cd labs\foundry\setup
   ```

3. **Ejecutar el script de despliegue** con tu nombre de tenant:

   ```powershell
   .\deploy.ps1 -TenantName "tu-tenant-temporal"
   ```

   El script realizará lo siguiente:
   - Verificará que Azure CLI esté instalado
   - Verificará que tengas una sesión activa (si no, abrirá el flujo de login)
   - Creará el Resource Group `rg-contoso-retail`
   - Desplegará toda la infraestructura (~5 minutos)

4. **Revisar la salida.** Al finalizar, el script muestra los nombres y URLs de todos los recursos creados. Toma nota de estos valores, los necesitarás en los laboratorios.

### Opciones adicionales

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

## Estructura del código

```
labs/foundry/
├── README.md                              ← Este archivo
├── lab04-anders-interpreter-agent.md      ← Lab 4: Agente Anders
├── lab05-julie-planner-agent.md           ← Lab 5: Agente Julie
├── setup/
│   ├── main.bicep                         ← Plantilla de infraestructura
│   ├── storage-rbac.bicep                 ← Asignaciones RBAC para Storage
│   └── deploy.ps1                         ← Script de despliegue
└── code/
    ├── api/
    │   └── FxContosoRetail/               ← Azure Function (API)
    │       ├── FxContosoRetail.cs          ← Endpoints: HolaMundo, OrdersReporter
    │       ├── Program.cs
    │       ├── Models/
    │       └── ...
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

Una vez completado el setup, continúa con el [Lab 4 — Anders (Interpreter Agent)](lab04-anders-interpreter-agent.md).
