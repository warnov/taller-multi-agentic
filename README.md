# taller-multi-agentic
Laboratorio práctico para construir una arquitectura multi-agente con Microsoft Fabric, Azure AI Foundry y Copilot Studio, mostrando cómo orquestar datos, razonamiento y acción en una experiencia conversacional unificada.

## Descripción general

Este workshop práctico está diseñado para guiar a los participantes en la construcción de una arquitectura **multi‑agente** completamente orquestada desde **Copilot Studio**, integrando tres capas clave de la plataforma Microsoft:

- **Microsoft Fabric**, como capa de datos y analítica.
- **Azure AI Foundry**, como capa de razonamiento y decisión.
- **Copilot Studio**, como capa de orquestación y experiencia conversacional.

El objetivo principal no es profundizar en la complejidad técnica de cada servicio por separado, sino **entender el patrón arquitectónico**, las responsabilidades de cada agente y cómo se comunican entre sí para resolver problemas reales de negocio de forma trazable, controlada y escalable.

Durante el workshop se construirá un único escenario integrado que permite observar dos perspectivas complementarias:

- Una **operativa**, orientada a hechos transaccionales y resolución de casos concretos.
- Una **analítica**, orientada a tendencias, patrones e insights para la toma de decisiones.

---

## Escenario del workshop

El escenario se basa en datos de **retail**, incluyendo clientes, órdenes, facturas, pagos, productos y categorías. A partir de esta base de datos común, se habilitan dos tipos de flujos:

- **Flujo operativo**: permite analizar situaciones transaccionales como estados de facturación, pagos no aplicados o inconsistencias entre órdenes y facturas.
- **Flujo analítico**: permite analizar el comportamiento del negocio, detectar tendencias, variaciones, concentraciones y señales relevantes para la gestión comercial y financiera.

Ambos flujos comparten la misma arquitectura, pero activan agentes distintos según la intención del usuario.

---

## Arquitectura conceptual

La arquitectura completa está compuesta por seis agentes distribuidos en tres capas:

### Microsoft Fabric (capa de datos)

- **Aurelio** – Agente de hechos operativos.
- **Nora** – Agente de analítica y señales.

### Azure AI Foundry (capa de razonamiento)

- **Bruno** – Agente intérprete para escenarios operativos.
- **Clara** – Agente planificador para escenarios analíticos.

### Copilot Studio (capa de orquestación)

- **Sofía** – Agente conversacional visible para el usuario.
- **Orion** – Orquestador que controla el flujo entre agentes.

Copilot Studio es el único punto de entrada y salida. Fabric entrega datos, Foundry razona sobre esos datos y Copilot consolida una única respuesta para el usuario.

---

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
