// =====================================================================
//  JulieAgent — Agente orquestador de campañas de marketing
//
//  Julie es un agente de tipo workflow que coordina:
//  1. SqlAgent (type: agent) — genera T-SQL a partir de lenguaje natural
//  2. Function App (type: openapi) — ejecuta el T-SQL contra la BD
//  3. MarketingAgent (type: agent) — genera mensajes personalizados
//
//  El resultado final es un JSON de campaña con correos electrónicos.
//
//  Herramientas:
//    - SqlAgent        → agente que genera la consulta T-SQL
//    - ContosoRetailDB → OpenAPI tool que ejecuta el SQL contra la BD
//    - MarketingAgent  → agente que genera mensajes de marketing
//
//  La URL de la Function App se configura en appsettings.json
//  (FunctionAppBaseUrl). Si no está configurada, Julie se crea
//  sin la herramienta OpenAPI (pendiente de despliegue).
// =====================================================================

using System.Text.Json;

namespace JulieAgent;

public static class JulieOrchestrator
{
    public const string Name = "Julie";

    public static string Instructions => """
        Eres Julie, la agente planificadora y orquestadora de campañas de marketing
        de Contoso Retail.

        Tu responsabilidad es coordinar la creación de campañas de marketing
        personalizadas para segmentos específicos de clientes.

        Cuando recibas una solicitud de campaña sigues estos pasos:

        1. EXTRACCIÓN: Analiza el prompt del usuario y extrae la descripción
           del segmento de clientes. Resume esa descripción en una frase clara.

        2. GENERACIÓN SQL: Invoca a SqlAgent pasándole la descripción del segmento.
           SqlAgent te retornará una consulta T-SQL.

        3. EJECUCIÓN SQL: Envía el T-SQL a tu herramienta OpenAPI (ContosoRetailDB)
           para ejecutarlo contra la base de datos. La herramienta retornará los
           resultados como datos de clientes.

        4. MARKETING PERSONALIZADO: Para CADA cliente retornado, invoca a
           MarketingAgent pasándole el nombre del cliente y su categoría favorita.
           MarketingAgent buscará eventos relevantes en Bing y generará un mensaje
           personalizado.

        5. ORGANIZACIÓN FINAL: Con todos los mensajes generados, organiza el
           resultado como un JSON de campaña con el siguiente formato:

        ```json
        {
          "campaign": "Nombre descriptivo de la campaña",
          "generatedAt": "YYYY-MM-DDTHH:mm:ss",
          "totalEmails": N,
          "emails": [
            {
              "to": "email@ejemplo.com",
              "customerName": "Nombre Apellido",
              "favoriteCategory": "Categoría",
              "subject": "Asunto del correo generado automáticamente",
              "body": "Mensaje de marketing personalizado"
            }
          ]
        }
        ```

        REGLAS:
        - El campo "subject" debe ser un asunto de correo atractivo y relevante.
        - El campo "body" es el mensaje que generó MarketingAgent para ese cliente.
        - Responde siempre en español.
        - Si algún cliente no tiene email, omítelo del resultado.
        - Genera un nombre descriptivo para la campaña basado en el segmento.
        """;

    /// <summary>
    /// Construye la definición del agente Julie como workflow.
    /// Herramientas: SqlAgent (agent), MarketingAgent (agent), ContosoRetailDB (openapi).
    /// Si openApiSpec es null (Function App no desplegada), la herramienta OpenAPI
    /// se omite y queda pendiente de configuración.
    /// </summary>
    public static object GetAgentDefinition(string modelDeployment, JsonElement? openApiSpec = null)
    {
        var tools = new List<object>
        {
            // SqlAgent como herramienta tipo agente
            new
            {
                type = "agent",
                agent = new
                {
                    name = SqlAgent.Name,
                    description = "Agente que genera consultas T-SQL a partir de una descripción en lenguaje natural de un segmento de clientes. Retorna únicamente el código SQL."
                }
            },
            // MarketingAgent como herramienta tipo agente
            new
            {
                type = "agent",
                agent = new
                {
                    name = MarketingAgent.Name,
                    description = "Agente que genera mensajes de marketing personalizados. Recibe el nombre del cliente y su categoría favorita, busca eventos relevantes en Bing y genera un mensaje motivacional."
                }
            }
        };

        // OpenAPI tool para ejecutar SQL contra la BD (solo si la Function App está desplegada)
        if (openApiSpec.HasValue)
        {
            tools.Add(new
            {
                type = "openapi",
                openapi = new
                {
                    name = "ContosoRetailDB",
                    description = "API de Contoso Retail para ejecutar consultas T-SQL contra la base de datos y retornar los resultados como JSON",
                    spec = openApiSpec.Value,
                    auth = new { type = "anonymous" }
                }
            });
        }

        return new
        {
            definition = new
            {
                kind = "workflow",
                model = modelDeployment,
                instructions = Instructions,
                tools = tools.ToArray()
            }
        };
    }
}
