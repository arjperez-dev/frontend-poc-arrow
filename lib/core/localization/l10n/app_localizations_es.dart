// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Arrow POC';

  @override
  String get play => 'Jugar';

  @override
  String get settings => 'Configuracion';

  @override
  String get levels => 'Niveles';

  @override
  String get gamePlaceholder => 'Pantalla de juego provisional';

  @override
  String get backendUrlLabel => 'URL del backend';

  @override
  String get homeSubtitle =>
      'Base de rompecabezas con grafos para el juego movil.';

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
}
