// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Nodus';

  @override
  String get play => 'Jugar';

  @override
  String get settings => 'Configuracion';

  @override
  String get levels => 'Niveles';

  @override
  String get gameMode => 'Modo de juego';

  @override
  String get challenges => 'Retos';

  @override
  String get gameMode2D => '2D';

  @override
  String get gameMode3D => '3D';

  @override
  String get gameModeHint => 'Elige que conjunto de niveles abre el menu.';

  @override
  String get gamePlaceholder => 'Pantalla de juego provisional';

  @override
  String get backendUrlLabel => 'URL del backend';

  @override
  String get homeSubtitle => 'Desenreda el nudo. Una salida a la vez.';

  @override
  String get levelSelectionPlaceholder => 'Seleccion de niveles provisional';

  @override
  String get settingsPlaceholder => 'Configuracion provisional';

  @override
  String get openGame => 'Abrir juego';

  @override
  String get moves => 'Movimientos';

  @override
  String get score => 'Puntaje';

  @override
  String get victory => 'Victoria';

  @override
  String get retry => 'Reintentar';

  @override
  String get nextLevel => 'Siguiente nivel';

  @override
  String get backToLevels => 'Volver a niveles';

  @override
  String get levelNotFound => 'Nivel no encontrado';

  @override
  String get loadingLevel => 'Cargando nivel';

  @override
  String get locked => 'Bloqueado';

  @override
  String get completed => 'Completado';

  @override
  String get unlocked => 'Desbloqueado';

  @override
  String get bestScore => 'Mejor puntaje';

  @override
  String get levelLocked =>
      'Completa los niveles anteriores para desbloquear este nivel.';

  @override
  String get soundEnabled => 'Efectos de sonido';

  @override
  String get musicEnabled => 'Musica';

  @override
  String get soundFoundationDescription => ' ';

  @override
  String get musicFutureDescription => ' ';

  @override
  String get language => 'Idioma';

  @override
  String get languageDisplayValue => 'Espanol';

  @override
  String get languageSystemOption => 'Predeterminado del sistema';

  @override
  String get resetProgress => 'Reiniciar progreso local';

  @override
  String get resetProgressConfirmation =>
      'Esto borra niveles completados, mejores puntajes y desbloqueos. La configuracion no cambia.';

  @override
  String get progressReset => 'Progreso local reiniciado.';

  @override
  String get resetRemoteProgress => 'Reiniciar progreso remoto';

  @override
  String get resetRemoteProgressConfirmation =>
      'Esto borra tu progreso guardado en el servidor y tambien reinicia el progreso local. La configuracion no cambia.';

  @override
  String get remoteProgressReset => 'Progreso remoto y local reiniciado.';

  @override
  String get resetRemoteProgressLoginRequired =>
      'Inicia sesion para reiniciar el progreso remoto.';

  @override
  String get remoteResetOfflineMessage =>
      'Backend no disponible. Solo se reinicio el progreso local.';

  @override
  String get remoteResetFailedMessage =>
      'No se pudo reiniciar el progreso remoto. Intentalo de nuevo.';

  @override
  String get cancel => 'Cancelar';

  @override
  String get settingsSectionAccount => 'Cuenta';

  @override
  String get settingsSectionGamePreferences => 'Preferencias de juego';

  @override
  String get settingsSectionAppSettings => 'Ajustes de la aplicacion';

  @override
  String get settingsSectionData => 'Datos';

  @override
  String get loadingSettings => 'Cargando configuracion';

  @override
  String get login => 'Iniciar sesion';

  @override
  String get register => 'Registrarse';

  @override
  String get logout => 'Cerrar sesion';

  @override
  String get email => 'Correo';

  @override
  String get password => 'Contrasena';

  @override
  String get displayName => 'Nombre';

  @override
  String get authOptional =>
      'Iniciar sesion es opcional. Activa sincronizacion y tabla de posiciones.';

  @override
  String get loggedInAs => 'Sesion iniciada como';

  @override
  String get notLoggedIn => 'Sin sesion iniciada';

  @override
  String get syncProgress => 'Sincronizar progreso';

  @override
  String get syncComplete => 'Progreso sincronizado.';

  @override
  String get syncUnavailable =>
      'Sincronizacion no disponible. El progreso local esta seguro.';

  @override
  String get leaderboard => 'Tabla de posiciones';

  @override
  String get leaderboardUnavailable => 'Tabla de posiciones no disponible.';

  @override
  String get localFirstNotice =>
      'El juego local sigue disponible sin conexion.';

  @override
  String get submit => 'Enviar';

  @override
  String get lives => 'Vidas';

  @override
  String get gameOver => 'Fin del juego';

  @override
  String get gameOverMessage => 'Te quedaste sin vidas.';

  @override
  String get mistakes => 'Errores';

  @override
  String get resetView => 'Restablecer vista';

  @override
  String get dragToRotate => 'Arrastra para rotar • pellizca para acercar';

  @override
  String get challengeTimeAttack => 'Contrarreloj';

  @override
  String get challengeTimeAttackDescription =>
      'Supera el nivel antes de que acabe el tiempo.';

  @override
  String get challengeMoveLimit => 'Movimientos limitados';

  @override
  String get challengeMoveLimitDescription =>
      'Despeja todas las flechas con un presupuesto fijo de movimientos.';

  @override
  String get challengePerfectRun => 'Partida perfecta';

  @override
  String get challengePerfectRunDescription =>
      'Una colision termina la partida. Solo perfeccion.';

  @override
  String get timeLeft => 'Tiempo';

  @override
  String get movesLeft => 'Movimientos restantes';

  @override
  String get flawless => 'Impecable';

  @override
  String get challengeBest => 'Mejor del reto';

  @override
  String get newRecord => 'Nuevo record!';

  @override
  String get challengeFailedTimeUp => 'Se acabo el tiempo!';

  @override
  String get challengeFailedOutOfMoves => 'Sin movimientos!';

  @override
  String get challengeFailedMistake =>
      'Una colision termino tu partida perfecta.';
}
