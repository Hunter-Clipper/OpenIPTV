// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get commonBack => 'Atrás';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonNotNow => 'Ahora no';

  @override
  String get wizardConnecting => 'Conectando…';

  @override
  String get wizardPickFileTitle => 'Elige un archivo de lista';

  @override
  String get wizardFilePickerFailed =>
      'No se pudo abrir el selector de archivos en este dispositivo.';

  @override
  String get wizardChooseFileFirst => 'Primero elige un archivo de lista.';

  @override
  String get wizardFieldServerAddress => 'la dirección del servidor';

  @override
  String get wizardFieldUsername => 'el nombre de usuario';

  @override
  String get wizardFieldPassword => 'la contraseña';

  @override
  String get wizardFieldM3uUrl => 'el enlace M3U';

  @override
  String wizardListAnd(String rest, String last) {
    return '$rest y $last';
  }

  @override
  String wizardEnterMissing(String fields) {
    return 'Escribe $fields que te dio tu proveedor.';
  }

  @override
  String get wizardRestoreEmpty =>
      'Esta copia de seguridad no incluye un perfil ni una lista, así que todavía no hay nada que restaurar. Toca Empezar.';

  @override
  String wizardRestoreProgressItem(String nickname, int index, int total) {
    return '$nickname ($index de $total)';
  }

  @override
  String wizardRestoreProgressLine(String label, String message) {
    return '$label — $message';
  }

  @override
  String get wizardLoadingRestoring => 'Restaurando tus listas…';

  @override
  String get wizardLoadingSettingUp => 'Preparando tu lista…';

  @override
  String get wizardAllSetAdded => '¡Lista añadida!';

  @override
  String wizardAllSetHeadline(String name) {
    return '¡Todo listo, $name!';
  }

  @override
  String get wizardAllSetHeadlineNoName => '¡Todo listo!';

  @override
  String get wizardAllSetBody =>
      'Tu lista ya está preparada.\nDisfruta de tus programas.';

  @override
  String get wizardWelcomeTitle => 'Te damos la bienvenida a\nOpenIPTV';

  @override
  String get wizardWelcomeSubtitle =>
      'Vamos a configurarlo todo.\nSolo toma un minuto.';

  @override
  String get wizardGetStarted => 'Empezar';

  @override
  String get wizardRestoreFromBackup =>
      'Restaurar desde una copia de seguridad';

  @override
  String get wizardNameTitle => '¿Cómo te llamas?';

  @override
  String get wizardPrivacyNote =>
      'Toda la información se queda en tu dispositivo.\nOpenIPTV nunca recopila datos personales.';

  @override
  String get wizardNameHint => 'Tu nombre';

  @override
  String get wizardPickAvatar => 'Elige un avatar';

  @override
  String get settingsAccentColorTitle => 'Color de acento';

  @override
  String get wizardContinue => 'Continuar';

  @override
  String get wizardPinTitle => 'Protege tu cuenta';

  @override
  String get wizardPinBody =>
      'Crea un PIN de 4 a 8 dígitos para proteger esta cuenta de administrador.\nPuedes omitirlo y añadir uno más tarde en Ajustes.';

  @override
  String get wizardSetPin => 'Crear PIN';

  @override
  String get wizardSkipForNow => 'Omitir por ahora';

  @override
  String get wizardTypeTitleAdd => '¿Qué tipo de lista\nvas a añadir?';

  @override
  String get wizardTypeTitleHave => '¿Qué tipo de lista\ntienes?';

  @override
  String get wizardTypeHelp =>
      '¿No lo sabes? Pregúntale a tu proveedor de IPTV, ¡seguro que lo sabe!';

  @override
  String get wizardTypeXtreamTitle => 'Xtream Codes';

  @override
  String get wizardTypeXtreamDesc =>
      'Inicia sesión con la dirección del servidor, un usuario y una contraseña.';

  @override
  String get wizardTypeM3uTitle => 'Lista M3U';

  @override
  String get wizardTypeM3uDesc =>
      'Carga una lista desde un enlace directo (que termine en .m3u o .m3u8).';

  @override
  String get wizardTypeFileTitle => 'Archivo de lista';

  @override
  String get wizardTypeFileDesc =>
      'Elige un archivo .m3u guardado en este dispositivo.';

  @override
  String get wizardCredsTitleXtream => 'Credenciales de Xtream';

  @override
  String get wizardCredsSubXtream =>
      'Escribe los datos de acceso de tu proveedor.';

  @override
  String get wizardCredsSubFile =>
      'Elige el archivo de lista guardado en este dispositivo.';

  @override
  String get wizardCredsSubM3u =>
      'Pega el enlace de la lista que te dio tu proveedor.';

  @override
  String get wizardNicknameOptional => 'Nombre (opcional)';

  @override
  String get wizardNickname => 'Nombre';

  @override
  String get wizardNicknameHintFile =>
      'Si lo dejas en blanco, se usa el nombre del archivo';

  @override
  String get wizardNicknameHintExample => 'p. ej., Servidor de casa';

  @override
  String get wizardServerAddressLabel => 'Dirección del servidor';

  @override
  String get wizardServerAddressHint => 'http://tu-proveedor.com:8080';

  @override
  String get wizardUsernameLabel => 'Usuario';

  @override
  String get wizardUsernameHint => 'tu_usuario';

  @override
  String get wizardPasswordLabel => 'Contraseña';

  @override
  String get wizardPasswordHint => 'tu_contraseña';

  @override
  String get wizardPasswordHide => 'Ocultar contraseña';

  @override
  String get wizardPasswordShow => 'Mostrar contraseña';

  @override
  String get wizardGuideUrlLabel => 'Enlace de la guía de TV (opcional)';

  @override
  String get wizardGuideUrlHint => 'https://ejemplo.com/epg.xml';

  @override
  String get wizardM3uUrlLabel => 'Enlace M3U';

  @override
  String get wizardM3uUrlHint => 'https://ejemplo.com/lista.m3u';

  @override
  String get wizardLoadMyPlaylist => 'Cargar mi lista';

  @override
  String get wizardFileFieldLabel => 'Archivo de lista';

  @override
  String get wizardFileChoose => 'Elige un archivo…';

  @override
  String get wizardFileChange => 'Cambiar';

  @override
  String get wizardFileBrowse => 'Examinar';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsGroupWatching => 'Ver';

  @override
  String get settingsGroupAppearance => 'Apariencia';

  @override
  String get settingsGroupPlayerControls => 'Controles del reproductor';

  @override
  String get settingsPlaybackTitle => 'Reproducción';

  @override
  String get settingsPlaybackSubtitle =>
      'Volver al inicio, imagen en imagen, controles del reproductor';

  @override
  String get settingsStartupTitle => 'Inicio';

  @override
  String get settingsStartupSubtitle =>
      'Abrir el último canal, iniciar al encender o reactivar';

  @override
  String get settingsChannelListsTitle => 'Listas de canales';

  @override
  String get settingsChannelListsSubtitle =>
      'Orden, canales ocultos, qué filas mostrar';

  @override
  String get settingsGuideLayoutTitle => 'Diseño de la guía de TV';

  @override
  String get settingsGuideLayoutSubtitle =>
      'Nombres, títulos en dos líneas, resaltado';

  @override
  String get settingsAskStartOverTitle => 'Ofrecer ver desde el principio';

  @override
  String get settingsAskStartOverBody =>
      'En los canales que guardan grabaciones (diferido), pregunta si quieres ver el programa desde el principio o en directo cuando abres uno que ya empezó. Desactívalo para ver siempre en directo.';

  @override
  String get settingsPipTitle => 'Imagen en imagen';

  @override
  String get settingsPipBody =>
      'Si está activado, al presionar Inicio mientras se reproduce un video, este se reduce a una pequeña ventana flotante para que puedas seguir viéndolo mientras usas otras apps.';

  @override
  String get settingsMediaNotificationTitle => 'Notificación multimedia';

  @override
  String get settingsMediaNotificationBody =>
      'Muestra una notificación de «Reproduciendo ahora» con controles de reproducir y pausar mientras se reproduce contenido, para que puedas controlarlo desde el panel de notificaciones o la pantalla de bloqueo.';

  @override
  String get settingsSkipButtonsTitle => 'Botones de salto';

  @override
  String settingsSecondsChoice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count segundos',
      one: '1 segundo',
    );
    return '$_temp0';
  }

  @override
  String get settingsHideControlsTitle => 'Ocultar controles tras';

  @override
  String get settingsSeekKeysTitle => 'Teclas de avance del mando';

  @override
  String get settingsSeekKeysLeftRight => 'Flechas izquierda / derecha';

  @override
  String get settingsSeekKeysUpDown => 'Flechas arriba / abajo';

  @override
  String get settingsSeekKeysMedia => 'Teclas de retroceso / avance';

  @override
  String get settingsLastChannelTitle => 'Abrir el último canal al iniciar';

  @override
  String get settingsLastChannelTooltipTitle => 'Último canal al iniciar';

  @override
  String get settingsLastChannelBody =>
      'Al abrir la app, va directo al último canal en vivo que viste. Desactívalo para entrar en TV en vivo.';

  @override
  String get settingsStartOnBootTitle => 'Iniciar al encender';

  @override
  String get settingsStartOnBootBody =>
      'Abre OpenIPTV automáticamente cuando se enciende el televisor. Android necesita que se permita «Mostrar sobre otras apps» para OpenIPTV; se te pedirá.';

  @override
  String get settingsStartOnWakeTitle => 'Iniciar al reactivar';

  @override
  String get settingsStartOnWakeBody =>
      'Abre OpenIPTV automáticamente cuando el televisor sale de la suspensión. Android necesita que se permita «Mostrar sobre otras apps» para OpenIPTV; se te pedirá.';

  @override
  String get settingsOverlayDialogTitle => 'Permitir mostrar sobre otras apps';

  @override
  String get settingsOverlayDialogBody =>
      'Android solo deja que OpenIPTV se abra por sí sola cuando el televisor se enciende o se reactiva si se permite «Mostrar sobre otras apps». Abre esa pantalla ahora y actívalo para OpenIPTV.';

  @override
  String get settingsOverlayOpenSettings => 'Abrir Ajustes';

  @override
  String get settingsAccentColorBody =>
      'Cambia el color de resalte que se usa en toda la app: botones activos, elementos seleccionados, barras de progreso y otros indicadores. Elige el que más te guste.';

  @override
  String get settingsAccentBlue => 'Azul';

  @override
  String get settingsAccentPurple => 'Morado';

  @override
  String get settingsAccentPink => 'Rosa';

  @override
  String get settingsAccentOrange => 'Naranja';

  @override
  String get settingsAccentGreen => 'Verde';

  @override
  String get settingsAccentTeal => 'Turquesa';

  @override
  String get settingsAccentCustom => 'Personalizado';

  @override
  String get settingsTextSizeTitle => 'Tamaño del texto';

  @override
  String get settingsTextSizeSmall => 'Pequeño';

  @override
  String get settingsTextSizeDefault => 'Predeterminado';

  @override
  String get settingsTextSizeLarge => 'Grande';

  @override
  String get settingsTextSizeExtraLarge => 'Muy grande';

  @override
  String get settingsPlayerTransparencyTitle => 'Transparencia del reproductor';

  @override
  String get settingsPlayerTransparencySolid => 'Sólido';

  @override
  String get settingsPlayerTransparencyDefault => 'Predeterminada';

  @override
  String get settingsPlayerTransparencyClear => 'Transparente';

  @override
  String get settingsPlayerTransparencyVeryClear => 'Muy transparente';

  @override
  String get settingsCleanNamesTitle => 'Limpiar nombres';

  @override
  String get settingsCleanNamesBody =>
      'Ordena los nombres que envía tu proveedor: quita etiquetas como «|EN|», «US|» o «A+ -» y convierte los nombres en MAYÚSCULAS a mayúsculas y minúsculas normales. Desactívalo para ver los nombres tal como los envía tu proveedor.';

  @override
  String get errorPlaylistNotM3u =>
      'Este archivo no es una lista. Elige un archivo .m3u o .m3u8 de tu proveedor.';

  @override
  String get errorPlaylistEmpty =>
      'Este archivo de lista no tiene ningún canal.';

  @override
  String get errorPlaylistFileMissing =>
      'El archivo de lista ya no está en este dispositivo. Elimina esta lista y vuelve a añadir el archivo.';

  @override
  String get errorXtreamLogin =>
      'No se pudo iniciar sesión con estos datos. Revisa la dirección del servidor, el usuario y la contraseña con tu proveedor.';

  @override
  String get errorM3uMissing =>
      'Escribe el enlace de la lista de tu proveedor.';

  @override
  String get errorLinkOpenFailed =>
      'No se pudo abrir el enlace de esta lista. Consúltalo con tu proveedor.';

  @override
  String get errorPlaylistTimeout =>
      'Esta lista tarda demasiado en cargar. Revisa tu conexión a internet e inténtalo de nuevo.';

  @override
  String get errorBadCredentials =>
      'Tu usuario o contraseña no parecen correctos. Consúltalo con tu proveedor.';

  @override
  String get errorUnreachable =>
      'No se pudo conectar con este servidor. Revisa tu conexión a internet e inténtalo de nuevo.';

  @override
  String get errorProviderServer =>
      'El servidor del proveedor tiene problemas en este momento. Inténtalo más tarde.';

  @override
  String get errorInvalidLink =>
      'Este enlace no parece una lista de canales válida. Revisa la dirección con tu proveedor.';

  @override
  String get errorGeneric =>
      'No se pudo completar. Revisa tus datos e inténtalo de nuevo.';

  @override
  String get errorGuideTimeout =>
      'La guía de TV tarda demasiado en cargar. Revisa tu conexión a internet e inténtalo de nuevo.';

  @override
  String get errorGuideEmpty =>
      'El proveedor envió una guía de TV vacía. Se conservó tu guía actual; inténtalo de nuevo en unos minutos.';

  @override
  String get errorGuideLogin =>
      'El enlace de la guía de TV requiere iniciar sesión. Revisa la dirección de la guía con tu proveedor.';

  @override
  String get errorGuideUnreachable =>
      'No se pudo conectar con el servidor de la guía de TV de esta lista. Puede que no tenga guía; revisa la dirección de la guía con tu proveedor.';

  @override
  String get errorGuideServer =>
      'El servidor de la guía de TV tiene problemas en este momento. Inténtalo más tarde.';

  @override
  String get errorGuideInvalidLink =>
      'Este enlace de la guía de TV no parece válido. Revisa la dirección con tu proveedor.';

  @override
  String get errorGuideGeneric =>
      'No se pudo cargar la guía de TV. Revisa tus datos e inténtalo de nuevo.';

  @override
  String get languageTitle => 'Idioma';

  @override
  String get languageAuto => 'Detectar desde el sistema';

  @override
  String languageAutoNow(String language) {
    return 'Automático — $language';
  }
}
