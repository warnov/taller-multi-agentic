## Descripción general

Este workshop práctico guía a los participantes en el diseño e implementación de una arquitectura **multi-agente** usando servicios de Microsoft, aplicada a un escenario de negocio tipo **Contoso Retail**. El foco del ejercicio no es construir un sistema productivo, sino entender cómo **orquestar agentes con responsabilidades claras** para resolver distintos tipos de preguntas de negocio sobre un mismo conjunto de datos.

La arquitectura integra tres capas bien definidas:

- **Microsoft Fabric**, como fuente de datos y analítica.
- **Azure AI Foundry**, como capa de razonamiento y decisión.
- **Copilot Studio**, como capa de orquestación y experiencia conversacional.

Copilot Studio actúa como el único punto de entrada y salida para el usuario, coordinando el trabajo de los agentes de datos y de razonamiento para entregar una única respuesta coherente.

------

## Escenario de negocio: Contoso Retail

Contoso es una empresa de retail que vende productos a clientes empresariales y finales. Su modelo de datos incluye información de clientes, cuentas, órdenes, líneas de orden, facturas, pagos, productos y categorías.

Sobre esta base, el negocio necesita responder dos tipos de preguntas frecuentes:

1. **Preguntas operativas**, orientadas a entender qué ocurrió en un caso puntual.
2. **Preguntas analíticas**, orientadas a entender patrones, tendencias y señales del negocio.

El workshop muestra cómo una misma arquitectura puede atender ambos tipos de necesidades sin duplicar sistemas ni lógica.

------

## Flujos de negocio cubiertos

### Flujo operativo

El flujo operativo responde a situaciones concretas como disputas de facturación, pagos aparentemente inconsistentes o facturas vencidas. En este flujo, el objetivo es reconstruir los hechos con precisión, interpretarlos y explicar claramente qué está ocurriendo.

Ejemplos de preguntas operativas:

- ¿Por qué una factura aparece vencida si el cliente dice haber pagado?
- ¿Existe un pago registrado que no fue aplicado a una orden?
- ¿La deuda es legítima o se trata de una inconsistencia operativa?

### Flujo analítico

El flujo analítico responde a preguntas de carácter estratégico y exploratorio. Aquí el objetivo no es explicar un caso puntual, sino identificar señales relevantes que ayuden a priorizar acciones.

Ejemplos de preguntas analíticas:

- ¿Cómo está evolucionando el revenue de un cliente o categoría?
- ¿Existen cambios en el mix de productos?
- ¿Se observa un aumento en pagos tardíos o concentración en pocos SKUs?

------

## Arquitectura y agentes

``` mermaid
---
config:
  look: neo
---
flowchart LR

  subgraph CS["Copilot Studio"]
    Charles["Charles"]
    Bill((("Bill (Orch)")))
    Ric{{"Ric (Child)"}}
  end

  subgraph MF["Microsoft Fabric"]
    Mark["Mark (Op. Facts)"]
    Amy["Amy (Analytics)"]
  end

  subgraph AF["Azure AI Foundry"]
    Anders["Anders (Interpreter)"]
    Julie["Julie (Planner)"]
  end

  %% Conexión invisible (Índice 0)
  MF ~~~ AF

  %% Conexiones
  Charles --> Bill
  Bill --> Charles
  Bill --> Ric
  Bill <-->|OP1| Mark
  Bill <-->|OP2| Anders
  Bill <-->|AN1| Amy
  Bill <-->|AN2| Julie

  %% Estilos Verdes: Internos CS (Charles y Ric)
  linkStyle 1,2,3 stroke:#32CD32,stroke-width:3px,color:#32CD32
  
  %% Estilos Rojos: Operativos (Mark y Anders)
  linkStyle 4,5 stroke:#E02828,stroke-width:3px,color:#E02828
  
  %% Estilos Azules: Analíticos (Amy y Julie)
  linkStyle 6,7 stroke:#2880E0,stroke-width:3px,color:#2880E0
```

