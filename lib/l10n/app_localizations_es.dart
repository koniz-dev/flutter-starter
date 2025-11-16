// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Flutter Starter';

  @override
  String get welcome =>
      '¡Bienvenido a Flutter Starter con Arquitectura Limpia!';

  @override
  String get featureFlagsReady => '¡El Sistema de Feature Flags está listo!';

  @override
  String get checkExamples =>
      'Consulta los ejemplos en feature_flags_example_screen.dart';

  @override
  String get login => 'Iniciar sesión';

  @override
  String get register => 'Registrarse';

  @override
  String get email => 'Correo electrónico';

  @override
  String get password => 'Contraseña';

  @override
  String get name => 'Nombre';

  @override
  String get emailRequired => 'Por favor ingresa tu correo electrónico';

  @override
  String get emailInvalid => 'Por favor ingresa un correo electrónico válido';

  @override
  String get passwordRequired => 'Por favor ingresa tu contraseña';

  @override
  String passwordMinLength(int minLength) {
    return 'La contraseña debe tener al menos $minLength caracteres';
  }

  @override
  String get nameRequired => 'Por favor ingresa tu nombre';

  @override
  String nameMinLength(int minLength) {
    return 'El nombre debe tener al menos $minLength caracteres';
  }

  @override
  String get dontHaveAccount => '¿No tienes una cuenta? Regístrate';

  @override
  String get alreadyHaveAccount => '¿Ya tienes una cuenta? Inicia sesión';

  @override
  String get retry => 'Reintentar';

  @override
  String get error => 'Error';

  @override
  String get loading => 'Cargando...';

  @override
  String get language => 'Idioma';

  @override
  String get selectLanguage => 'Seleccionar idioma';

  @override
  String get english => 'Inglés';

  @override
  String get spanish => 'Español';

  @override
  String get arabic => 'Árabe';

  @override
  String get featureFlagsDebug => 'Depuración de Feature Flags';

  @override
  String get unexpectedError => 'Ocurrió un error inesperado';

  @override
  String get badRequest =>
      'Solicitud incorrecta. Por favor verifica tu entrada.';

  @override
  String get unauthorized =>
      'No autorizado. Por favor inicia sesión nuevamente.';

  @override
  String get forbidden => 'Prohibido. No tienes permiso.';

  @override
  String get notFound => 'Recurso no encontrado.';

  @override
  String get conflict => 'Conflicto. El recurso ya existe.';

  @override
  String get validationError =>
      'Error de validación. Por favor verifica tu entrada.';

  @override
  String get tooManyRequests =>
      'Demasiadas solicitudes. Por favor intenta más tarde.';

  @override
  String get internalServerError =>
      'Error interno del servidor. Por favor intenta más tarde.';

  @override
  String get badGateway =>
      'Puerta de enlace incorrecta. Por favor intenta más tarde.';

  @override
  String get serviceUnavailable =>
      'Servicio no disponible. Por favor intenta más tarde.';

  @override
  String get gatewayTimeout =>
      'Tiempo de espera de puerta de enlace agotado. Por favor intenta más tarde.';

  @override
  String get clientError => 'Ocurrió un error del cliente.';

  @override
  String get serverError =>
      'Ocurrió un error del servidor. Por favor intenta más tarde.';

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos',
      one: '1 elemento',
      zero: 'Sin elementos',
    );
    return '$_temp0';
  }

  @override
  String minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hace $count minutos',
      one: 'Hace 1 minuto',
      zero: 'Ahora mismo',
    );
    return '$_temp0';
  }
}
