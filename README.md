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

El flujo operativo responde a situaciones concretas como disputas de facturación, pagos aparentemente inconsistentes o facturas vencidas. En este flujo, el objetivo es reconstruir los hechos con precisión, ejecutar las acciones necesarias (como generar reportes) y explicar claramente qué está ocurriendo.

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
  theme: neo-dark
---
flowchart LR
 subgraph CS["Copilot Studio"]
        Charles["Charles"]
        Bill((("Bill (Orch)")))
        Ric{{"Ric (Child)"}}
  end
 subgraph MF["Microsoft Fabric"]
        Jeffrey["Mark (Op. Facts)"]
        Amy["Amy (Analytics)"]
  end
 subgraph AF["Azure AI Foundry"]
        Anders["Anders (Executor)"]
        Julie["Julie (Planner)"]
  end
    MF ~~~ AF
    Charles L_Charles_Bill_0@--> Bill
    Bill L_Bill_Charles_0@--> Charles & Ric
    Bill <-- OP1 --> Jeffrey
    Bill <-- OP2 --> Anders
    Bill <-- AN1 --> Amy
    Bill <-- AN2 --> Julie

    linkStyle 1 stroke:#32CD32,stroke-width:3px,color:#32CD32,fill:none
    linkStyle 2 stroke:#32CD32,stroke-width:3px,color:#32CD32,fill:none
    linkStyle 3 stroke:#32CD32,stroke-width:3px,color:#32CD32,fill:none
    linkStyle 4 stroke:#E02828,stroke-width:3px,color:#E02828,fill:none
    linkStyle 5 stroke:#E02828,stroke-width:3px,color:#E02828,fill:none
    linkStyle 6 stroke:#2880E0,stroke-width:3px,color:#2880E0,fill:none
    linkStyle 7 stroke:#2880E0,stroke-width:3px,color:#2880E0,fill:none

    L_Charles_Bill_0@{ curve: natural } 
    L_Bill_Charles_0@{ curve: natural }
```

La arquitectura está compuesta por **siete agentes**, distribuidos en tres capas. Cada agente tiene **una única responsabilidad** y atiende **un solo tipo de escenario** (operativo o analítico).

### Microsoft Fabric – Capa de datos

- **Mark (Operational Facts Agent)**
  Reconstruye hechos transaccionales exactos usando SQL sobre el modelo de datos. Entrega solo datos trazables, sin interpretación.
- **Amy (Analytics Agent)**
  Calcula métricas agregadas, tendencias, variaciones y outliers. Entrega señales cuantitativas, sin recomendaciones.

#### Documentación de la base de datos

Para comprender mejor el modelo de datos sobre el cual operan los agentes de Fabric, se ha agregado documentación detallada de la base de datos de Contoso Retail. Esta documentación incluye:

- **Diagrama ER (Entidad-Relación)** que muestra las relaciones entre las tablas principales
- **Esquemas de tablas** con todos los campos y tipos de datos

Puedes consultar la documentación completa aquí: [Database Documentation](./assets/database.md)

### Azure AI Foundry – Capa de razonamiento

- **Anders (Executor Agent)**
  Ejecuta acciones operativas concretas como la generación y publicación de reportes, renderizado de facturas y otras tareas que requieren interacción con servicios externos.
- **Julie (Planner Agent)**
  Convierte señales analíticas en prioridades y planes de acción, incluyendo resúmenes ejecutivos.

### Copilot Studio – Capa de orquestación

- **Charles (UI Agent)**
  Interactúa con el usuario, recoge intención y presenta la respuesta final.
- **Bill (Orchestrator)**
  Decide el flujo de ejecución, invoca a los agentes correctos en el orden adecuado y consolida el resultado.
- **Ric (Child Agent)**
  Agente hijo que extiende las capacidades de orquestación del sistema.

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
- [Lab 2 – Agente Mark: hechos operativos](./labs/fabric/lab02-mark-facts-agent.md)
- [Lab 3 – Agente Amy: analítica y señales](./labs/fabric/lab03-amy-analytics-agent.md)

### 2. Laboratorios de Azure AI Foundry

- [Lab 4 – Agente Anders: ejecución operativa](./labs/foundry/lab04-anders-executor-agent.md)
- [Lab 5 – Agente Julie: planificación analítica](./labs/foundry/lab05-julie-planner-agent.md)

### 3. Laboratorios de Copilot Studio

- [Lab 6 – Agente Charles: experiencia conversacional](./labs/copilot/lab06-charles-copilot-agent.md)
- [Lab 7 – Agente Ric: agente hijo](./labs/copilot/lab07-ric-child-agent.md)
- [Lab 8 – Orquestador Bill: control del flujo multi‑agente](./labs/copilot/lab08-bill-orchestrator.md)

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
