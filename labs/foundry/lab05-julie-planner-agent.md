# Lab 05: Julie Planner Agent

## Nota de continuidad del setup

Este laboratorio asume que ya completaste:

- El despliegue base de infraestructura de Foundry (`labs/foundry/README.md`)
- El flujo de datos en Fabric del **Lab 01** (`lab01-data-setup.md`)

En particular, para el setup actualizado se requieren estos valores:

- `FabricWarehouseSqlEndpoint`
- `FabricWarehouseDatabase`

Estos se obtienen desde el connection string SQL del Warehouse de Fabric:

- `FabricWarehouseSqlEndpoint` = `Data Source` sin `,1433`
- `FabricWarehouseDatabase` = `Initial Catalog`

Si no estás siguiendo toda la secuencia de laboratorios, para Lab 05 también puedes usar una base SQL standalone (por ejemplo Azure SQL Database) ajustando esos dos valores al host y nombre de base correspondientes.

Si no proporcionas estos valores durante el setup, el despliegue de infraestructura no falla, pero la conexión SQL para Lab 05 no se configura automáticamente y debe ajustarse manualmente en la Function App.
