(function () {
  "use strict";

  /* ------------------------------------------------------------------ *
   * Translations (English + Spanish). No external libraries.           *
   * Keys map to [data-i18n] (innerHTML) and [data-i18n-aria] (aria).   *
   * ------------------------------------------------------------------ */
  var translations = {
    en: {
      "hero.eyebrow": "Software Development Project",
      "hero.tagline": "A graph-based puzzle game where every arrow is rigid, every exit is deliberate.",
      "nav.overview": "Overview",
      "nav.workflow": "AI Workflow",
      "nav.highlights": "Technical Highlights",
      "nav.implementation": "Implementation",
      "nav.closing": "Closing",
      "lang.aria": "Switch language to Spanish",

      "s1.title": "Project Overview",
      "s1.lead": "Nodus is a graph-based puzzle game. Each level is a graph of nodes and edges covered by rigid arrows. Tapping an arrow attempts a single, atomic full exit in its head direction — the arrow either escapes the board entirely, or the move is rolled back exactly as it was. There is no partial movement, which turns every level into a question of <em>order</em>: which arrow can leave now so that the others eventually can too.",
      "o1.h": "Graph-Based Mechanics",
      "o1.p": "The board is never a grid of tiles. It is a true graph: nodes joined by edges, with rigid multi-node arrows laid over them. Movement is resolved as a coordinate sweep from each arrow's head — if the path is clear the whole arrow slides off; if it is blocked, the attempt is undone atomically. This graph model is what makes both flat and layered boards possible with one set of rules.",
      "o2.h": "2D &amp; 3D Modes",
      "o2.p": "The game ships two full modes: flat 2D boards and multi-layer 3D boards rendered through a rotatable perspective camera you can orbit and zoom. Both share the same underlying resolver — the extra dimension is handled by a direction abstraction, not by special-cased physics, so a 3D level is just a graph whose arrows can also travel between stacked layers.",
      "o3.h": "Challenge System",
      "o3.p": "On top of the campaign, three challenge types re-use existing levels with new pressure: Time Attack (a calculated clock), Move Limit (a bounded budget of taps), and Perfect Run (a single mistake fails the attempt). Challenge results live in their own storage and never touch campaign completion, progress sync, or the leaderboard — the two systems are deliberately kept separate.",
      "o4.h": "Progressive Difficulty",
      "o4.p": "30 levels in total: 15 random-generated rectangular boards, 5 fixed figure silhouettes (heart, diamond, club, spade, crown), and 10 multi-layer 3D figures (pyramid, diamond, hourglass, cross, starburst, cat, helix, and more). Difficulty is <em>computed</em> from each level's structure — arrow count, how many start blocked, bends, density and layers — not just read from a static label, and the level list is ordered by that computed score.",
      "o5.h": "Audio System",
      "o5.p": "Sound is driven through an app-lifetime audio manager that keeps a single set of players alive across screens rather than rebuilding them per level. Background music and a pool of sound effects negotiate focus so they duck instead of silencing each other, pause when the app goes to the background, and resume when it returns — a design shaped directly by real-device testing.",
      "o6.h": "Progress &amp; Leaderboards",
      "o6.p": "Progress is local-first: unlocks and best scores are stored on the device so the game is fully playable offline. An optional account adds cloud sync with a merge policy that never discards better local results, plus per-level leaderboards when signed in. The online layer is purely additive — nothing about core play depends on a network connection.",

      "s2.title": "AI Workflow Evolution",
      "s2.lead": "Nodus was built with an AI coding assistant, and the way the team worked <em>with</em> that assistant changed as much as the game did. Every request to the model fills a fixed-size <strong>context window</strong> — the text the model reads before it answers. The story below is about steadily spending less of that window on re-explaining the project, and more of it on producing correct work. It moved through three stages.",
      "problem.label": "Why the project moved on",
      "cost.label": "What it cost",
      "win.label": "Why it stuck",
      "stage1.tag": "Stage 1",
      "stage1.h": "Prompt Engineering",
      "stage1.p": "The earliest phases relied on carefully worded one-off prompts. Each session re-explained the architecture, the constraints, and the history from scratch, all inside the prompt itself.",
      "stage1.cost": "Every session paid the same setup cost again: a large share of each request's input tokens went to re-establishing context that produced no new code, leaving less of the window for the actual task.",
      "stage1.problem": "Context had to be rebuilt in full every time. The prompt grew unwieldy, facts drifted between sessions, and a large share of the window was spent restating things the project already knew before any real work could begin.",
      "stage2.tag": "Stage 2",
      "stage2.h": "Spec-Driven Development",
      "stage2.p": "To fight that drift, work moved to written specifications: structured phase documents that stated exactly what to build, which files were in scope, and which rules applied. The model was pointed at a spec instead of an ad-hoc paragraph.",
      "stage2.cost": "Ambiguity and rework dropped, but every phase document still duplicated the same baseline facts by hand, so per-phase prompt size stayed large even though the back-and-forth did not.",
      "stage2.problem": "Specs cut ambiguity and repeated back-and-forth, but each phase still carried its own bespoke document that duplicated the same baseline facts. The shared knowledge lived nowhere permanent, so every new spec re-imported it by hand.",
      "stage3.tag": "Stage 3 · current",
      "stage3.h": "Harness Engineering",
      "stage3.p": "The project now keeps a standing <code>harness/</code> directory: baseline facts, active constraints, pre- and post-implementation checklists, a phase-prompt template, and a running improvement log. A new phase references this shared, persistent state instead of restating it — only the <em>delta</em> for that phase enters the window.",
      "stage3.cost": "The harness itself has to be kept up to date — a constraint or a decision that changes must be edited once in the harness, or future phases will read a stale fact. That upkeep is paid once per change, not once per phase.",
      "stage3.win": "The baseline is written once and reused everywhere. Each session starts by reading the harness, so facts stay consistent, mistakes are logged and not repeated, and the context window is freed up for actual implementation and review. This is the workflow the project runs on today.",

      "cw.title": "Anatomy of a Context Window",
      "cw.desc": "Every request the model answers is built from a limited budget of tokens. That budget splits into <strong>input</strong> (everything the model must read first) and <strong>output</strong> (what it actually produces). The more input is spent re-establishing context, the less room remains for useful work.",
      "cw.aria": "Diagram of a context window divided into input tokens and output tokens.",
      "cw.input_header": "Input tokens",
      "cw.input_sub": "What the model reads before answering",
      "cw.sys": "System instructions",
      "cw.sys.why": "Fixed cost on every request — the same rules apply regardless of task, so this share can't shrink further.",
      "cw.ctx": "Project context &amp; constraints",
      "cw.ctx.why": "Grows every time facts must be restated — exactly the share the standing <code>harness/</code> directory exists to shrink.",
      "cw.spec": "Phase specification",
      "cw.spec.why": "The actual task-specific ask — the only input block that should scale with the size of the work, not with how many sessions came before it.",
      "cw.output_header": "Output tokens",
      "cw.output_sub": "What the model generates in response",
      "cw.code": "Generated code",
      "cw.code.why": "The direct deliverable — the reason the request was made in the first place.",
      "cw.audit": "Audit reports &amp; tests",
      "cw.audit.why": "Verification evidence that the code is correct — the harness's post-implementation checklist requires it every phase.",
      "cw.note": "The window is finite: input and output compete for the same space. Reducing repeated input is what leaves more room for output.",

      "chart.title": "Comparing the Three Techniques",
      "chart.illustrative": "illustrative",
      "chart.caption": "Each technique scored on three axes: how much of the context window it consumes on repeated setup, how many tokens it costs per phase, and the quality of the results it produced. These scores are illustrative — they show the shape of the improvement across stages, not measured token counts.",
      "chart.aria": "Illustrative grouped bar chart comparing prompt engineering, spec-driven development, and harness engineering across three axes: context-window impact, token usage, and quality of results.",
      "legend.context": "Context-window impact",
      "legend.tokens": "Token usage per phase",
      "legend.quality": "Quality of results",
      "chart.s1": "Prompt\nEngineering",
      "chart.s2": "Spec-Driven\nDevelopment",
      "chart.s3": "Harness\nEngineering",

      "s3.title": "Technical Highlights",
      "s3.lead": "Each choice below was made for a concrete reason — not just what the stack is, but why it earns its place and what it buys the project.",
      "t1.h": "AWS EC2 Hosting",
      "t1.p": "The backend runs on an Amazon EC2 instance, giving the team a real, always-on server with full control over the runtime and network — closer to a production deployment than a managed sandbox, and a chance to practise operating cloud infrastructure directly.",
      "t2.h": "Docker-Based Deployment",
      "t2.p": "The backend ships with a <code>Dockerfile</code> and <code>docker-compose.yml</code>, so the API and its database start with a single command. The same image runs on a laptop and on EC2, which removes \"works on my machine\" drift between development and the server.",
      "t3.h": "Local / Cloud Flexibility",
      "t3.p": "The app is fully playable offline against local level data; the backend is strictly additive. Auth, cloud sync, and leaderboards enhance the experience when present but are never required for it — a deliberate design so a network outage never blocks play.",
      "t4.h": "Flutter + Clean Architecture",
      "t4.p": "One Flutter codebase targets multiple platforms, organised as Domain → Application → Infrastructure → Presentation per feature. Keeping the domain pure (no Flutter, HTTP, or storage imports) means the game rules can be unit-tested in isolation and reused unchanged across 2D and 3D.",
      "t5.h": "Node.js + NestJS + Prisma",
      "t5.p": "The server is a NestJS API on Node.js — its modular, dependency-injected structure mirrors the frontend's layered design — with Prisma as a type-safe ORM and migration layer. Together they give a strongly-typed path from HTTP request to database and back.",
      "t6.h": "Graph-Based Game Engine",
      "t6.p": "No matrix, grid-cell, or tile runtime model exists anywhere. Levels are graphs of nodes and edges, and movement is a coordinate-based sweep resolved entirely in the domain layer. This single abstraction is what lets the same engine drive flat boards, figure silhouettes, and stacked 3D levels.",
      "t7.h": "30 Levels, Tool-Validated",
      "t7.p": "15 random rectangular boards, 5 figure silhouettes, and 10 multi-layer 3D figures. A Node generator/validator checks every level for solvability, connectivity, and shape rules before it ships, so no unsolvable or malformed board can reach a player.",
      "t8.h": "Challenge Modes",
      "t8.p": "Time Attack, Move Limit, and Perfect Run layer over campaign levels through a strategy pattern for scoring, with fully separate save state. Adding a new challenge type means adding one strategy — the core game loop stays untouched.",
      "t9.h": "Backend-Driven Dynamic Levels",
      "t9.p": "On top of the 30 bundled levels, the client can fetch additional real, playable levels straight from the backend (reserved level numbers 1000+) and merge them into the level list at runtime — new content ships by seeding the database, with no app rebuild. The merge stays offline-first: the 30 local levels are always authoritative, a number conflict always keeps the local level, and a failed or absent backend falls back to the last successfully cached remote batch rather than losing previously downloaded content.",

      "s_impl.title": "Technical Implementation",
      "s_impl.lead": "How Nodus is actually put together: what each side of the stack is responsible for, how they relate, which architecture backs each repository, and the cross-cutting concerns applied to the backend.",
      "impl1.h": "Frontend Responsibility",
      "impl1.p": "The Flutter client owns all gameplay: the graph domain, movement resolution, rendering, audio, and local persistence. Each feature is organised Domain &rarr; Application &rarr; Infrastructure &rarr; Presentation, and the domain layer stays pure Dart — no Flutter, HTTP, or storage imports — so the rules that decide whether an arrow escapes or collides can be unit-tested with no UI and no network involved.",
      "impl2.h": "Backend Responsibility",
      "impl2.p": "The NestJS API owns accounts, the level catalog, progress persistence and sync, and leaderboards — organised as <code>src/{domain, application, infrastructure, interfaces}</code>, with Prisma as the ORM and migration layer and Swagger docs served at <code>/api/docs</code>. It never runs gameplay logic; that responsibility stays entirely on the client.",
      "impl3.h": "How Frontend and Backend Relate",
      "impl3.p": "The relationship is strictly additive. Local levels remain the offline source of truth; the client maps them to backend level ids through <code>GET /levels</code>. Progress sync applies a merge policy that never discards a better local result. Leaderboard submission happens only when the player is authenticated, and is best-effort and non-blocking — a failed or absent backend never blocks local play. The same <code>GET /levels</code> call also lets the client download extra, real, playable levels the backend has seeded (reserved numbers 1000+) and merge them in at runtime, offline-first and local-wins, so new content can ship without an app rebuild.",
      "impl4.h": "Architecture Impact",
      "impl4.p": "Both repositories use Clean/hexagonal architecture. Isolating business rules from frameworks means they can be unit-tested without booting a UI or a database, adapters (a Prisma repository, an HTTP client, SharedPreferences) can be swapped behind a port without touching a single use case, and a failure in one adapter — a dropped connection, a slow disk — can't leak into the rules that decide correctness.",
      "impl5.h": "AOP — Three Cross-Cutting Concerns",
      "impl5.p": "The backend separates cross-cutting concerns from business logic using NestJS interceptors, filters, and guards. Two are applied <strong>globally</strong>: a logging &amp; performance interceptor wraps every HTTP handler, recording method/path/status/time with zero controller changes; a global exception filter normalises any thrown error into one consistent JSON response shape. Security is the third concern, and it is applied <strong>per-route</strong>, not globally: a JWT guard validates the bearer token on protected routes (progress, leaderboard submission, admin endpoints), and a roles guard plus a <code>@Roles(ADMIN)</code> decorator additionally restrict the two admin-only level endpoints.",

      "s4.title": "Closing",
      "s4.lead": "Nodus began as a small graph-based puzzle prototype and grew into a full 2D and 3D game with an optional online backend — built alongside a development workflow that matured right beside it, from prompt engineering, to specs, to a proper harness. The result is a project where the game and the way it was made both reflect the same idea: write the rules down once, keep them clean, and reuse them everywhere. Thank you to <strong>Professor Carlos Alonso</strong> for the guidance throughout the course.",
      "link.backend": "Backend Repository",
      "link.frontend": "Frontend Repository",
      "link.lucid": "Lucidchart Diagram",
      "footer.text": "Nodus — Software Development Course Project",
      "footer.top": "Back to top ↑"
    },

    es: {
      "hero.eyebrow": "Proyecto de Desarrollo de Software",
      "hero.tagline": "Un juego de rompecabezas basado en grafos donde cada flecha es rígida y cada salida es deliberada.",
      "nav.overview": "Resumen",
      "nav.workflow": "Flujo de IA",
      "nav.highlights": "Aspectos Técnicos",
      "nav.implementation": "Implementación",
      "nav.closing": "Cierre",
      "lang.aria": "Cambiar idioma a inglés",

      "s1.title": "Resumen del Proyecto",
      "s1.lead": "Nodus es un juego de rompecabezas basado en grafos. Cada nivel es un grafo de nodos y aristas cubierto por flechas rígidas. Al tocar una flecha se intenta una salida completa y atómica en la dirección de su punta — la flecha escapa por completo del tablero o el movimiento se revierte tal como estaba. No hay movimiento parcial, lo que convierte cada nivel en una cuestión de <em>orden</em>: qué flecha puede salir ahora para que las demás también puedan hacerlo después.",
      "o1.h": "Mecánica Basada en Grafos",
      "o1.p": "El tablero nunca es una cuadrícula de casillas. Es un grafo real: nodos unidos por aristas, con flechas rígidas de varios nodos superpuestas. El movimiento se resuelve como un barrido por coordenadas desde la punta de cada flecha — si el camino está libre, toda la flecha se desliza fuera; si está bloqueado, el intento se deshace de forma atómica. Este modelo de grafo es lo que hace posibles tableros planos y por capas con un solo conjunto de reglas.",
      "o2.h": "Modos 2D y 3D",
      "o2.p": "El juego incluye dos modos completos: tableros 2D planos y tableros 3D de varias capas renderizados con una cámara en perspectiva que se puede rotar y acercar. Ambos comparten el mismo resolutor subyacente — la dimensión adicional se maneja con una abstracción de dirección, no con física de casos especiales, así que un nivel 3D es solo un grafo cuyas flechas también pueden viajar entre capas apiladas.",
      "o3.h": "Sistema de Retos",
      "o3.p": "Sobre la campaña, tres tipos de reto reutilizan los niveles existentes con nueva presión: Contrarreloj (un reloj calculado), Límite de Movimientos (un presupuesto acotado de toques) y Ronda Perfecta (un solo error hace fallar el intento). Los resultados de los retos viven en su propio almacenamiento y nunca afectan la finalización de la campaña, la sincronización de progreso ni la tabla de clasificación — los dos sistemas se mantienen separados a propósito.",
      "o4.h": "Dificultad Progresiva",
      "o4.p": "30 niveles en total: 15 tableros rectangulares generados aleatoriamente, 5 siluetas de figuras fijas (corazón, diamante, trébol, pica, corona) y 10 figuras 3D de varias capas (pirámide, diamante, reloj de arena, cruz, estallido, gato, hélice y más). La dificultad se <em>calcula</em> a partir de la estructura de cada nivel — número de flechas, cuántas empiezan bloqueadas, curvas, densidad y capas — no se lee de una etiqueta estática, y la lista de niveles se ordena por esa puntuación calculada.",
      "o5.h": "Sistema de Audio",
      "o5.p": "El sonido se gestiona mediante un administrador de audio de por vida que mantiene un único conjunto de reproductores activo entre pantallas en lugar de reconstruirlos en cada nivel. La música de fondo y un conjunto de efectos negocian el foco para atenuarse en vez de silenciarse mutuamente, se pausan cuando la app pasa a segundo plano y se reanudan al volver — un diseño moldeado directamente por pruebas en dispositivos reales.",
      "o6.h": "Progreso y Clasificaciones",
      "o6.p": "El progreso es local primero: los desbloqueos y las mejores puntuaciones se guardan en el dispositivo, así que el juego es totalmente jugable sin conexión. Una cuenta opcional añade sincronización en la nube con una política de fusión que nunca descarta mejores resultados locales, además de clasificaciones por nivel al iniciar sesión. La capa en línea es puramente adicional — nada del juego principal depende de una conexión de red.",

      "s2.title": "Evolución del Flujo de IA",
      "s2.lead": "Nodus se construyó con un asistente de programación de IA, y la forma en que el equipo trabajó <em>con</em> ese asistente cambió tanto como el propio juego. Cada solicitud al modelo llena una <strong>ventana de contexto</strong> de tamaño fijo — el texto que el modelo lee antes de responder. La historia a continuación trata de gastar cada vez menos de esa ventana en volver a explicar el proyecto, y más en producir trabajo correcto. Pasó por tres etapas.",
      "problem.label": "Por qué el proyecto avanzó",
      "cost.label": "Qué costó",
      "win.label": "Por qué perduró",
      "stage1.tag": "Etapa 1",
      "stage1.h": "Ingeniería de Prompts",
      "stage1.p": "Las primeras fases dependían de prompts únicos redactados con cuidado. Cada sesión volvía a explicar desde cero la arquitectura, las restricciones y el historial, todo dentro del propio prompt.",
      "stage1.cost": "Cada sesión pagaba de nuevo el mismo costo de preparación: una gran parte de los tokens de entrada de cada solicitud se gastaba en restablecer contexto que no producía código nuevo, dejando menos ventana disponible para la tarea real.",
      "stage1.problem": "El contexto había que reconstruirlo por completo cada vez. El prompt se volvía inmanejable, los datos variaban entre sesiones y una gran parte de la ventana se gastaba en repetir cosas que el proyecto ya conocía antes de poder empezar el trabajo real.",
      "stage2.tag": "Etapa 2",
      "stage2.h": "Desarrollo Guiado por Especificaciones",
      "stage2.p": "Para combatir esa deriva, el trabajo pasó a especificaciones escritas: documentos de fase estructurados que indicaban exactamente qué construir, qué archivos estaban en alcance y qué reglas aplicaban. Al modelo se le dirigía a una especificación en vez de a un párrafo improvisado.",
      "stage2.cost": "La ambigüedad y el retrabajo bajaron, pero cada documento de fase seguía duplicando a mano los mismos datos de base, así que el tamaño del prompt por fase se mantenía grande aunque el ir y venir ya no lo estuviera.",
      "stage2.problem": "Las especificaciones redujeron la ambigüedad y el ir y venir repetido, pero cada fase seguía llevando su propio documento a medida que duplicaba los mismos datos de base. El conocimiento compartido no vivía en ningún lugar permanente, así que cada nueva especificación lo reimportaba a mano.",
      "stage3.tag": "Etapa 3 · actual",
      "stage3.h": "Ingeniería de Harness",
      "stage3.p": "El proyecto ahora mantiene un directorio <code>harness/</code> permanente: datos de base, restricciones activas, listas de verificación previas y posteriores a la implementación, una plantilla de prompt de fase y un registro continuo de mejoras. Una fase nueva referencia este estado compartido y persistente en vez de repetirlo — solo el <em>delta</em> de esa fase entra en la ventana.",
      "stage3.cost": "El propio harness debe mantenerse actualizado — una restricción o decisión que cambia debe editarse una sola vez en el harness, o las fases futuras leerán un dato desactualizado. Ese mantenimiento se paga una vez por cambio, no una vez por fase.",
      "stage3.win": "La base se escribe una vez y se reutiliza en todas partes. Cada sesión empieza leyendo el harness, así que los datos se mantienen consistentes, los errores se registran y no se repiten, y la ventana de contexto queda libre para la implementación y la revisión reales. Este es el flujo de trabajo con el que funciona el proyecto hoy.",

      "cw.title": "Anatomía de una Ventana de Contexto",
      "cw.desc": "Cada respuesta del modelo se construye a partir de un presupuesto limitado de tokens. Ese presupuesto se divide en <strong>entrada</strong> (todo lo que el modelo debe leer primero) y <strong>salida</strong> (lo que realmente produce). Cuanta más entrada se gasta en reestablecer el contexto, menos espacio queda para el trabajo útil.",
      "cw.aria": "Diagrama de una ventana de contexto dividida en tokens de entrada y tokens de salida.",
      "cw.input_header": "Tokens de entrada",
      "cw.input_sub": "Lo que el modelo lee antes de responder",
      "cw.sys": "Instrucciones del sistema",
      "cw.sys.why": "Costo fijo en cada solicitud — las mismas reglas aplican sin importar la tarea, así que esta parte no puede reducirse más.",
      "cw.ctx": "Contexto y restricciones del proyecto",
      "cw.ctx.why": "Crece cada vez que hay que repetir datos — exactamente la parte que el directorio <code>harness/</code> permanente existe para reducir.",
      "cw.spec": "Especificación de la fase",
      "cw.spec.why": "El encargo específico de la tarea — la única parte de la entrada que debería escalar con el tamaño del trabajo, no con cuántas sesiones hubo antes.",
      "cw.output_header": "Tokens de salida",
      "cw.output_sub": "Lo que el modelo genera en respuesta",
      "cw.code": "Código generado",
      "cw.code.why": "El entregable directo — la razón por la que se hizo la solicitud.",
      "cw.audit": "Informes de auditoría y pruebas",
      "cw.audit.why": "Evidencia de verificación de que el código es correcto — la lista de verificación posterior a la implementación del harness lo exige en cada fase.",
      "cw.note": "La ventana es finita: la entrada y la salida compiten por el mismo espacio. Reducir la entrada repetida es lo que deja más lugar para la salida.",

      "chart.title": "Comparación entre las Tres Técnicas",
      "chart.illustrative": "ilustrativo",
      "chart.caption": "Cada técnica puntuada en tres ejes: cuánto de la ventana de contexto consume en preparación repetida, cuántos tokens cuesta por fase y la calidad de los resultados que produjo. Estas puntuaciones son ilustrativas — muestran la forma de la mejora entre etapas, no recuentos de tokens medidos.",
      "chart.aria": "Gráfico ilustrativo de barras agrupadas que compara la ingeniería de prompts, el desarrollo guiado por especificaciones y la ingeniería de harness en tres ejes: impacto en la ventana de contexto, uso de tokens y calidad de los resultados.",
      "legend.context": "Impacto en la ventana de contexto",
      "legend.tokens": "Uso de tokens por fase",
      "legend.quality": "Calidad de los resultados",
      "chart.s1": "Ingeniería\nde Prompts",
      "chart.s2": "Guiado por\nEspecificaciones",
      "chart.s3": "Ingeniería\nde Harness",

      "s3.title": "Aspectos Técnicos",
      "s3.lead": "Cada elección a continuación se tomó por una razón concreta — no solo qué es la tecnología, sino por qué se gana su lugar y qué le aporta al proyecto.",
      "t1.h": "Alojamiento en AWS EC2",
      "t1.p": "El backend se ejecuta en una instancia de Amazon EC2, dando al equipo un servidor real y siempre activo con control total sobre el entorno de ejecución y la red — más cercano a un despliegue de producción que a un entorno gestionado, y una oportunidad para practicar la operación de infraestructura en la nube directamente.",
      "t2.h": "Despliegue con Docker",
      "t2.p": "El backend incluye un <code>Dockerfile</code> y un <code>docker-compose.yml</code>, así que la API y su base de datos arrancan con un solo comando. La misma imagen corre en una laptop y en EC2, lo que elimina la deriva de \"funciona en mi máquina\" entre el desarrollo y el servidor.",
      "t3.h": "Flexibilidad Local / Nube",
      "t3.p": "La app es totalmente jugable sin conexión con datos de niveles locales; el backend es estrictamente adicional. La autenticación, la sincronización en la nube y las clasificaciones enriquecen la experiencia cuando están presentes, pero nunca son necesarias — un diseño deliberado para que una caída de red nunca bloquee el juego.",
      "t4.h": "Flutter + Arquitectura Limpia",
      "t4.p": "Una sola base de código Flutter apunta a varias plataformas, organizada como Dominio → Aplicación → Infraestructura → Presentación por funcionalidad. Mantener el dominio puro (sin imports de Flutter, HTTP ni almacenamiento) permite probar las reglas del juego de forma aislada y reutilizarlas sin cambios entre 2D y 3D.",
      "t5.h": "Node.js + NestJS + Prisma",
      "t5.p": "El servidor es una API NestJS sobre Node.js — su estructura modular con inyección de dependencias refleja el diseño en capas del frontend — con Prisma como ORM y capa de migraciones con tipado seguro. Juntos ofrecen un camino fuertemente tipado desde la petición HTTP hasta la base de datos y de vuelta.",
      "t6.h": "Motor de Juego Basado en Grafos",
      "t6.p": "No existe ningún modelo de ejecución de matriz, celda de cuadrícula ni casilla en ninguna parte. Los niveles son grafos de nodos y aristas, y el movimiento es un barrido por coordenadas resuelto por completo en la capa de dominio. Esta única abstracción es lo que permite que el mismo motor impulse tableros planos, siluetas de figuras y niveles 3D apilados.",
      "t7.h": "30 Niveles, Validados por Herramienta",
      "t7.p": "15 tableros rectangulares aleatorios, 5 siluetas de figuras y 10 figuras 3D de varias capas. Un generador/validador en Node revisa cada nivel en cuanto a resolubilidad, conectividad y reglas de forma antes de publicarlo, de modo que ningún tablero irresoluble o mal formado pueda llegar a un jugador.",
      "t8.h": "Modos de Reto",
      "t8.p": "Contrarreloj, Límite de Movimientos y Ronda Perfecta se superponen a los niveles de campaña mediante un patrón de estrategia para la puntuación, con estado de guardado totalmente separado. Añadir un nuevo tipo de reto significa añadir una estrategia — el bucle principal del juego queda intacto.",
      "t9.h": "Niveles Dinámicos desde el Backend",
      "t9.p": "Además de los 30 niveles incluidos, el cliente puede descargar niveles adicionales reales y jugables directamente desde el backend (números de nivel reservados 1000+) y fusionarlos en la lista de niveles en tiempo de ejecución — el contenido nuevo se publica sembrando la base de datos, sin necesidad de recompilar la app. La fusión sigue siendo offline-first: los 30 niveles locales son siempre la autoridad, un conflicto de número siempre conserva el nivel local, y un backend caído o ausente recurre al último lote remoto descargado con éxito en vez de perder contenido ya descargado.",

      "s_impl.title": "Implementación Técnica",
      "s_impl.lead": "Cómo está armado Nodus en la práctica: de qué es responsable cada lado del stack, cómo se relacionan, qué arquitectura respalda a cada repositorio y qué concerns transversales se aplican en el backend.",
      "impl1.h": "Responsabilidad del Frontend",
      "impl1.p": "El cliente Flutter posee todo el juego: el dominio del grafo, la resolución de movimiento, el renderizado, el audio y la persistencia local. Cada funcionalidad se organiza como Dominio &rarr; Aplicación &rarr; Infraestructura &rarr; Presentación, y la capa de dominio se mantiene en Dart puro — sin imports de Flutter, HTTP ni almacenamiento — de modo que las reglas que deciden si una flecha escapa o choca pueden probarse de forma aislada, sin interfaz ni red.",
      "impl2.h": "Responsabilidad del Backend",
      "impl2.p": "La API NestJS posee las cuentas, el catálogo de niveles, la persistencia y sincronización del progreso, y las clasificaciones — organizada como <code>src/{domain, application, infrastructure, interfaces}</code>, con Prisma como ORM y capa de migraciones, y documentación Swagger servida en <code>/api/docs</code>. Nunca ejecuta lógica de juego; esa responsabilidad queda completamente del lado del cliente.",
      "impl3.h": "Cómo se Relacionan Frontend y Backend",
      "impl3.p": "La relación es estrictamente aditiva. Los niveles locales siguen siendo la fuente de verdad sin conexión; el cliente los mapea a los ids de nivel del backend mediante <code>GET /levels</code>. La sincronización de progreso aplica una política de fusión que nunca descarta un mejor resultado local. El envío a la tabla de clasificación solo ocurre cuando el jugador está autenticado, y es best-effort y no bloqueante — un backend caído o ausente nunca bloquea el juego local. La misma llamada a <code>GET /levels</code> también permite al cliente descargar niveles adicionales reales y jugables que el backend ha sembrado (números reservados 1000+) y fusionarlos en tiempo de ejecución, offline-first y con prioridad local, para que el contenido nuevo pueda publicarse sin recompilar la app.",
      "impl4.h": "Impacto de la Arquitectura",
      "impl4.p": "Ambos repositorios usan arquitectura limpia/hexagonal. Aislar las reglas de negocio de los frameworks permite probarlas sin levantar una interfaz o una base de datos, los adaptadores (un repositorio Prisma, un cliente HTTP, SharedPreferences) pueden sustituirse detrás de un puerto sin tocar un solo caso de uso, y un fallo en un adaptador — una conexión caída, un disco lento — no puede filtrarse a las reglas que deciden la corrección.",
      "impl5.h": "AOP — Tres Concerns Transversales",
      "impl5.p": "El backend separa los concerns transversales de la lógica de negocio usando interceptores, filtros y guards de NestJS. Dos se aplican <strong>globalmente</strong>: un interceptor de registro y rendimiento envuelve cada manejador HTTP, registrando método/ruta/estado/tiempo sin cambios en los controladores; un filtro de excepciones global normaliza cualquier error lanzado en una única forma de respuesta JSON consistente. La seguridad es el tercer concern, y se aplica <strong>por ruta</strong>, no globalmente: un guard JWT valida el token portador en rutas protegidas (progreso, envío a la tabla de clasificación, endpoints de administrador), y un guard de roles junto con un decorador <code>@Roles(ADMIN)</code> restringen además los dos endpoints de nivel exclusivos para administradores.",

      "s4.title": "Cierre",
      "s4.lead": "Nodus empezó como un pequeño prototipo de rompecabezas basado en grafos y creció hasta convertirse en un juego completo 2D y 3D con un backend en línea opcional — construido junto a un flujo de desarrollo que maduró a su lado, desde la ingeniería de prompts, a las especificaciones, hasta un harness propiamente dicho. El resultado es un proyecto donde el juego y la forma en que se hizo reflejan la misma idea: escribe las reglas una vez, mantenlas limpias y reutilízalas en todas partes. Gracias <strong>Profesor Carlos Alonso</strong> por la guía a lo largo del curso.",
      "link.backend": "Repositorio del Backend",
      "link.frontend": "Repositorio del Frontend",
      "link.lucid": "Diagrama de Lucidchart",
      "footer.text": "Nodus — Proyecto del Curso de Desarrollo de Software",
      "footer.top": "Volver arriba ↑"
    }
  };

  var STORAGE_KEY = "nodus-lang";
  var currentLang = "en";

  function safeGet(key) {
    try {
      return window.localStorage.getItem(key);
    } catch (e) {
      return null;
    }
  }

  function safeSet(key, value) {
    try {
      window.localStorage.setItem(key, value);
    } catch (e) {
      /* localStorage unavailable (private mode / file restrictions) — ignore */
    }
  }

  function applyLanguage(lang) {
    var dict = translations[lang] || translations.en;
    currentLang = lang;
    document.documentElement.lang = lang;

    document.querySelectorAll("[data-i18n]").forEach(function (el) {
      var key = el.getAttribute("data-i18n");
      if (dict[key] !== undefined) {
        el.innerHTML = dict[key];
      }
    });

    document.querySelectorAll("[data-i18n-aria]").forEach(function (el) {
      var key = el.getAttribute("data-i18n-aria");
      if (dict[key] !== undefined) {
        el.setAttribute("aria-label", dict[key]);
      }
    });

    var toggleLabel = document.getElementById("langToggleLabel");
    if (toggleLabel) {
      // Show the language you can switch TO.
      toggleLabel.textContent = lang === "en" ? "ES" : "EN";
    }

    safeSet(STORAGE_KEY, lang);
    drawChart();
  }

  // --- Language toggle wiring ---
  var langToggle = document.getElementById("langToggle");
  if (langToggle) {
    langToggle.addEventListener("click", function () {
      applyLanguage(currentLang === "en" ? "es" : "en");
    });
  }

  // --- Smooth scroll for in-page nav links ---
  document.querySelectorAll('a[href^="#"]').forEach(function (link) {
    link.addEventListener("click", function (e) {
      var targetId = link.getAttribute("href").slice(1);
      var target = document.getElementById(targetId);
      if (target) {
        e.preventDefault();
        target.scrollIntoView({ behavior: "smooth", block: "start" });
      }
    });
  });

  // --- Section reveal on scroll ---
  var revealTargets = document.querySelectorAll(
    ".overview-card, .stage-card, .tech-card, .link-card, .visual-block"
  );
  revealTargets.forEach(function (el) {
    el.classList.add("reveal");
  });

  if ("IntersectionObserver" in window) {
    var observer = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) {
            entry.target.classList.add("is-visible");
            observer.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.15 }
    );
    revealTargets.forEach(function (el) {
      observer.observe(el);
    });
  } else {
    revealTargets.forEach(function (el) {
      el.classList.add("is-visible");
    });
  }

  /* ------------------------------------------------------------------ *
   * Technique comparison chart (Canvas). Illustrative scores per stage *
   * across three axes: context-window impact, token usage, and        *
   * quality of results. Separate from the context-window anatomy      *
   * diagram above — this chart compares the three techniques, not the *
   * composition of a single request.                                  *
   * ------------------------------------------------------------------ */
  var canvas = document.getElementById("workflowCanvas");
  var ctx = canvas && canvas.getContext ? canvas.getContext("2d") : null;

  // Illustrative only — not measured token counts. Higher = more impact/
  // cost for context/tokens; higher = better for quality.
  var stages = [
    { key: "chart.s1", context: 85, tokens: 80, quality: 55 },
    { key: "chart.s2", context: 60, tokens: 65, quality: 75 },
    { key: "chart.s3", context: 25, tokens: 35, quality: 92 }
  ];

  function cssVar(name, fallback) {
    var v = getComputedStyle(document.documentElement).getPropertyValue(name).trim();
    return v || fallback;
  }

  function drawChart() {
    if (!ctx) {
      return;
    }
    var dict = translations[currentLang] || translations.en;

    var dpr = window.devicePixelRatio || 1;
    var cssWidth = canvas.clientWidth || 900;
    var cssHeight = 420;
    canvas.width = cssWidth * dpr;
    canvas.height = cssHeight * dpr;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, cssWidth, cssHeight);

    var textColor = cssVar("--text", "#eef0f6");
    var mutedColor = cssVar("--text-muted", "#a6acc2");
    var contextColor = cssVar("--accent", "#6d8dff");
    var tokensColor = cssVar("--accent-warm", "#ffb26b");
    var qualityColor = cssVar("--accent-2", "#7ee8c8");
    var metrics = [
      { key: "context", color: contextColor },
      { key: "tokens", color: tokensColor },
      { key: "quality", color: qualityColor }
    ];

    var padL = 52;
    var padR = 32;
    var padT = 28;
    var padB = 78;
    var chartW = cssWidth - padL - padR;
    var chartH = cssHeight - padT - padB;
    var baseY = padT + chartH;
    var groupW = chartW / stages.length;
    var barGap = 6;
    var barW = Math.min(64, (groupW * 0.7 - barGap * (metrics.length - 1)) / metrics.length);

    // Gridlines + percentage axis
    ctx.font = "11px -apple-system, Segoe UI, Roboto, sans-serif";
    ctx.textAlign = "right";
    [0, 25, 50, 75, 100].forEach(function (pct) {
      var y = baseY - (pct / 100) * chartH;
      ctx.globalAlpha = 0.14;
      ctx.strokeStyle = mutedColor;
      ctx.beginPath();
      ctx.moveTo(padL, y);
      ctx.lineTo(padL + chartW, y);
      ctx.stroke();
      ctx.globalAlpha = 1;
      ctx.fillStyle = mutedColor;
      ctx.fillText(pct, padL - 8, y + 4);
    });

    stages.forEach(function (stage, i) {
      var groupX = padL + i * groupW + groupW / 2;
      var groupWidth = metrics.length * barW + (metrics.length - 1) * barGap;
      var startX = groupX - groupWidth / 2;

      metrics.forEach(function (metric, mi) {
        var value = stage[metric.key];
        var barH = (value / 100) * chartH;
        var barX = startX + mi * (barW + barGap);
        var barY = baseY - barH;

        ctx.fillStyle = metric.color;
        ctx.fillRect(barX, barY, barW, barH);

        ctx.textAlign = "center";
        ctx.fillStyle = textColor;
        ctx.font = "bold 11px -apple-system, Segoe UI, Roboto, sans-serif";
        ctx.fillText(value, barX + barW / 2, barY - 6);
      });

      // Stage name (supports \n)
      ctx.fillStyle = textColor;
      ctx.font = "13px -apple-system, Segoe UI, Roboto, sans-serif";
      var label = (dict[stage.key] || "").split("\n");
      label.forEach(function (line, li) {
        ctx.fillText(line, groupX, baseY + 22 + li * 15);
      });
    });

    ctx.textAlign = "left";
  }

  // --- Initial language + first draw ---
  var stored = safeGet(STORAGE_KEY);
  applyLanguage(stored === "es" || stored === "en" ? stored : "en");

  // --- Redraw chart on resize / theme change ---
  var resizeTimer;
  window.addEventListener("resize", function () {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(drawChart, 120);
  });

  if (window.matchMedia) {
    var scheme = window.matchMedia("(prefers-color-scheme: dark)");
    if (scheme.addEventListener) {
      scheme.addEventListener("change", drawChart);
    }
  }
})();