La arquitectura está compuesta por **seis agentes**, distribuidos en tres capas. Cada agente tiene **una única responsabilidad** y atiende **un solo tipo de escenario** (operativo o analítico).

### Microsoft Fabric – Capa de datos

- **Aurelio (Operational Facts Agent)**
  Reconstruye hechos transaccionales exactos usando SQL sobre el modelo de datos. Entrega solo datos trazables, sin interpretación.
- **Nora (Analytics Agent)**
  Calcula métricas agregadas, tendencias, variaciones y outliers. Entrega señales cuantitativas, sin recomendaciones.

### Azure AI Foundry – Capa de razonamiento

- **Bruno (Interpreter Agent)**
  Interpreta hechos operativos y los traduce en una explicación de negocio clara y estructurada.
- **Clara (Planner Agent)**
  Convierte señales analíticas en prioridades y planes de acción, incluyendo resúmenes ejecutivos.

### Copilot Studio – Capa de orquestación

- **Sofía (UI Agent)**
  Interactúa con el usuario, recoge intención y presenta la respuesta final.
- **Orion (Orchestrator)**
  Decide el flujo de ejecución, invoca a los agentes correctos en el orden adecuado y consolida el resultado.

------

## Objetivo del workshop

Al finalizar el workshop, los participantes comprenderán:

- Cómo separar datos, razonamiento y experiencia de usuario.
- Cómo diseñar agentes con responsabilidades bien delimitadas.
- Cómo orquestar flujos operativos y analíticos sobre un mismo dominio de negocio.
- Cómo usar Copilot Studio como capa central de control en soluciones multi-agente.

Este repositorio sirve como guía práctica y reutilizable para entender y replicar este patrón arquitectónico en escenarios reales.

## Tabla de contenidos del workshop

El workshop está dividido en laboratorios independientes pero conectados, organizados por capa arquitectónica. Se recomienda seguirlos en el orden indicado.

### 1. Laboratorios de Microsoft Fabric

- [Lab 1 – Preparación de datos y modelo de retail](./labs/fabric/lab01-data-setup.md)
- [Lab 2 – Agente Aurelio: hechos operativos](./labs/fabric/lab02-aurelio-facts-agent.md)
- [Lab 3 – Agente Nora: analítica y señales](./labs/fabric/lab03-nora-analytics-agent.md)

### 2. Laboratorios de Azure AI Foundry

- [Lab 4 – Agente Bruno: interpretación operativa](./labs/foundry/lab04-bruno-interpreter-agent.md)
- [Lab 5 – Agente Clara: planificación analítica](./labs/foundry/lab05-clara-planner-agent.md)

### 3. Laboratorios de Copilot Studio

- [Lab 6 – Agente Sofía: experiencia conversacional](./labs/copilot/lab06-sofia-copilot-agent.md)
- [Lab 7 – Orquestador Orion: control del flujo multi‑agente](./labs/copilot/lab07-orion-orchestrator.md)

---

## Resultado esperado

Al finalizar el workshop, los participantes habrán construido y comprendido:

- Cómo diseñar agentes con responsabilidades claras.
- Cómo separar datos, razonamiento y experiencia de usuario.
- Cómo orquestar múltiples agentes desde Copilot Studio.
- Cómo reutilizar el mismo patrón arquitectónico para distintos escenarios de negocio.

Este repositorio sirve como guía práctica y reutilizable para diseñar soluciones multi‑agente en proyectos reales.

---

## Requisitos previos

- Conocimientos básicos de Azure.
- Familiaridad general con conceptos de datos y analítica.
- No se requiere experiencia previa profunda en Fabric, Foundry o Copilot Studio.

---

## Notas finales

Este workshop está pensado como un ejercicio **pedagógico y arquitectónico**. El foco está en el diseño del flujo y la colaboración entre agentes, no en optimizar modelos ni consultas al extremo.