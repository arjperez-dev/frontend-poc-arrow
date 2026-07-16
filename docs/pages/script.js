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
      "nav.closing": "Closing",
      "lang.aria": "Switch language to Spanish",

      "s1.title": "Project Overview",
      "s1.lead": "Nodus is a graph-based puzzle game built. Each level is a graph of nodes and edges covered by rigid arrows. Tapping an arrow attempts a single, atomic full exit in its head direction — the arrow either escapes the board entirely, or the move is rolled back exactly as it was. There is no partial movement, which turns every level into a question of <em>order</em>: which arrow can leave now so that the others eventually can too.",
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
      "problem.label": "The problem",
      "win.label": "Why it stuck",
      "stage1.tag": "Stage 1",
      "stage1.h": "Prompt Engineering",
      "stage1.p": "The earliest phases relied on carefully worded one-off prompts. Each session re-explained the architecture, the constraints, and the history from scratch, all inside the prompt itself.",
      "stage1.problem": "Context had to be rebuilt in full every time. The prompt grew unwieldy, facts drifted between sessions, and a large share of the window was spent restating things the project already knew before any real work could begin.",
      "stage2.tag": "Stage 2",
      "stage2.h": "Spec-Driven Development",
      "stage2.p": "To fight that drift, work moved to written specifications: structured phase documents that stated exactly what to build, which files were in scope, and which rules applied. The model was pointed at a spec instead of an ad-hoc paragraph.",
      "stage2.problem": "Specs cut ambiguity and repeated back-and-forth, but each phase still carried its own bespoke document that duplicated the same baseline facts. The shared knowledge lived nowhere permanent, so every new spec re-imported it by hand.",
      "stage3.tag": "Stage 3 · current",
      "stage3.h": "Harness Engineering",
      "stage3.p": "The project now keeps a standing <code>harness/</code> directory: baseline facts, active constraints, pre- and post-implementation checklists, a phase-prompt template, and a running improvement log. A new phase references this shared, persistent state instead of restating it — only the <em>delta</em> for that phase enters the window.",
      "stage3.win": "The baseline is written once and reused everywhere. Each session starts by reading the harness, so facts stay consistent, mistakes are logged and not repeated, and the context window is freed up for actual implementation and review. This is the workflow the project runs on today.",

      "cw.title": "Anatomy of a Context Window",
      "cw.desc": "Every request the model answers is built from a limited budget of tokens. That budget splits into <strong>input</strong> (everything the model must read first) and <strong>output</strong> (what it actually produces). The more input is spent re-establishing context, the less room remains for useful work.",
      "cw.aria": "Diagram of a context window divided into input tokens and output tokens.",
      "cw.input_header": "Input tokens",
      "cw.input_sub": "What the model reads before answering",
      "cw.sys": "System instructions",
      "cw.ctx": "Project context &amp; constraints",
      "cw.spec": "Phase specification",
      "cw.output_header": "Output tokens",
      "cw.output_sub": "What the model generates in response",
      "cw.code": "Generated code",
      "cw.audit": "Audit reports &amp; tests",
      "cw.note": "The window is finite: input and output compete for the same space. Reducing repeated input is what leaves more room for output.",

      "chart.title": "Efficiency Across the Three Techniques",
      "chart.illustrative": "illustrative",
      "chart.caption": "Reading left to right, each technique spends a smaller share of the window on repeated setup (blue) and a larger share on real output (mint). The dashed line traces the shrinking setup overhead. These proportions are illustrative — they show the shape of the improvement, not measured token counts.",
      "chart.aria": "Illustrative chart showing input versus output token composition across the three AI workflow stages, with a downward trend in repeated setup overhead from prompt engineering to harness engineering.",
      "legend.input": "Input tokens — repeated setup / context",
      "legend.output": "Output tokens — actual work",
      "legend.line": "Setup overhead (falling)",
      "chart.s1": "Prompt\nEngineering",
      "chart.s2": "Spec-Driven\nDevelopment",
      "chart.s3": "Harness\nEngineering",
      "chart.input_label": "setup",
      "chart.output_label": "output",

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

      "s4.title": "Closing",
      "s4.lead": "Nodus began as a small graph-based puzzle prototype and grew into a full 2D and 3D game with an optional online backend — built alongside a development workflow that matured right beside it, from prompt engineering, to specs, to a proper harness. The result is a project where the game and the way it was made both reflect the same idea: write the rules down once, keep them clean, and reuse them everywhere. Thank you to <strong>Professor Carlos Alonso</strong> for the guidance throughout this capstone project.",
      "link.backend": "Backend Repository",
      "link.frontend": "Frontend Repository",
      "link.lucid": "Lucidchart Diagram",
      "footer.text": "Nodus — University Capstone Project",
      "footer.top": "Back to top ↑"
    },

    es: {
      "hero.eyebrow": "Proyecto de Desarrollo de Software",
      "hero.tagline": "Un juego de rompecabezas basado en grafos donde cada flecha es rígida y cada salida es deliberada.",
      "nav.overview": "Resumen",
      "nav.workflow": "Flujo de IA",
      "nav.highlights": "Aspectos Técnicos",
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
      "problem.label": "El problema",
      "win.label": "Por qué perduró",
      "stage1.tag": "Etapa 1",
      "stage1.h": "Ingeniería de Prompts",
      "stage1.p": "Las primeras fases dependían de prompts únicos redactados con cuidado. Cada sesión volvía a explicar desde cero la arquitectura, las restricciones y el historial, todo dentro del propio prompt.",
      "stage1.problem": "El contexto había que reconstruirlo por completo cada vez. El prompt se volvía inmanejable, los datos variaban entre sesiones y una gran parte de la ventana se gastaba en repetir cosas que el proyecto ya conocía antes de poder empezar el trabajo real.",
      "stage2.tag": "Etapa 2",
      "stage2.h": "Desarrollo Guiado por Especificaciones",
      "stage2.p": "Para combatir esa deriva, el trabajo pasó a especificaciones escritas: documentos de fase estructurados que indicaban exactamente qué construir, qué archivos estaban en alcance y qué reglas aplicaban. Al modelo se le dirigía a una especificación en vez de a un párrafo improvisado.",
      "stage2.problem": "Las especificaciones redujeron la ambigüedad y el ir y venir repetido, pero cada fase seguía llevando su propio documento a medida que duplicaba los mismos datos de base. El conocimiento compartido no vivía en ningún lugar permanente, así que cada nueva especificación lo reimportaba a mano.",
      "stage3.tag": "Etapa 3 · actual",
      "stage3.h": "Ingeniería de Harness",
      "stage3.p": "El proyecto ahora mantiene un directorio <code>harness/</code> permanente: datos de base, restricciones activas, listas de verificación previas y posteriores a la implementación, una plantilla de prompt de fase y un registro continuo de mejoras. Una fase nueva referencia este estado compartido y persistente en vez de repetirlo — solo el <em>delta</em> de esa fase entra en la ventana.",
      "stage3.win": "La base se escribe una vez y se reutiliza en todas partes. Cada sesión empieza leyendo el harness, así que los datos se mantienen consistentes, los errores se registran y no se repiten, y la ventana de contexto queda libre para la implementación y la revisión reales. Este es el flujo de trabajo con el que funciona el proyecto hoy.",

      "cw.title": "Anatomía de una Ventana de Contexto",
      "cw.desc": "Cada respuesta del modelo se construye a partir de un presupuesto limitado de tokens. Ese presupuesto se divide en <strong>entrada</strong> (todo lo que el modelo debe leer primero) y <strong>salida</strong> (lo que realmente produce). Cuanta más entrada se gasta en reestablecer el contexto, menos espacio queda para el trabajo útil.",
      "cw.aria": "Diagrama de una ventana de contexto dividida en tokens de entrada y tokens de salida.",
      "cw.input_header": "Tokens de entrada",
      "cw.input_sub": "Lo que el modelo lee antes de responder",
      "cw.sys": "Instrucciones del sistema",
      "cw.ctx": "Contexto y restricciones del proyecto",
      "cw.spec": "Especificación de la fase",
      "cw.output_header": "Tokens de salida",
      "cw.output_sub": "Lo que el modelo genera en respuesta",
      "cw.code": "Código generado",
      "cw.audit": "Informes de auditoría y pruebas",
      "cw.note": "La ventana es finita: la entrada y la salida compiten por el mismo espacio. Reducir la entrada repetida es lo que deja más lugar para la salida.",

      "chart.title": "Eficiencia entre las Tres Técnicas",
      "chart.illustrative": "ilustrativo",
      "chart.caption": "De izquierda a derecha, cada técnica gasta una parte menor de la ventana en la preparación repetida (azul) y una parte mayor en la salida real (menta). La línea discontinua traza la caída de la sobrecarga de preparación. Estas proporciones son ilustrativas — muestran la forma de la mejora, no recuentos de tokens medidos.",
      "chart.aria": "Gráfico ilustrativo que muestra la composición de tokens de entrada frente a salida a lo largo de las tres etapas del flujo de IA, con una tendencia decreciente en la sobrecarga de preparación repetida desde la ingeniería de prompts hasta la ingeniería de harness.",
      "legend.input": "Tokens de entrada — preparación / contexto repetido",
      "legend.output": "Tokens de salida — trabajo real",
      "legend.line": "Sobrecarga de preparación (en descenso)",
      "chart.s1": "Ingeniería\nde Prompts",
      "chart.s2": "Guiado por\nEspecificaciones",
      "chart.s3": "Ingeniería\nde Harness",
      "chart.input_label": "preparación",
      "chart.output_label": "salida",

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

      "s4.title": "Cierre",
      "s4.lead": "Nodus empezó como un pequeño prototipo de rompecabezas basado en grafos y creció hasta convertirse en un juego completo 2D y 3D con un backend en línea opcional — construido junto a un flujo de desarrollo que maduró a su lado, desde la ingeniería de prompts, a las especificaciones, hasta un harness propiamente dicho. El resultado es un proyecto donde el juego y la forma en que se hizo reflejan la misma idea: escribe las reglas una vez, mantenlas limpias y reutilízalas en todas partes. Gracias <strong>Profesor Carlos Alonso</strong> por la guía a lo largo de este semestre.",
      "link.backend": "Repositorio del Backend",
      "link.frontend": "Repositorio del Frontend",
      "link.lucid": "Diagrama de Lucidchart",
      "footer.text": "Nodus — Proyecto de Grado Universitario",
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
   * Efficiency chart (Canvas). Illustrative composition per stage:     *
   * input (repeated setup) shrinks, output (real work) grows.          *
   * A dashed line traces the falling setup overhead across stages.     *
   * ------------------------------------------------------------------ */
  var canvas = document.getElementById("workflowCanvas");
  var ctx = canvas && canvas.getContext ? canvas.getContext("2d") : null;

  // Illustrative only — not measured token counts.
  var stages = [
    { key: "chart.s1", input: 78, output: 22 },
    { key: "chart.s2", input: 55, output: 45 },
    { key: "chart.s3", input: 32, output: 68 }
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
    var cssHeight = 400;
    canvas.width = cssWidth * dpr;
    canvas.height = cssHeight * dpr;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, cssWidth, cssHeight);

    var textColor = cssVar("--text", "#eef0f6");
    var mutedColor = cssVar("--text-muted", "#a6acc2");
    var inputColor = cssVar("--accent", "#6d8dff");
    var outputColor = cssVar("--accent-2", "#7ee8c8");
    var lineColor = cssVar("--accent-warm", "#ffb26b");

    var padL = 52;
    var padR = 32;
    var padT = 28;
    var padB = 78;
    var chartW = cssWidth - padL - padR;
    var chartH = cssHeight - padT - padB;
    var baseY = padT + chartH;
    var groupW = chartW / stages.length;
    var barW = Math.min(96, groupW * 0.44);

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
      ctx.fillText(pct + "%", padL - 8, y + 4);
    });

    var boundaryPoints = [];

    stages.forEach(function (stage, i) {
      var groupX = padL + i * groupW + groupW / 2;
      var barX = groupX - barW / 2;

      var inputH = (stage.input / 100) * chartH;
      var outputH = (stage.output / 100) * chartH;

      // Input segment (bottom)
      var inputY = baseY - inputH;
      ctx.fillStyle = inputColor;
      ctx.fillRect(barX, inputY, barW, inputH);

      // Output segment (top)
      var outputY = inputY - outputH;
      ctx.fillStyle = outputColor;
      ctx.fillRect(barX, outputY, barW, outputH);

      boundaryPoints.push({ x: groupX, y: inputY });

      // Segment value labels
      ctx.textAlign = "center";
      ctx.fillStyle = "#0f1117";
      ctx.font = "bold 13px -apple-system, Segoe UI, Roboto, sans-serif";
      ctx.fillText(stage.input + "%", groupX, inputY + inputH / 2 + 4);
      ctx.fillText(stage.output + "%", groupX, outputY + outputH / 2 + 4);

      // Stage name (supports \n)
      ctx.fillStyle = textColor;
      ctx.font = "13px -apple-system, Segoe UI, Roboto, sans-serif";
      var label = (dict[stage.key] || "").split("\n");
      label.forEach(function (line, li) {
        ctx.fillText(line, groupX, baseY + 22 + li * 15);
      });
    });

    // Dashed trend line over the input/output boundary (falling overhead)
    ctx.strokeStyle = lineColor;
    ctx.lineWidth = 2;
    ctx.setLineDash([6, 5]);
    ctx.beginPath();
    boundaryPoints.forEach(function (pt, i) {
      if (i === 0) {
        ctx.moveTo(pt.x, pt.y);
      } else {
        ctx.lineTo(pt.x, pt.y);
      }
    });
    ctx.stroke();
    ctx.setLineDash([]);

    // Trend markers
    boundaryPoints.forEach(function (pt) {
      ctx.fillStyle = lineColor;
      ctx.beginPath();
      ctx.arc(pt.x, pt.y, 4, 0, Math.PI * 2);
      ctx.fill();
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
