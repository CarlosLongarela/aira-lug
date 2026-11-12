# Hermes
## Opciones de configuración para ahorrar tokens en las llamadas

- Abre un chat nuevo al cambiar de tarea, en lugar de acumular asuntos diferentes en la misma conversación.

- **Configuración → Memoria y contexto → Contexto y compresión → Compresión automática:** *Activado*. Resume el historial para evitar seguir enviándolo completo.

- **En esa misma pantalla → Umbral de compresión** *0.50* (50 %) como punto de partida. Si las conversaciones crecen demasiado, prueba *0.30*. Comprimir antes reduce el historial enviado, pero también puede perder detalles y genera llamadas de resumen.

- **En esa misma pantalla → Aumento automático de compresión de Codex** *Desactivado* si utilizas Codex y tu prioridad es reducir tokens. Esta opción puede elevar automáticamente el umbral al 85 %, dejando crecer mucho más el contexto.

- **Configuración → Avanzado → Acceso a herramientas → Conjunto de herramientas activadas** Mantén solo las herramientas que necesitas habitualmente. Desactiva, por ejemplo, generación de imágenes o control del ordenador cuando no los uses.

- **Configuración → Avanzado → Límites de salida → Límite de salida del terminal** Prueba *12000* bytes para evitar grandes volcados de terminal. Si falta información, puedes subirlo.

- **Configuración → Avanzado → Límites del agente → Pasos máximos del agente** Prueba *20* para trabajo cotidiano. Limita las cadenas de llamadas; las tareas complejas pueden necesitar más pasos.

- **Configuración → Modelo → Modelo principal → Valores predeterminados → Razonamiento:** *Bajo* para consultas y redacción; *Medio* para programación habitual. Reserva los niveles altos para problemas difíciles. En un chat abierto, cambia también el nivel desde la etiqueta de razonamiento junto al selector del modelo.

- **Configuración → Modelo → Modelos auxiliares:** Para títulos y compresión configura *Bajo*, *Mínimo* o *Desactivado*, cuando el modelo lo permita. Puedes elegir un modelo más económico para estas tareas; el de compresión debe admitir suficiente contexto. Esto puede reducir el coste, aunque no necesariamente los tokens de entrada.

- Activamos el medidor de contexto (también es útil activar agentes y terminal):

    1. Haz clic derecho en una zona vacía de la barra inferior, donde aparecen los proveedores y la versión.
    2. En Mostrar en la barra de estado, activa Medidor de contexto (Context meter).
    3. Con una conversación abierta, pulsa ese indicador para ver el desglose por historial, herramientas, memoria, etc.
