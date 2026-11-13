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
      'Esta copia de seguridad no incluye un perfil ni una lista, así que todavía no hay nada que restaurar. Usa Empezar en su lugar.';

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
  String get wizardAllSetAdded => '¡Lista agregada!';

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
  String get wizardRestoreFromBackup => 'Restaurar copia de seguridad';

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
      'Crea un PIN de 4 a 8 dígitos para proteger esta cuenta de administrador.\nPuedes omitirlo y agregar uno más tarde en Ajustes.';

  @override
  String get wizardSetPin => 'Crear PIN';

  @override
  String get wizardSkipForNow => 'Omitir por ahora';

  @override
  String get wizardTypeTitleAdd => '¿Qué tipo de lista\nvas a agregar?';

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
  String get wizardGuideUrlLabel => 'Dirección de la guía (opcional)';

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
  String get settingsGroupWatching => 'Visualización';

  @override
  String get settingsGroupAppearance => 'Apariencia';

  @override
  String get settingsGroupPlayerControls => 'Controles del reproductor';

  @override
  String get settingsPlaybackTitle => 'Reproducción';

  @override
  String get settingsPlaybackSubtitle =>
      'Empezar de nuevo, imagen en imagen, controles del reproductor';

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
  String get settingsAskStartOverTitle => 'Ofrecer empezar de nuevo';

  @override
  String get settingsAskStartOverBody =>
      'En los canales que guardan grabaciones (diferido), pregunta si quieres ver el programa desde el principio o en vivo cuando abres uno que ya empezó. Desactívalo para ver siempre en vivo.';

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
  String get settingsPlayerTransparencyDefault => 'Predeterminado';

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
      'El archivo de lista ya no está en este dispositivo. Elimina esta lista y vuelve a agregar el archivo.';

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
      'La dirección de la guía de TV requiere iniciar sesión. Revísala con tu proveedor.';

  @override
  String get errorGuideUnreachable =>
      'No se pudo conectar con el servidor de la guía de TV de esta lista. Puede que no tenga guía; revisa la dirección de la guía con tu proveedor.';

  @override
  String get errorGuideServer =>
      'El servidor de la guía de TV tiene problemas en este momento. Inténtalo más tarde.';

  @override
  String get errorGuideInvalidLink =>
      'Esta dirección de la guía de TV no parece válida. Revísala con tu proveedor.';

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

  @override
  String get wizardAccentColor => 'Color de acento';

  @override
  String get consentTitle => '¿Quieres ayudar a mejorar OpenIPTV?';

  @override
  String get consentBody =>
      'OpenIPTV puede enviar un informe anónimo cuando la app falla o se congela. El informe incluye la versión de la app, el modelo de tu dispositivo y el lugar del código donde ocurrió el problema. Nunca incluye tus listas, inicios de sesión, enlaces, nombres de canales ni lo que ves, y no se puede relacionar contigo.\n\nEsto está desactivado a menos que lo actives. Puedes cambiar de opinión cuando quieras en Ajustes, donde también puedes ver exactamente qué se envía. El código que lo hace es pequeño y está abierto en GitHub por si quieres revisarlo.';

  @override
  String get consentNoThanks => 'No, gracias';

  @override
  String get consentTurnOn => 'Activar';

  @override
  String get errorStateTitle => 'No se pudo cargar';

  @override
  String get errorStateTryAgain => 'Reintentar';

  @override
  String get pinUnlock => 'Desbloquear';

  @override
  String get pinIncorrect => 'PIN incorrecto';

  @override
  String pinEnterAdminToUnlock(String name) {
    return 'Escribe el PIN de administrador para desbloquear «$name»';
  }

  @override
  String pinUnlockAction(String name) {
    return 'Desbloquear «$name»';
  }

  @override
  String pinSwitchToProfile(String name) {
    return 'Cambiar a $name';
  }

  @override
  String pinEnterForProfile(String name) {
    return 'Escribe el PIN de $name';
  }

  @override
  String get profilePickerLoadFailed => 'No se pudieron cargar los perfiles.';

  @override
  String get profilePickerWhoIsWatching => '¿Quién está viendo?';

  @override
  String get profilePickerKids => 'Niños';

  @override
  String get settingsGroupAccount => 'Cuenta';

  @override
  String get settingsGroupPlaylistsGuides => 'Listas y guías';

  @override
  String get settingsGroupAboutAdvanced => 'Acerca de y avanzado';

  @override
  String get settingsUpdatesTitle => 'Actualizaciones';

  @override
  String get settingsUpdatesBody =>
      'Busca una versión más reciente de OpenIPTV en GitHub y, si hay una, muestra qué cambió y la instala. Solo se consulta la página pública de versiones: no se envía nada sobre ti ni sobre tu dispositivo. Elige si esto también ocurre cada vez que se abre la app.';

  @override
  String get settingsUpdatesAutoOn => 'Busca automáticamente';

  @override
  String get settingsUpdatesManual => 'Solo manual';

  @override
  String get settingsUpdatesCheckAuto => 'Buscar automáticamente';

  @override
  String get settingsUpdatesClose => 'Cerrar';

  @override
  String get settingsUpdatesCheckNow => 'Buscar ahora';

  @override
  String get settingsProfileTitle => 'Perfil';

  @override
  String get settingsProfileBody =>
      'OpenIPTV admite varios perfiles en un mismo dispositivo. Cada perfil tiene su propio historial, favoritos, categorías ocultas y bloqueo con PIN. Selecciónalo para administrar los perfiles.';

  @override
  String get settingsProfileNone => 'Ningún perfil seleccionado';

  @override
  String settingsProfileSubtitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(
      kind,
      {
        'admin': 'Administrador',
        'kids': 'Perfil infantil',
        'other': 'Perfil estándar',
      },
    );
    return '$_temp0 · Administrar perfiles';
  }

  @override
  String get settingsSwitchProfileTitle => 'Cambiar de perfil';

  @override
  String get settingsSwitchProfileBody =>
      'Cambia rápidamente el perfil activo sin entrar en la administración de perfiles. Es útil cuando compartes el dispositivo con familiares o compañeros de casa.';

  @override
  String settingsProfilesAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count perfiles disponibles',
      one: '1 perfil disponible',
    );
    return '$_temp0';
  }

  @override
  String get settingsParentalTitle => 'Control parental';

  @override
  String get settingsParentalBody =>
      'Oculta las categorías para adultos y bloquea con el PIN de administrador las que elijas. Las categorías desbloqueadas siguen así hasta que se reinicie la app.';

  @override
  String get settingsParentalSubtitle =>
      'Protege con PIN las categorías para adultos y bloqueadas';

  @override
  String get settingsPlaylistsTitle => 'Listas';

  @override
  String get settingsPlaylistsBody =>
      'Una lista es la conexión con tu proveedor: un enlace de lista M3U o las credenciales de Xtream Codes. Las listas aportan tus canales, películas y series. Puedes agregar varias listas y actualizarlas aquí.';

  @override
  String get settingsPlaylistsNone => 'No hay listas agregadas';

  @override
  String settingsPlaylistsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count listas',
      one: '1 lista',
    );
    return '$_temp0';
  }

  @override
  String get settingsBackupTitle => 'Copia de seguridad y restauración';

  @override
  String get settingsBackupBody =>
      'Exporta tus perfiles y listas a un solo archivo .zip que puedes guardar donde quieras. Restáuralo más adelante para pasar a un dispositivo nuevo o recuperarte de un restablecimiento. Se incluyen las credenciales de acceso: guarda bien el archivo.';

  @override
  String get settingsBackupSubtitle =>
      'Exporta o importa tu perfil y tus listas';

  @override
  String get settingsAutoRefreshTitle => 'Actualización automática';

  @override
  String get settingsAutoRefreshBody =>
      'Actualiza automáticamente tus listas y la guía de TV en segundo plano para que los canales y la programación estén al día sin hacerlo a mano.';

  @override
  String settingsAutoRefreshEvery(int hours) {
    return 'Cada $hours horas';
  }

  @override
  String get settingsAutoRefreshOff => 'Desactivado';

  @override
  String settingsAutoRefreshNotifies(String interval) {
    return '$interval · avisa al terminar';
  }

  @override
  String get settingsAutoRefreshNotifyTitle => 'Avisar al terminar';

  @override
  String get settingsStayInformedTitle => 'Mantente al tanto';

  @override
  String get settingsStayInformedBody =>
      '¿Permites las notificaciones para que OpenIPTV te avise cuando termine una actualización en segundo plano o tenga algún problema?';

  @override
  String get settingsAllow => 'Permitir';

  @override
  String get settingsReliableRefreshTitle =>
      'Actualización confiable en segundo plano';

  @override
  String get settingsReliableRefreshBody =>
      'Algunos teléfonos limitan mucho las apps en segundo plano para ahorrar batería, lo que puede retrasar la actualización automática. Excluir a OpenIPTV de la optimización de batería hace las actualizaciones más confiables.';

  @override
  String get settingsContinue => 'Continuar';

  @override
  String get settingsGuideDataTitle => 'Datos de la guía';

  @override
  String get settingsGuideDataBody =>
      'Elige cuántos días de guía de TV se conservan, si se guardan las descripciones de los programas, consulta cuándo se actualizó por última vez la guía de cada lista y bórrala.';

  @override
  String get settingsGuideDataSubtitle => 'Cuánta guía de TV se guarda';

  @override
  String get settingsExtraGuidesTitle => 'Guías adicionales';

  @override
  String get settingsExtraGuidesBody =>
      'Agrega archivos de guía de TV para los canales de tu lista que no tienen guía. OpenIPTV los empareja por nombre y tú también puedes elegir la guía de cualquier canal.';

  @override
  String get settingsExtraGuidesSubtitle =>
      'Completa los canales que no tienen guía';

  @override
  String get settingsSortOrderTitle => 'Orden del contenido';

  @override
  String get settingsSortOrderBody =>
      'Controla cómo se ordenan los canales, las películas y las series. «Orden del proveedor» los muestra en la secuencia en que los envía tu proveedor de IPTV. A–Z los ordena alfabéticamente.';

  @override
  String get settingsSortProvider => 'Orden del proveedor';

  @override
  String get settingsSortAz => 'A–Z';

  @override
  String get settingsHiddenCategoriesTitle => 'Categorías ocultas';

  @override
  String get settingsHiddenCategoriesBody =>
      'Las categorías que ocultaste no aparecen en tu lista de canales. Tus canales siguen ahí, solo que fuera de la vista. Puedes volver a mostrarlas aquí cuando quieras.';

  @override
  String get settingsHiddenCategoriesNone => 'No hay categorías ocultas.';

  @override
  String get settingsResetCategoriesTitle =>
      'Restablecer nombres y orden de categorías';

  @override
  String get settingsResetCategoriesDialogTitle =>
      '¿Restablecer nombres y orden de categorías?';

  @override
  String get settingsResetCategoriesDialogBody =>
      'Las categorías de TV en vivo vuelven a los nombres y al orden que les da tu lista. Las categorías ocultas siguen ocultas.';

  @override
  String get settingsReset => 'Restablecer';

  @override
  String get settingsHiddenChannelsTitle => 'Canales ocultos';

  @override
  String get settingsHiddenChannelsBody =>
      'Los canales que ocultaste (mantén presionado un canal → Ocultar canal) no aparecen en TV en vivo, en la guía ni en la búsqueda de este perfil. Recupéralos aquí.';

  @override
  String get settingsHiddenChannelsNone => 'Ninguno';

  @override
  String settingsHiddenChannelsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ocultos',
      one: '1 oculto',
    );
    return '$_temp0';
  }

  @override
  String get settingsHiddenChannelsEmpty => 'No hay canales ocultos.';

  @override
  String get settingsChannelFromRemovedPlaylist =>
      'Canal de una lista eliminada';

  @override
  String get settingsShow => 'Mostrar';

  @override
  String get settingsShowAll => 'Mostrar todos';

  @override
  String get settingsAllChannels => 'Todos los canales';

  @override
  String get settingsShowFavorites => 'Mostrar favoritos';

  @override
  String get settingsShowRecent => 'Mostrar vistos recientemente';

  @override
  String get settingsShowAllChannels => 'Mostrar todos los canales';

  @override
  String get settingsGuideShowNames => 'Guía: mostrar nombres de canal';

  @override
  String get settingsGuideTwoLineNames =>
      'Guía: nombres de canal en dos líneas';

  @override
  String get settingsGuideTwoLineTitles =>
      'Guía: títulos de programa en dos líneas';

  @override
  String get settingsGuideHighlightPlaying =>
      'Guía: resaltar el canal en reproducción';

  @override
  String get settingsAboutTitle => 'Acerca de OpenIPTV';

  @override
  String get settingsAboutBody =>
      'Muestra la versión actual de la app y la información de la licencia. OpenIPTV es de código abierto bajo la licencia GPL-3.0: sin anuncios, sin telemetría, sin cuentas. Nunca.';

  @override
  String settingsAboutVersion(String version) {
    return 'Versión $version';
  }

  @override
  String get settingsAboutLegalese =>
      '© 2026 colaboradores de OpenIPTV. Con licencia GPL-3.0.';

  @override
  String get settingsAboutDescription =>
      'Un cliente IPTV multiplataforma, de código abierto y sin anuncios. No requiere cuentas. Sin telemetría. Sin anuncios. Nunca.';

  @override
  String get settingsPowerToolsTitle => 'Herramientas avanzadas';

  @override
  String get settingsPowerToolsBody =>
      'Herramientas para revisar y ajustar tu conexión: las direcciones IP de tu dispositivo y pública, el tipo de conexión, la VPN y el DNS. Útiles cuando un proveedor tiene problemas para conectarse contigo.';

  @override
  String get settingsPowerToolsSubtitle =>
      'Información de red para resolver problemas';

  @override
  String get settingsAnonReportsTitle => 'Informes anónimos';

  @override
  String get settingsAnonReportsBody =>
      'Opcionalmente, envía un informe anónimo cuando la app se cierra o se congela, para que los problemas se corrijan más rápido. Está desactivado salvo que lo actives, y puedes ver exactamente qué se envía.';

  @override
  String get settingsOn => 'Activado';

  @override
  String get settingsOff => 'Desactivado';

  @override
  String settingsPlaylistRefreshed(String name) {
    return 'Se actualizó la lista «$name».';
  }

  @override
  String settingsPlaylistRefreshFailed(String error) {
    return 'No se pudo actualizar la lista: $error';
  }

  @override
  String settingsGuideRefreshed(String name) {
    return 'Se actualizó la guía de TV de «$name».';
  }

  @override
  String get settingsSwitchPlaylistTitle => '¿Cambiar de lista?';

  @override
  String get settingsSwitchToAllBody =>
      '¿Mostrar todas las listas juntas?\n\nLa lista de canales, las películas y las series incluirán todas las listas.';

  @override
  String settingsSwitchToOneBody(String name) {
    return '¿Cambiar a «$name»?\n\nLa lista de canales, las películas y las series se actualizarán para mostrar solo esta lista.';
  }

  @override
  String get settingsSwitch => 'Cambiar';

  @override
  String get settingsRemovePlaylistTitle => '¿Eliminar la lista?';

  @override
  String settingsRemovePlaylistBody(String name) {
    return 'Se eliminará «$name» con todos sus canales, películas y series. Esta acción no se puede deshacer.';
  }

  @override
  String get settingsRemove => 'Eliminar';

  @override
  String settingsRemovingPlaylist(String name) {
    return 'Eliminando «$name»…';
  }

  @override
  String get settingsAddPlaylist => 'Agregar lista';

  @override
  String get settingsChoosePlaylistHint =>
      'Elige qué lista explorar o muestra todas juntas.';

  @override
  String get settingsPlaylistsLoadError => 'No se pudieron cargar las listas.';

  @override
  String get settingsPlaylistsEmpty => 'Aún no hay listas.';

  @override
  String get settingsAllPlaylists => 'Todas las listas';

  @override
  String settingsPlaylistsCombined(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count listas combinadas',
      one: '1 lista combinada',
    );
    return '$_temp0';
  }

  @override
  String get settingsSourceFile => 'Archivo de lista';

  @override
  String get settingsSourceM3u => 'Lista M3U';

  @override
  String get settingsBrowsing => 'En uso';

  @override
  String get settingsRefreshPlaylistTooltip => 'Actualizar lista';

  @override
  String get settingsMoreTooltip => 'Más';

  @override
  String get settingsEditPlaylist => 'Editar lista';

  @override
  String get settingsPlaylistInfo => 'Información de la lista';

  @override
  String get settingsRefreshTvGuide => 'Actualizar guía de TV';

  @override
  String get settingsInfoFetchError =>
      'No se pudo obtener la información del servidor.';

  @override
  String get settingsInfoSource => 'Origen';

  @override
  String get settingsInfoFileSaved => 'Archivo guardado en este dispositivo';

  @override
  String get settingsInfoGuideUrl => 'Dirección de la guía';

  @override
  String get settingsInfoLastRefreshed => 'Última actualización';

  @override
  String get settingsInfoNever => 'Nunca';

  @override
  String get settingsInfoStatus => 'Estado';

  @override
  String get settingsInfoExpires => 'Vence';

  @override
  String get settingsInfoActiveConnections => 'Conexiones activas';

  @override
  String get settingsInfoMaxConnections => 'Conexiones máximas';

  @override
  String get settingsInfoTrial => 'Prueba';

  @override
  String get settingsInfoYes => 'Sí';

  @override
  String get settingsInfoNo => 'No';

  @override
  String get settingsInfoServer => 'Servidor';

  @override
  String get settingsInfoTimezone => 'Zona horaria';

  @override
  String get browseActionsSortedAz => 'Ordenado A–Z';

  @override
  String get browseActionsProviderOrder => 'Orden del proveedor';

  @override
  String get browseActionsSwitchToList => 'Cambiar a vista de lista';

  @override
  String get browseActionsSwitchToGrid => 'Cambiar a vista de cuadrícula';

  @override
  String get browseActionsSwitchToCompact => 'Cambiar a vista compacta';

  @override
  String get browseActionsSwitchToPosters => 'Cambiar a vista de pósters';

  @override
  String get bufferPresetFastLabel => 'Inicio rápido';

  @override
  String get bufferPresetFastDescription =>
      'Empieza rápido y se reanuda justo después de un corte breve. Lo mejor con una buena conexión.';

  @override
  String get bufferPresetBalancedLabel => 'Equilibrado';

  @override
  String get bufferPresetBalancedDescription =>
      'Espera un poco más antes de empezar, para tener menos interrupciones con una conexión normal.';

  @override
  String get bufferPresetSmoothLabel => 'Fluido';

  @override
  String get bufferPresetSmoothDescription =>
      'Guarda una reserva más grande para que la reproducción aguante una conexión inestable. Tarda más en empezar y en cambiar de canal.';

  @override
  String get graphicsModeAutomaticLabel => 'Automático';

  @override
  String get graphicsModeAutomaticDescription =>
      'Usa el modo compatible solo en los televisores que lo necesitan. Recomendado.';

  @override
  String get graphicsModeStandardLabel => 'Estándar';

  @override
  String get graphicsModeStandardDescription =>
      'El método de dibujo más reciente. Lo mejor en la mayoría de teléfonos y televisores.';

  @override
  String get graphicsModeCompatibleLabel => 'Compatible';

  @override
  String get graphicsModeCompatibleDescription =>
      'Un método de dibujo más antiguo y estable. Pruébalo si la imagen se ve cortada (con una línea que la cruza) o entrecortada, sobre todo en movimientos rápidos.';

  @override
  String get videoLayerAutomaticLabel => 'Automático';

  @override
  String get videoLayerAutomaticDescription =>
      'Muestra la imagen como lo hacen los reproductores de TV, para un video más fluido y un cambio de canal más rápido y limpio. Recomendado.';

  @override
  String get videoLayerOnLabel => 'Activado';

  @override
  String get videoLayerOnDescription => 'Úsala siempre en este televisor.';

  @override
  String get videoLayerOffLabel => 'Desactivado';

  @override
  String get videoLayerOffDescription =>
      'Dibuja la imagen dentro de la app, como antes. Pruébalo si la imagen falta o se ve mal.';

  @override
  String get speedTestVerdictPlenty => 'De sobra, incluso para 4K.';

  @override
  String get speedTestVerdictGood => 'Buena para HD y para la mayoría del 4K.';

  @override
  String get speedTestVerdictFineHd => 'Bien para HD; el 4K puede cortarse.';

  @override
  String get speedTestVerdictEnoughSd =>
      'Suficiente para SD; el HD puede cortarse.';

  @override
  String get speedTestVerdictTooSlow =>
      'Demasiado lenta para una reproducción fluida.';

  @override
  String get vpnNotWireGuardProfile => 'Este no es un perfil de WireGuard.';

  @override
  String vpnProfileProblem(String detail) {
    return 'Este perfil tiene un problema ($detail).';
  }

  @override
  String get vpnNotAvailable =>
      'La VPN no está disponible en este dispositivo.';

  @override
  String get vpnNotOpenVpnProfile => 'Este no es un perfil de OpenVPN.';

  @override
  String get vpnNeedsDeviceCertificate =>
      'Este perfil necesita un certificado guardado en el dispositivo, algo que OpenIPTV no admite.';

  @override
  String get vpnCouldntReadProfile => 'No se pudo leer este perfil.';

  @override
  String get vpnConnected => 'VPN conectada';

  @override
  String get vpnConnecting => 'Conectando la VPN…';

  @override
  String get vpnNeedsPermission =>
      'OpenIPTV necesita tu permiso para configurar una VPN. Selecciona Conectar y permítelo.';

  @override
  String get vpnBadConfig =>
      'Este perfil tiene un problema. Impórtalo de nuevo.';

  @override
  String get vpnConnectFailed =>
      'No se pudo conectar la VPN. Revisa el perfil e inténtalo de nuevo.';

  @override
  String get refreshAllSummaryEverything => 'Todo está actualizado.';

  @override
  String get refreshAllSummaryPlaylists =>
      'Todas las listas están actualizadas.';

  @override
  String get refreshAllSummaryGuides =>
      'Todas las guías de TV están actualizadas.';

  @override
  String refreshAllProblem(String name, String message) {
    return '$name: $message';
  }

  @override
  String refreshAllSummaryFailedOne(String problems) {
    return '$problems.';
  }

  @override
  String refreshAllSummaryFailedMany(int ok, int total, String problems) {
    return '$ok de $total actualizadas. $problems.';
  }

  @override
  String refreshAllUpdating(String name, int done, int total) {
    return 'Actualizando $name… ($done de $total)';
  }

  @override
  String refreshAllUpdatingGuide(String name, int done, int total) {
    return 'Actualizando la guía de TV de $name… ($done de $total)';
  }

  @override
  String refreshAllUpdatingExtraGuides(int done, int total) {
    return 'Actualizando guías adicionales… ($done de $total)';
  }

  @override
  String get refreshAllEverythingTitle => 'Actualizar todo';

  @override
  String get refreshAllEverythingHint =>
      'Canales, películas, series y guías de TV de todas las listas';

  @override
  String get refreshAllPlaylistsTitle => 'Actualizar listas';

  @override
  String get refreshAllPlaylistsHint => 'Solo canales, películas y series';

  @override
  String get refreshAllGuidesTitle => 'Actualizar guías de TV';

  @override
  String get refreshAllGuidesHint =>
      'Qué hay ahora y qué sigue, en todas las listas';

  @override
  String get refreshAllChoiceEverything => 'Todo';

  @override
  String get refreshAllChoicePlaylists => 'Solo listas';

  @override
  String get refreshAllChoicePlaylistsHint => 'Canales, películas y series';

  @override
  String get refreshAllChoiceGuides => 'Solo guías de TV';

  @override
  String get refreshAllDialogTitle => 'Actualizar';

  @override
  String get refreshAllNowTitle => 'Actualizar ahora';

  @override
  String get refreshAllNowIdle => 'Actualiza tus listas y guías de TV ahora';

  @override
  String refreshAllLastRun(String time, String summary) {
    return '$time · $summary';
  }

  @override
  String get editPlaylistTitle => 'Editar lista';

  @override
  String get editPlaylistName => 'Nombre';

  @override
  String get editPlaylistServerAddress => 'Dirección del servidor';

  @override
  String get editPlaylistUsername => 'Nombre de usuario';

  @override
  String get editPlaylistPassword => 'Contraseña';

  @override
  String get editPlaylistPasswordHint =>
      'Déjalo vacío para conservar la contraseña actual';

  @override
  String get editPlaylistShowPassword => 'Mostrar contraseña';

  @override
  String get editPlaylistHidePassword => 'Ocultar contraseña';

  @override
  String get editPlaylistLink => 'Enlace de la lista';

  @override
  String get editPlaylistGuideAddress =>
      'Dirección de la guía de TV (opcional)';

  @override
  String get editPlaylistGuideAutoProvider => 'Automática — de tu proveedor';

  @override
  String get editPlaylistGuideAutoPlaylist => 'Automática — de la lista';

  @override
  String get editPlaylistFileNote =>
      'Esta lista es un archivo de tu dispositivo. Para usar otro archivo, agrégalo como una lista nueva.';

  @override
  String get editPlaylistLoginStored =>
      'Tus datos de acceso se guardan cifrados en este dispositivo.';

  @override
  String get editPlaylistSave => 'Guardar';

  @override
  String get editPlaylistChecking => 'Comprobando tus datos…';

  @override
  String get editPlaylistUpdating =>
      'Guardado. Actualizando canales y películas…';

  @override
  String editPlaylistSaved(String name) {
    return '«$name» guardada.';
  }

  @override
  String editPlaylistSavedUpdated(String name) {
    return '«$name» guardada y actualizada.';
  }

  @override
  String editPlaylistSavedWithSummary(String name, String summary) {
    return '«$name» guardada. $summary';
  }

  @override
  String get editPlaylistLiveFormat => 'Formato de la transmisión en vivo';

  @override
  String get editPlaylistLiveFormatNote =>
      'Al cambiarlo se actualizan los canales de la lista.';

  @override
  String get editPlaylistFormatAutoLabel => 'Automático';

  @override
  String get editPlaylistFormatAutoDescription =>
      'Sigue lo que permite tu proveedor, normalmente TS';

  @override
  String get editPlaylistFormatTsDescription =>
      'Flujo de transporte: arranca rápido y funciona con la mayoría de los proveedores';

  @override
  String get editPlaylistFormatHlsDescription =>
      'Lista adaptable: para proveedores cuyas transmisiones TS se cortan';

  @override
  String get parentalTitle => 'Control parental';

  @override
  String get parentalAdminsOnly => 'Solo para administradores.';

  @override
  String get parentalProtectionGroup => 'Protección';

  @override
  String get parentalProtectionTitle => 'Protección parental';

  @override
  String get parentalProtectionOn =>
      'Las categorías para adultos y las bloqueadas requieren el PIN de administrador';

  @override
  String get parentalProtectionOff =>
      'Desactivado — todo el contenido es visible';

  @override
  String get parentalLockedGroup => 'Categorías bloqueadas';

  @override
  String get parentalLockedDescription =>
      'El contenido para adultos se bloquea automáticamente. Las categorías de abajo las agregó el análisis de la lista.';

  @override
  String get parentalNoLocked => 'No hay otras categorías bloqueadas';

  @override
  String get parentalRemoveTooltip => 'Quitar de la lista de bloqueadas';

  @override
  String get carVideoTitle => 'Video en el auto';

  @override
  String get carVideoSubtitleMissing =>
      'Mira en la pantalla del auto cuando estés estacionado';

  @override
  String get carVideoSubtitleOutdated =>
      'Hay una actualización del complemento';

  @override
  String get carVideoSubtitleInstalled => 'Complemento instalado';

  @override
  String get carVideoInfoMissing =>
      'Esto necesita una pequeña app complementaria, OpenIPTV Video (aprox. 1 MB).';

  @override
  String get carVideoInfoInstalled => 'El complemento está instalado.';

  @override
  String get carVideoInfoOutdated =>
      'Hay una versión más reciente del complemento.';

  @override
  String carVideoInfo(String addonLine) {
    return 'Mira en la pantalla de tu auto con Android Auto mientras estás estacionado. Android Auto cierra la imagen cuando empiezas a manejar; el sonido sigue.\n\nCómo verlo: elige un canal, una película o un episodio en OpenIPTV en la pantalla del auto y luego abre Video, el segundo ícono de OpenIPTV.\n\n$addonLine\n\nSi no aparece en el auto: en la app Android Auto de tu teléfono, activa las opciones de desarrollador y «Fuentes desconocidas».';
  }

  @override
  String get carVideoNeedsPermission =>
      'Para instalar el complemento, OpenIPTV necesita permiso para instalar apps.\n\nSelecciona Abrir Ajustes, activa «Permitir desde esta fuente» y vuelve aquí; la instalación continuará automáticamente.';

  @override
  String get carVideoDownloading => 'Descargando…';

  @override
  String carVideoDownloadingPercent(int percent) {
    return 'Descargando… $percent %';
  }

  @override
  String get carVideoHandedOff =>
      'Sigue las indicaciones en pantalla para terminar la instalación.\n\nSi no apareció nada, o si cancelaste, selecciona Instalar de nuevo.';

  @override
  String get carVideoUnavailable =>
      'El complemento aún no está disponible para descargar. Llegará con la próxima versión de OpenIPTV.';

  @override
  String get carVideoFailed =>
      'No se pudo descargar el complemento. Revisa tu conexión a internet e inténtalo de nuevo.';

  @override
  String get carVideoDone => 'Listo';

  @override
  String get carVideoUpdate => 'Actualizar';

  @override
  String get carVideoInstall => 'Instalar';

  @override
  String get carVideoOpenSettings => 'Abrir Ajustes';

  @override
  String get carVideoClose => 'Cerrar';

  @override
  String get carVideoInstallAgain => 'Instalar de nuevo';

  @override
  String get carVideoTryAgain => 'Reintentar';

  @override
  String get profileTitle => 'Perfil';

  @override
  String get profileLoadFailed => 'No se pudo cargar el perfil.';

  @override
  String get profileNoActive => 'No hay un perfil activo.';

  @override
  String get profileKidsAdminBlocked =>
      'Las cuentas de administrador no pueden marcarse como cuentas infantiles';

  @override
  String get profileAdultHidden => 'Se ocultará el contenido para adultos';

  @override
  String get profileAllVisible => 'Todo el contenido es visible';

  @override
  String get profileAccountGroup => 'Cuenta';

  @override
  String get profileKidsProfile => 'Perfil infantil';

  @override
  String get profileKidsTooltipBody =>
      'Al activarlo, este perfil se marca como perfil infantil y el contenido para adultos se oculta automáticamente en TV en vivo, Películas y Series. Requiere que la Protección parental esté activada.';

  @override
  String get profileSecurityGroup => 'Seguridad';

  @override
  String get profilePinLock => 'Bloqueo con PIN';

  @override
  String get profilePinIsSet =>
      'PIN configurado — selecciona para cambiarlo o quitarlo';

  @override
  String get profilePinNotSet => 'Sin PIN — selecciona para crear uno';

  @override
  String get profileAllProfilesGroup => 'Todos los perfiles';

  @override
  String get profileAddProfile => 'Agregar perfil';

  @override
  String get profileEnterPinToDisableKids =>
      'Escribe el PIN de administrador para desactivar el perfil infantil';

  @override
  String get profileDeleteTitle => '¿Eliminar perfil?';

  @override
  String profileDeleteBody(String name) {
    return 'Al eliminar «$name» se eliminarán sus favoritos y ajustes. Tus listas y canales no se ven afectados.';
  }

  @override
  String get profileDelete => 'Eliminar';

  @override
  String get profileProtectionRequiredTitle =>
      'Se requiere la Protección parental';

  @override
  String get profileProtectionRequiredBody =>
      'Los perfiles infantiles necesitan que la Protección parental esté activada para ocultar automáticamente el contenido para adultos. ¿Activarla ahora?';

  @override
  String get profileEnableProtection => 'Activar protección';

  @override
  String get profileActive => 'Activo';

  @override
  String get profileKidsBadge => 'Infantil';

  @override
  String get profilePinBadge => 'PIN';

  @override
  String get profileMenuEdit => 'Editar';

  @override
  String get profileEditTitle => 'Editar perfil';

  @override
  String get profileNameLabel => 'Nombre';

  @override
  String get profileAvatarLabel => 'Avatar';

  @override
  String get profileEnterName => 'Escribe un nombre.';

  @override
  String get profileSaveFailed => 'No se pudieron guardar los cambios.';

  @override
  String get profileSave => 'Guardar';

  @override
  String get profileNewTitle => 'Perfil nuevo';

  @override
  String get profileNameHint => 'p. ej., Niños, Sala';

  @override
  String get profileIsKidAccount => 'Es una cuenta infantil';

  @override
  String get profileCreate => 'Crear';

  @override
  String get profileCreateFailed => 'No se pudo crear el perfil.';

  @override
  String get profilePinsDontMatch => 'Los PIN no coinciden.';

  @override
  String get profilePinTooShort => 'El PIN debe tener al menos 4 dígitos.';

  @override
  String get profileCurrentPinIncorrect => 'El PIN actual es incorrecto.';

  @override
  String get profileChangePinTitle => 'Cambiar PIN';

  @override
  String get profileSetPinTitle => 'Crear PIN';

  @override
  String get profileCurrentPin => 'PIN actual';

  @override
  String get profileNewPin => 'PIN nuevo';

  @override
  String get profilePinDigitsHint => 'De 4 a 8 dígitos';

  @override
  String get profileConfirmPin => 'Confirmar PIN';

  @override
  String get profileRepeatNewPin => 'Repite el PIN nuevo';

  @override
  String get profileRemovePin => 'Quitar PIN';

  @override
  String get profileEnterAdminPin => 'Escribe el PIN de administrador';

  @override
  String get profileBiometricPinMessage =>
      'Para activar el desbloqueo con huella y rostro';

  @override
  String get profileContinue => 'Continuar';

  @override
  String get profileIncorrectPin => 'PIN incorrecto';

  @override
  String get profileBiometricOn =>
      'El desbloqueo con huella y rostro está activado';

  @override
  String get profileBiometricFailed =>
      'No se pudo activar el desbloqueo con huella y rostro en este dispositivo.';

  @override
  String get profileBiometricTitle => 'Desbloquear con huella o rostro';

  @override
  String get profileBiometricBody =>
      'Usa tu huella o tu rostro donde se pida el PIN de administrador en este dispositivo. Cualquier persona cuya huella o rostro esté registrado en este dispositivo puede usarlo, así que actívalo solo si eres la única persona. Si agregas una huella o un rostro nuevo, se desactiva hasta que lo vuelvas a activar. Los demás perfiles siguen usando sus propios PIN.';

  @override
  String get profileBiometricSubtitleOn =>
      'Úsalo en lugar de escribir el PIN de administrador';

  @override
  String get profileBiometricSubtitleNeedsPin => 'Primero crea un PIN';

  @override
  String get powerUserTitle => 'Herramientas avanzadas';

  @override
  String get powerUserRefreshTooltip => 'Actualizar';

  @override
  String get powerUserOn => 'Activado';

  @override
  String get powerUserOff => 'Desactivado';

  @override
  String get powerUserYes => 'Sí';

  @override
  String get powerUserNo => 'No';

  @override
  String get powerUserAutomatic => 'Automático';

  @override
  String powerUserInUseNow(String mode) {
    return 'En uso ahora: $mode.';
  }

  @override
  String get powerUserNetworkTitle => 'Red';

  @override
  String get powerUserNetworkDescription =>
      'Cómo está conectado este dispositivo ahora mismo. Es útil cuando un proveedor tiene problemas para llegar a ti, por ejemplo para ver qué dirección ve o comprobar que tu VPN está activada.';

  @override
  String get powerUserNetworkDescriptionCopy =>
      'Cómo está conectado este dispositivo ahora mismo. Es útil cuando un proveedor tiene problemas para llegar a ti, por ejemplo para ver qué dirección ve o comprobar que tu VPN está activada. Selecciona una dirección para copiarla.';

  @override
  String get powerUserCheckingConnection => 'Comprobando tu conexión…';

  @override
  String get powerUserConnection => 'Conexión';

  @override
  String get powerUserDeviceIp => 'Dirección IP del dispositivo';

  @override
  String get powerUserNotAvailable => 'No disponible';

  @override
  String get powerUserVpnAddress => 'Dirección de la VPN';

  @override
  String get powerUserDnsServers => 'Servidores DNS';

  @override
  String powerUserCopied(String label) {
    return 'Copiado: $label';
  }

  @override
  String get powerUserPublicIp => 'Dirección IP pública';

  @override
  String get powerUserChecking => 'Comprobando…';

  @override
  String get powerUserCheckFailed =>
      'No se pudo comprobar ahora. Inténtalo de nuevo.';

  @override
  String powerUserPublicIpIdle(String service) {
    return 'La dirección que ve tu proveedor. Para comprobarla se consulta $service.';
  }

  @override
  String get powerUserCheck => 'Comprobar';

  @override
  String get powerUserCheckAgain => 'Comprobar de nuevo';

  @override
  String get powerUserVpnDescription =>
      'Una VPN integrada: WireGuard u OpenVPN. Útil cuando tu proveedor de internet bloquea o ralentiza a tu proveedor de IPTV. Solo se conecta una a la vez.';

  @override
  String get powerUserWgImportHint =>
      'Importa un perfil de WireGuard (archivo .conf) de tu proveedor de VPN.';

  @override
  String get powerUserOvpnImportHint =>
      'Importa un perfil de OpenVPN (archivo .ovpn) de tu proveedor de VPN.';

  @override
  String powerUserVpnStateOff(String name, String where) {
    return 'Desconectada — $name$where';
  }

  @override
  String powerUserWgConnected(
      String name, String where, String rx, String tx, String ago) {
    return 'Conectada — $name$where\n↓ $rx  ↑ $tx · $ago';
  }

  @override
  String get powerUserHandshakeWaiting => 'esperando la respuesta del servidor';

  @override
  String powerUserHandshakeAnswered(String when) {
    return 'el servidor respondió $when';
  }

  @override
  String get powerUserJustNow => 'hace un momento';

  @override
  String powerUserSecondsAgo(int seconds) {
    return 'hace $seconds s';
  }

  @override
  String powerUserMinutesAgo(int minutes) {
    return 'hace $minutes min';
  }

  @override
  String powerUserOvpnConnected(
      String name, String where, String rx, String tx) {
    return 'Conectada — $name$where\n↓ $rx  ↑ $tx';
  }

  @override
  String powerUserOvpnConnecting(String name, String where) {
    return 'Conectando — $name$where';
  }

  @override
  String powerUserOvpnError(String name, String where) {
    return 'No se pudo conectar — $name$where';
  }

  @override
  String get powerUserImport => 'Importar';

  @override
  String get powerUserDisconnect => 'Desconectar';

  @override
  String get powerUserConnect => 'Conectar';

  @override
  String get powerUserRouteApp => 'Solo OpenIPTV';

  @override
  String get powerUserRouteAppHint =>
      'Las demás apps siguen con tu conexión normal';

  @override
  String get powerUserRouteDevice => 'Todo el dispositivo';

  @override
  String get powerUserRouteDeviceHint =>
      'Todas las apps usan la VPN, excepto el enlace de Android Auto con el auto';

  @override
  String get powerUserReconnectToApply =>
      'Vuelve a conectar la VPN para aplicar el cambio.';

  @override
  String get powerUserAutoConnect => 'Conectar al abrir OpenIPTV';

  @override
  String get powerUserAutoConnectHint => 'Usa la última VPN que conectaste';

  @override
  String get powerUserRemoveWireGuard => 'Eliminar el perfil de WireGuard';

  @override
  String get powerUserChangeOvpnLogin => 'Cambiar el acceso de OpenVPN';

  @override
  String powerUserSignedInAs(String user) {
    return 'Sesión iniciada como $user';
  }

  @override
  String get powerUserRemoveOpenVpn => 'Eliminar el perfil de OpenVPN';

  @override
  String get powerUserPickOvpn => 'Elige un perfil de OpenVPN';

  @override
  String get powerUserPickWireGuard => 'Elige un perfil de WireGuard';

  @override
  String powerUserProfileAdded(String name) {
    return 'Perfil «$name» agregado';
  }

  @override
  String get powerUserVpnLoginTitle => 'Acceso a la VPN';

  @override
  String get powerUserVpnLoginBody =>
      'Este perfil necesita el nombre de usuario y la contraseña de tu proveedor de VPN. Se guardan cifrados en este dispositivo.';

  @override
  String get powerUserUsername => 'Nombre de usuario';

  @override
  String get powerUserPassword => 'Contraseña';

  @override
  String get powerUserSave => 'Guardar';

  @override
  String get powerUserVpnLoginSaved => 'Acceso a la VPN guardado';

  @override
  String get powerUserRemoveTitle => '¿Eliminar el perfil de VPN?';

  @override
  String get powerUserRemoveBody =>
      'La VPN se desconecta y el perfil se elimina de este dispositivo. Puedes importarlo de nuevo más tarde.';

  @override
  String get powerUserRemove => 'Eliminar';

  @override
  String get powerUserOvpnAuthFailed =>
      'El servidor VPN rechazó el nombre de usuario o la contraseña. Usa «Cambiar el acceso de OpenVPN» para corregirlo.';

  @override
  String get powerUserOvpnUnreachable =>
      'No se pudo conectar con el servidor VPN. Revisa el perfil y tu conexión.';

  @override
  String get powerUserOvpnConnectFailed =>
      'La VPN no se pudo conectar. Revisa el perfil e inténtalo de nuevo.';

  @override
  String get powerUserSpeedTitle => 'Prueba de velocidad';

  @override
  String get powerUserSpeedDescription =>
      'Mide qué tan rápido llega el video. La prueba con el proveedor usa una conexión con tu proveedor; si tu plan permite solo una a la vez, deja de ver contenido en otros dispositivos antes.';

  @override
  String get powerUserSpeedProviderLabel => 'Velocidad con tu proveedor';

  @override
  String get powerUserSpeedProviderIdle =>
      'Descarga durante unos segundos de la lista que estás viendo.';

  @override
  String get powerUserSpeedInternetLabel => 'Velocidad general de internet';

  @override
  String powerUserSpeedInternetIdle(String host) {
    return 'Descarga un archivo de prueba de $host.';
  }

  @override
  String get powerUserSpeedConnecting => 'Conectando…';

  @override
  String powerUserSpeedTesting(String mbps) {
    return 'Probando… $mbps Mbit/s';
  }

  @override
  String powerUserSpeedResult(String mbps, String verdict, int ms) {
    return '$mbps Mbit/s — $verdict\nTiempo de respuesta: $ms ms';
  }

  @override
  String get powerUserSpeedPacedNote =>
      'Medido en un canal en vivo, que llega a la velocidad de reproducción: muestra que la conexión aguanta, no tu velocidad máxima.';

  @override
  String get powerUserSpeedNothingToTest =>
      'Esta lista aún no tiene nada con qué probar.';

  @override
  String get powerUserSpeedProviderFailed =>
      'No se pudo descargar desde tu proveedor. Puede que esté ocupado, o que tu plan permita solo una conexión a la vez.';

  @override
  String get powerUserSpeedInternetFailed =>
      'No se pudo hacer la prueba. Revisa tu conexión e inténtalo de nuevo.';

  @override
  String get powerUserRun => 'Iniciar';

  @override
  String get powerUserRunAgain => 'Repetir';

  @override
  String get powerUserDbTitle => 'Base de datos';

  @override
  String get powerUserDbDescription =>
      'La base de datos guarda tus listas, tus accesos y tu historial, y está cifrada en el dispositivo. Desactivar el cifrado puede hacer más rápidos los televisores muy lentos.';

  @override
  String get powerUserDbSkipTitle => 'Omitir el cifrado de la base de datos';

  @override
  String get powerUserDbSkipQuestion =>
      '¿Omitir el cifrado de la base de datos?';

  @override
  String get powerUserDbTurnOnQuestion =>
      '¿Volver a activar el cifrado de la base de datos?';

  @override
  String get powerUserDbSkipBody =>
      'Tu base de datos (incluidos los accesos de las listas y los enlaces de transmisión) se guardará sin cifrar en el disco. Cualquiera con acceso al dispositivo podrá leerla. Hay que reiniciar la app para que el cambio surta efecto.';

  @override
  String get powerUserDbTurnOnBody =>
      'Tu base de datos volverá a cifrarse, lo que es más seguro pero puede ser más lento en televisores antiguos. La app se reiniciará para aplicarlo.';

  @override
  String get powerUserDbEnable => 'Omitir cifrado';

  @override
  String get powerUserDbTurnOn => 'Activar';

  @override
  String get powerUserDbReopenTitle => 'Vuelve a abrir OpenIPTV para terminar';

  @override
  String get powerUserDbReopenBody =>
      'Cambió el modo de cifrado de la base de datos. OpenIPTV se cerrará ahora. Ábrela de nuevo para aplicar el cambio.';

  @override
  String get powerUserDbClose => 'Cerrar OpenIPTV';

  @override
  String get powerUserBufferTitle => 'Búfer de reproducción';

  @override
  String get powerUserBufferDescription =>
      'Cuánto video guarda el reproductor en reserva. Una reserva más grande aguanta una conexión inestable, pero tarda más en empezar. Se aplica desde el próximo canal o video que abras.';

  @override
  String get powerUserPicturesTitle => 'Imágenes';

  @override
  String get powerUserPicturesDescription =>
      'Los pósters, los logotipos de canales y los fondos se muestran a resolución completa, para imágenes más nítidas. Desactívalo para mostrarlos aproximadamente al tamaño en que se dibujan, lo que usa menos memoria. Pruébalo si la app va lenta o se reinicia en un televisor o teléfono con poca memoria. Se aplica de inmediato; no hace falta descargar nada otra vez.';

  @override
  String get powerUserFullResTitle => 'Imágenes a resolución completa';

  @override
  String get powerUserFrameRateTitle => 'Ajustar la frecuencia de imagen';

  @override
  String get powerUserFrameRateDescription =>
      'Cambia tu pantalla a una frecuencia de actualización que se ajuste al video (por ejemplo, 24 Hz para películas), para que el movimiento se vea más fluido. Solo funciona si tu pantalla lo admite, y algunos televisores se ponen en negro un instante al cambiar. La pantalla vuelve a la normalidad cuando dejas de ver.';

  @override
  String get powerUserFrameRateSwitch => 'Ajustar la frecuencia de imagen';

  @override
  String get powerUserPassthroughTitle => 'Sonido envolvente sin procesar';

  @override
  String get powerUserPassthroughDescription =>
      'Envía el sonido Dolby y DTS sin modificar a una barra de sonido, un receptor o un televisor que lo decodifique. Se pausa solo mientras la vista múltiple está activa.';

  @override
  String get powerUserPassthroughAuto =>
      'Lo usa cuando tu sistema de sonido indica que puede. Recomendado.';

  @override
  String get powerUserPassthroughOn =>
      'Envía siempre el sonido envolvente tal cual. Solo si una barra de sonido o un receptor puede decodificarlo; si no, puede que no haya sonido.';

  @override
  String get powerUserPassthroughOff =>
      'El dispositivo siempre decodifica el sonido por sí mismo. Elígelo para los altavoces del televisor o si el sonido se corta o crepita.';

  @override
  String get powerUserTunnelingTitle => 'Reproducción en túnel';

  @override
  String get powerUserTunnelingDescription =>
      'Permite que los chips de video y de sonido trabajen juntos de forma directa, lo que puede reducir los tirones en transmisiones exigentes. Se pausa solo mientras la vista múltiple está activa.';

  @override
  String get powerUserTunnelingAuto =>
      'Se usa solo en dispositivos donde se ha comprobado que funciona. Recomendado.';

  @override
  String get powerUserTunnelingOn =>
      'Experimental, solo para canales en vivo. Si se traba o muestra una imagen negra, OpenIPTV lo desactiva solo; también puedes desactivarlo aquí.';

  @override
  String get powerUserTunnelingOff => 'Nunca se usa.';

  @override
  String get powerUserLayerTitle => 'Capa de video';

  @override
  String get powerUserLayerDescription =>
      'Muestra la imagen principal como lo hacen los reproductores de TV: movimiento más fluido, cambios de canal más rápidos y lo que necesita la reproducción en túnel. Se aplica cuando la app se reinicia.';

  @override
  String get powerUserLayerChangeFailed =>
      'No se pudo cambiar el ajuste de la capa de video.';

  @override
  String get powerUserRestartTitle => '¿Reiniciar para aplicar?';

  @override
  String get powerUserRestartLayerBody =>
      'OpenIPTV debe reiniciarse para cambiar cómo muestra la imagen. Lo que se esté reproduciendo se detendrá.';

  @override
  String get powerUserRestartGraphicsBody =>
      'OpenIPTV debe reiniciarse para cambiar cómo dibuja la pantalla. Lo que se esté reproduciendo se detendrá.';

  @override
  String get powerUserLater => 'Más tarde';

  @override
  String get powerUserRestartNow => 'Reiniciar ahora';

  @override
  String get powerUserRestartFailed =>
      'No se pudo reiniciar. Cierra y abre OpenIPTV para aplicarlo.';

  @override
  String get powerUserGraphicsTitle => 'Modo gráfico';

  @override
  String get powerUserGraphicsDescription =>
      'Cómo dibuja OpenIPTV la pantalla y el video. Si la imagen se ve cortada (con una línea que la cruza) o entrecortada en movimientos rápidos, prueba Compatible. Se aplica cuando la app se reinicia.';

  @override
  String powerUserGraphicsThisDevice(String chip) {
    return 'Este dispositivo: $chip.';
  }

  @override
  String get powerUserGraphicsChangeFailed =>
      'No se pudo cambiar el modo gráfico.';

  @override
  String get powerUserUaTitle => 'Agente de usuario';

  @override
  String get powerUserUaDescription =>
      'Cómo se presenta el reproductor ante tu proveedor. OpenIPTV envía su propio nombre, versión y dispositivo. Cámbialo solo si tu proveedor pide uno en particular. Cada canal adicional en la vista múltiple agrega su propia etiqueta al final, para que tu proveedor pueda distinguirlos. Se aplica desde el próximo canal que abras.';

  @override
  String get powerUserUaRow => 'Agente de usuario del reproductor';

  @override
  String get powerUserUaDefault => 'OpenIPTV (predeterminado)';

  @override
  String get powerUserUaEmptyNote => 'Déjalo vacío para usar el de OpenIPTV.';

  @override
  String get powerUserUaHint => 'p. ej., VLC/3.0.20 LibVLC/3.0.20';

  @override
  String get powerUserUseDefault => 'Usar el predeterminado';

  @override
  String get extraGuidesTitle => 'Guías adicionales';

  @override
  String get extraGuidesModeExplicit => 'Explícito';

  @override
  String get extraGuidesModeExplicitDesc =>
      'Solo cuando el ID de guía del canal es exactamente igual al de la guía. Es lo más seguro; los canales sin ID no se tocan.';

  @override
  String get extraGuidesModeStandard => 'Estándar';

  @override
  String get extraGuidesModeStandardDesc =>
      'El ID de guía, o exactamente el mismo nombre de canal. Las emisoras locales de EE. UU. se emparejan por su indicativo.';

  @override
  String get extraGuidesModeOptimistic => 'Optimista';

  @override
  String get extraGuidesModeOptimisticDesc =>
      'También canales con nombres solo parecidos. Encuentra más, pero algunas coincidencias serán erróneas; puedes corregirlas en Revisar coincidencias de guía.';

  @override
  String get extraGuidesMatchingModeTitle => 'Modo de emparejamiento';

  @override
  String get extraGuidesQueued =>
      'Se aplicará en cuanto termine la actualización en curso.';

  @override
  String get extraGuidesWorkingToast =>
      'Actualizando tus guías. Puede tardar unos minutos; los botones vuelven cuando termine.';

  @override
  String get extraGuidesStarting => 'Iniciando…';

  @override
  String extraGuidesUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Guías actualizadas: $count canales vinculados.',
      one: 'Guías actualizadas: 1 canal vinculado.',
    );
    return '$_temp0';
  }

  @override
  String get extraGuidesUpdateFailed => 'No se pudieron actualizar las guías.';

  @override
  String get extraGuidesChecking => 'Revisando la guía…';

  @override
  String get extraGuidesAlreadyAdded => 'Esa guía ya está en tu lista.';

  @override
  String extraGuidesAdded(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se agregó «$name» con $count canales. Emparejando canales…',
      one: 'Se agregó «$name» con 1 canal. Emparejando canales…',
    );
    return '$_temp0';
  }

  @override
  String extraGuidesRemoveTitle(String name) {
    return '¿Quitar «$name»?';
  }

  @override
  String get extraGuidesRemoveBody =>
      'Los canales que estaban emparejados con esta guía pierden su programación. Tus listas no se ven afectadas.';

  @override
  String get extraGuidesRemove => 'Quitar';

  @override
  String get extraGuidesUpdateNow => 'Actualizar ahora';

  @override
  String get extraGuidesTurnOff => 'Desactivar';

  @override
  String get extraGuidesTurnOn => 'Activar';

  @override
  String get extraGuidesMoveUp => 'Subir (se usa primero)';

  @override
  String get extraGuidesMoveDown => 'Bajar';

  @override
  String get extraGuidesFillTitle => 'Completar guías faltantes';

  @override
  String get extraGuidesFillDescription =>
      'La guía de TV de tu propia lista se usa siempre primero. Un canal que esa guía no cubre se empareja por nombre con las guías que agregues aquí. También puedes elegir la guía de cualquier canal: mantén presionado un canal → Cambiar guía.\n\nFunciona con guías .xml, .xml.gz y comprimidas en zip, siempre que al descomprimirse sean XML. OpenIPTV no ofrece guías, pero hay sitios de la comunidad que las publican: buscar «XMLTV EPG» en internet es un buen punto de partida. 😉';

  @override
  String get extraGuidesYourGuides => 'Tus guías';

  @override
  String get extraGuidesListHint =>
      'Las guías más arriba en la lista se usan primero.';

  @override
  String get extraGuidesListHintEmpty =>
      'Aún no hay ninguna. Las guías más arriba en la lista se usan primero.';

  @override
  String get extraGuidesAddTitle => 'Agregar una guía';

  @override
  String get extraGuidesAddSubtitle =>
      'Una dirección web que termine en .xml, .xml.gz o .zip';

  @override
  String get extraGuidesMatchingGroup => 'Emparejamiento';

  @override
  String get extraGuidesAutoMatchTitle => 'Emparejar canales automáticamente';

  @override
  String get extraGuidesAutoMatchSubtitle =>
      'Los canales sin guía se emparejan con las guías de arriba. Nunca cambia un canal que ya tiene guía.';

  @override
  String get extraGuidesMatchAndUpdate => 'Emparejar y actualizar ahora';

  @override
  String get extraGuidesReviewMatchesTitle => 'Revisar coincidencias de guía';

  @override
  String get extraGuidesNoMatchesYet => 'Aún no hay canales emparejados';

  @override
  String extraGuidesMatchSummary(int auto, int manual) {
    return '$auto emparejados automáticamente · $manual elegidos por ti';
  }

  @override
  String extraGuidesLastError(String error, String when) {
    return '$error\nÚltima lectura: $when.';
  }

  @override
  String get extraGuidesNotRead => 'Aún no se ha leído';

  @override
  String extraGuidesTileLine(int channels, int used, String when) {
    String _temp0 = intl.Intl.pluralLogic(
      channels,
      locale: localeName,
      other: '$channels canales',
      one: '1 canal',
    );
    return '$_temp0 · $used en uso · leída $when';
  }

  @override
  String extraGuidesTileLineOff(int channels, int used, String when) {
    String _temp0 = intl.Intl.pluralLogic(
      channels,
      locale: localeName,
      other: '$channels canales',
      one: '1 canal',
    );
    return '$_temp0 · $used en uso · leída $when · desactivada';
  }

  @override
  String get extraGuidesNameLabel => 'Nombre (opcional)';

  @override
  String get extraGuidesAddressLabel => 'Dirección de la guía';

  @override
  String get extraGuidesAddressInvalid =>
      'Escribe la dirección de la guía, que empiece con http:// o https://';

  @override
  String get extraGuidesAddButton => 'Agregar';

  @override
  String get extraGuidesLinksTitle => 'Coincidencias de guía';

  @override
  String get extraGuidesLinksEmpty =>
      'Todavía no hay canales emparejados con una guía adicional. Elige una para un canal: mantenlo presionado → Cambiar guía, o agrega una guía y deja que OpenIPTV empareje los canales por ti.';

  @override
  String get extraGuidesLinkNone => 'Sin guía (tu elección)';

  @override
  String extraGuidesLinkManual(String id, String guide) {
    return '$id · $guide · tu elección';
  }

  @override
  String extraGuidesLinkAuto(String id, String guide) {
    return '$id · $guide · automática';
  }

  @override
  String get extraGuidesGuideFallback => 'guía';

  @override
  String get guideDataAgoJustNow => 'hace un momento';

  @override
  String guideDataAgoMinutes(int count) {
    return 'hace $count min';
  }

  @override
  String guideDataAgoHours(int count) {
    return 'hace $count h';
  }

  @override
  String guideDataAgoDays(int count) {
    return 'hace $count d';
  }

  @override
  String get guideDataTitle => 'Datos de la guía';

  @override
  String get guideDataDaysTitle => 'Días de guía que se conservan';

  @override
  String get guideDataDaysDescription =>
      'Hasta cuántos días por delante se guarda la guía de TV. Menos días hacen la guía más pequeña y rápida de actualizar. El historial de diferido se conserva según lo ofrezca tu proveedor.';

  @override
  String guideDataDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días',
      one: '1 día',
    );
    return '$_temp0';
  }

  @override
  String guideDataDaysDefault(int count) {
    return '$count días (predeterminado)';
  }

  @override
  String get guideDataDetailsTitle => 'Detalles de los programas';

  @override
  String get guideDataDetailsDescription =>
      'Las descripciones ocupan la mayor parte de la guía. Desactívalas para ahorrar espacio; los títulos y horarios se conservan. Al desactivarlas se borran ahora las que ya están guardadas.';

  @override
  String get guideDataStoreDescriptions =>
      'Guardar descripciones de los programas';

  @override
  String get guideDataDescriptionsBack =>
      'Las descripciones volverán la próxima vez que se actualice la guía de TV.';

  @override
  String get guideDataLastUpdate => 'Última actualización';

  @override
  String get guideDataNoGuides => 'Ninguna de tus listas tiene guía de TV.';

  @override
  String get guideDataClearGroup => 'Borrar';

  @override
  String get guideDataClearTitle => '¿Borrar los datos de la guía?';

  @override
  String get guideDataClearBody =>
      'Esto borra la guía de TV guardada de todas las listas. Tus listas y canales se conservan. Actualiza las guías de TV para cargarla de nuevo.';

  @override
  String get guideDataClearButton => 'Borrar';

  @override
  String get guideDataClearRowTitle => 'Borrar datos de la guía';

  @override
  String get guideDataClearRowSubtitle =>
      'Borra la guía guardada de todas las listas';

  @override
  String get guideDataClearing => 'Borrando…';

  @override
  String get guideDataCleared => 'Se borraron los datos de la guía.';

  @override
  String guideDataLastLoaded(String error, String when, int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString programas',
      one: '1 programa',
    );
    return '$error\nÚltima carga: $when; se conservan $_temp0.';
  }

  @override
  String guideDataUpdated(String when, int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString programas',
      one: '1 programa',
    );
    return 'Actualizada $when · $_temp0';
  }

  @override
  String guideDataStored(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString programas guardados',
      one: '1 programa guardado',
    );
    return '$_temp0';
  }

  @override
  String get guideDataNotLoaded => 'Aún no se ha cargado';

  @override
  String get changeGuideTitle => 'Cambiar guía';

  @override
  String get changeGuideDescribeDefault =>
      'Usa la guía de la propia lista (o una coincidencia automática, si no tiene)';

  @override
  String get changeGuideDescribeNone => 'Sin guía, como elegiste';

  @override
  String changeGuideDescribeManual(String id, String guide) {
    return 'Elegiste $id en $guide';
  }

  @override
  String changeGuideDescribeAuto(String id, String guide) {
    return 'Emparejado automáticamente con $id en $guide';
  }

  @override
  String get changeGuideGuideFallback => 'una guía';

  @override
  String get changeGuideLoading =>
      'Cargando la guía; esto puede tardar un minuto…';

  @override
  String get changeGuideLoaded => 'Guía cambiada y cargada.';

  @override
  String get changeGuideRemoved => 'Guía quitada.';

  @override
  String get changeGuideBackToAuto => 'De vuelta al modo automático.';

  @override
  String get changeGuideNoGuidesTitle => 'Aún no hay guías para elegir';

  @override
  String get changeGuideNoGuidesBody =>
      'Agrega una en Ajustes → Listas y guías → Guías adicionales, o actualiza tus guías de TV.';

  @override
  String get changeGuideSearchHint => 'Buscar en las guías';

  @override
  String get changeGuideSuggested => 'Sugeridas';

  @override
  String get changeGuideResults => 'Resultados';

  @override
  String get changeGuideNothingFound => 'No se encontró nada';

  @override
  String get changeGuideGuideLabel => 'Guía';

  @override
  String get changeGuideNoGuideTitle => 'Sin guía para este canal';

  @override
  String get changeGuideNoGuideSubtitle =>
      'Borra su programación y la mantiene así';

  @override
  String get changeGuideUseAutomatic => 'Usar automático';

  @override
  String get changeGuideUseAutomaticSubtitle =>
      'La guía de la propia lista, o una coincidencia automática';

  @override
  String get backupTitle => 'Copia de seguridad y restauración';

  @override
  String get backupExportGroup => 'Exportar';

  @override
  String get backupExportInfoTitle => 'Exportar copia de seguridad';

  @override
  String get backupExportInfoBody =>
      'Al exportar se guardan todos los perfiles, todas las listas y los ajustes de la app en un solo archivo .zip. Si quieres, puedes protegerlo con una contraseña.';

  @override
  String get backupExportInfoTip =>
      'Guarda este archivo en un lugar seguro: lo necesitarás para restaurarlo todo en un dispositivo nuevo.';

  @override
  String get backupExportTitle => 'Exportar copia de seguridad';

  @override
  String get backupExportSubtitle =>
      'Guarda todos los perfiles, listas y ajustes en un archivo .zip';

  @override
  String get backupRestoreGroup => 'Restaurar';

  @override
  String get backupImportInfoTitle => 'Restaurar copia de seguridad';

  @override
  String get backupImportInfoBody =>
      'Al importar se lee un archivo de copia de seguridad .zip y se agregan sus perfiles y listas a este dispositivo. Si la copia tenía contraseña, se te pedirá la que se usó al exportarla.';

  @override
  String get backupImportInfoTip =>
      'Importar no borra nada: tus perfiles actuales se conservan.';

  @override
  String get backupImportTitle => 'Importar copia de seguridad';

  @override
  String get backupImportSubtitle =>
      'Abre un archivo de copia de seguridad .zip';

  @override
  String get backupPreparing => 'Preparando la copia de seguridad…';

  @override
  String backupSavedTo(String location) {
    return 'Copia de seguridad guardada en $location';
  }

  @override
  String get backupShareSubject => 'Copia de seguridad de OpenIPTV';

  @override
  String get backupCreateFailed =>
      'No se pudo crear el archivo de copia de seguridad. Verifica que tengas permiso de almacenamiento e inténtalo de nuevo.';

  @override
  String get backupSaveTitle => 'Guardar copia de seguridad';

  @override
  String get backupSaveBody =>
      'Guarda el archivo de copia de seguridad en este dispositivo o compártelo con otra app (correo, almacenamiento en la nube, …).';

  @override
  String get backupShareButton => 'Compartir…';

  @override
  String get backupSaveToDownloads => 'Guardar en Descargas';

  @override
  String backupRestoredProfiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count perfiles',
      one: '1 perfil',
    );
    return '$_temp0';
  }

  @override
  String backupRestoredSources(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count listas',
      one: '1 lista',
    );
    return '$_temp0';
  }

  @override
  String backupRestored(String profiles, String sources) {
    return 'Se restauraron $profiles y $sources.';
  }

  @override
  String get backupPickTitle => 'Elige una copia de seguridad';

  @override
  String get backupPickerFailed =>
      'No se pudo abrir el selector de archivos. Verifica que la app tenga permiso de acceso a archivos e inténtalo de nuevo.';

  @override
  String get backupOpenFailed =>
      'No se pudo abrir este archivo de copia de seguridad. Asegúrate de que sea una copia de OpenIPTV válida.';

  @override
  String get backupProtectTitle => '¿Proteger esta copia de seguridad?';

  @override
  String get backupProtectBody =>
      'Los datos de acceso de las listas se guardan en texto sin cifrar dentro del archivo. Si quieres, define una contraseña para cifrarlo; necesitarás la misma contraseña para restaurarlo.';

  @override
  String get backupPasswordOptionalHint => 'Contraseña (opcional)';

  @override
  String get backupSkip => 'Omitir';

  @override
  String get backupExportButton => 'Exportar';

  @override
  String get backupProtectedTitle => 'La copia está protegida';

  @override
  String get backupProtectedBody =>
      'Esta copia de seguridad está protegida con una contraseña. Escribe la que se definió al exportarla.';

  @override
  String get backupEnterPasswordHint => 'Escribe la contraseña';

  @override
  String get backupRestoreButton => 'Restaurar';

  @override
  String get updateManagedByPlay =>
      'Las actualizaciones de esta instalación las administra Google Play.';

  @override
  String get updateChecking => 'Buscando actualizaciones…';

  @override
  String get updateCheckFailed =>
      'No se pudo buscar actualizaciones. Revisa tu conexión a internet.';

  @override
  String updateUpToDate(String version) {
    return 'Tienes la versión más reciente ($version).';
  }

  @override
  String get updateAvailableTitle => 'Actualización disponible';

  @override
  String updateVersion(String version) {
    return 'Versión $version';
  }

  @override
  String updateVersionFromTo(String installed, String latest) {
    return 'Versión $installed → $latest';
  }

  @override
  String get updatePermissionBody =>
      'Para instalar actualizaciones, OpenIPTV necesita permiso para instalar apps.\n\nSelecciona Abrir Ajustes, activa «Permitir desde esta fuente» y vuelve aquí: la actualización continuará automáticamente.';

  @override
  String get updateDownloading => 'Descargando…';

  @override
  String updateDownloadingPercent(int percent) {
    return 'Descargando… $percent %';
  }

  @override
  String get updateHandedOffBody =>
      'Sigue las indicaciones en pantalla para terminar la instalación. OpenIPTV se reiniciará con la nueva versión.\n\nSi no apareció nada, o cancelaste, selecciona Instalar de nuevo.';

  @override
  String get updateFailedBody =>
      'No se pudo descargar la actualización. Revisa tu conexión a internet e inténtalo de nuevo.';

  @override
  String get updateSkipVersion => 'Omitir esta versión';

  @override
  String get updateLater => 'Más tarde';

  @override
  String get updateNow => 'Actualizar ahora';

  @override
  String get updateOpenSettings => 'Abrir Ajustes';

  @override
  String get updateClose => 'Cerrar';

  @override
  String get updateInstallAgain => 'Instalar de nuevo';

  @override
  String get updateTryAgain => 'Reintentar';

  @override
  String get updateNoNotes => 'No hay notas de la versión.';

  @override
  String get reportsTitle => 'Informes anónimos';

  @override
  String get reportsSwitchTitle => 'Enviar informes de fallas anónimos';

  @override
  String get reportsSwitchSubtitle =>
      'Desactivado salvo que lo actives. Ayuda a corregir fallas más rápido.';

  @override
  String get reportsIntro =>
      'Cuando la app falla o se congela, se guarda un informe breve en este dispositivo y se envía en segundo plano poco después, nunca más de una vez cada 10 minutos. No se puede vincular contigo ni con nada de lo que ves.';

  @override
  String get reportsContainsHeading => 'Un informe contiene solo esto';

  @override
  String get reportsContainsList =>
      '• Versión de la app\n• Versión de Android\n• Fabricante y modelo del dispositivo\n• La fecha (sin la hora)\n• Qué tipo de problema fue (falla o congelamiento) y solo su nombre\n• En qué parte del código ocurrió (hasta 30 líneas)';

  @override
  String get reportsNeverHeading => 'Nunca se incluye';

  @override
  String get reportsNeverList =>
      '• Listas, datos de acceso, contraseñas ni enlaces\n• Nombres de canales, películas o series, ni lo que ves\n• Textos de búsqueda, nombres de perfiles ni ajustes\n• Direcciones IP, ID del dispositivo ni ningún ID que permita relacionar informes\n• Mensajes de error (pueden contener enlaces o nombres)';

  @override
  String get reportsWaitingHeading => 'Pendientes de envío en este dispositivo';

  @override
  String get reportsNothingWaiting => 'No hay nada pendiente.';

  @override
  String get reportsDeleteWaiting => 'Eliminar informes pendientes';

  @override
  String get reportsCheckCodeHeading => 'Revisa el código';

  @override
  String get reportsCheckCodeBody =>
      'Todo está en lib/telemetry/ del repositorio de OpenIPTV en GitHub, con una breve nota de diseño en docs/design/anonymous-stats.md.';

  @override
  String get playerPlay => 'Reproducir';

  @override
  String get playerPause => 'Pausar';

  @override
  String get playerChannels => 'Canales';

  @override
  String get castTitleCasting => 'Transmitiendo';

  @override
  String get castDeviceFallback => 'Dispositivo de transmisión';

  @override
  String get castConnected => 'Conectado';

  @override
  String get castStop => 'Dejar de transmitir';

  @override
  String get castPickerTitle => 'Transmitir a';

  @override
  String get castSearching => 'Buscando televisores y altavoces en tu Wi-Fi…';

  @override
  String get castConnecting => 'Conectando…';

  @override
  String get castSameWifi =>
      'Tu teléfono y el televisor deben estar en la misma red Wi-Fi.';

  @override
  String get castCastTooltip => 'Transmitir';

  @override
  String get castYourTv => 'tu televisor';

  @override
  String castPlayingOn(String device) {
    return 'Reproduciendo en $device';
  }

  @override
  String castCastingTo(String device) {
    return 'Transmitiendo a $device';
  }

  @override
  String castOnDevice(String device) {
    return 'En $device';
  }

  @override
  String get castBack10 => 'Retroceder 10 segundos';

  @override
  String get castForward10 => 'Adelantar 10 segundos';

  @override
  String get castVolumeDown => 'Bajar volumen';

  @override
  String get castVolumeUp => 'Subir volumen';

  @override
  String catchupStartedMinutesAgo(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutos',
      one: '1 minuto',
    );
    return 'Este programa empezó hace $_temp0. ¿Desde dónde quieres verlo?';
  }

  @override
  String catchupStartedHoursAgo(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours horas',
      one: '1 hora',
    );
    return 'Este programa empezó hace $_temp0. ¿Desde dónde quieres verlo?';
  }

  @override
  String catchupStartedHoursMinutesAgo(int hours, int minutes) {
    return 'Este programa empezó hace $hours h $minutes min. ¿Desde dónde quieres verlo?';
  }

  @override
  String get catchupStartFromBeginning => 'Ver desde el principio';

  @override
  String get catchupWatchLive => 'Ver en vivo';

  @override
  String get playerClose => 'Cerrar';

  @override
  String get channelSwitcherBarrier => 'Cerrar canales';

  @override
  String get channelSwitcherFavorites => 'Favoritos';

  @override
  String get channelSwitcherTitle => 'Canales';

  @override
  String get channelSwitcherPrevCategory => 'Categoría anterior';

  @override
  String get channelSwitcherNextCategory => 'Categoría siguiente';

  @override
  String get channelSwitcherNowWatching => 'Viendo ahora';

  @override
  String get channelSwitcherLive => 'En vivo';

  @override
  String get playerChannelUnavailableNow =>
      'Este canal no está disponible en este momento.';

  @override
  String get multiViewFullScreen => 'Pantalla completa';

  @override
  String get multiViewSwap => 'Cambiar canal';

  @override
  String get multiViewAdd => 'Agregar un canal';

  @override
  String get multiViewLayout => 'Disposición';

  @override
  String get multiViewEqualGrid => 'Cuadrícula';

  @override
  String get multiViewOneBig => 'Uno grande';

  @override
  String get multiViewRemove => 'Quitar';

  @override
  String get multiViewHintOptions => 'Toca dos veces para ver opciones';

  @override
  String get multiViewHintHear => 'Toca dos veces para escuchar este canal';

  @override
  String get multiViewNoDecoder =>
      'Este dispositivo no puede reproducir otro canal al mismo tiempo.';

  @override
  String get multiViewProviderRefused =>
      'Tu proveedor no permitió otra transmisión.';

  @override
  String playerBackSeconds(int seconds) {
    return 'Retroceder $seconds segundos';
  }

  @override
  String playerForwardSeconds(int seconds) {
    return 'Adelantar $seconds segundos';
  }

  @override
  String get playerSubtitles => 'Subtítulos';

  @override
  String get playerRemoveFavorite => 'Quitar de favoritos';

  @override
  String get playerAddFavorite => 'Agregar a favoritos';

  @override
  String get playerTvGuide => 'Guía de TV';

  @override
  String get playerSettingsTooltip => 'Ajustes de reproducción';

  @override
  String playerTimeLeft(String duration) {
    return 'Quedan $duration';
  }

  @override
  String playerNextProgramme(String title) {
    return 'Siguiente: $title';
  }

  @override
  String get playerLiveBadge => 'VIVO';

  @override
  String get playerGoLive => 'Ver en vivo';

  @override
  String playerStreamDetails(String details) {
    return 'Detalles de la transmisión: $details';
  }

  @override
  String get playerNoticeAudioDelay =>
      'El retraso de audio no funcionó con esta transmisión, así que se restableció a Ninguno. La reproducción continúa con normalidad.';

  @override
  String get playerNoticePassthrough =>
      'El sonido envolvente sin procesar no funcionó en este dispositivo, así que se desactivó y el audio se reproduce con normalidad. Puedes volver a probarlo en Herramientas avanzadas.';

  @override
  String get playerNoticeTunneled =>
      'La reproducción en túnel no funcionó en este dispositivo, así que se desactivó. Puedes volver a probarla en Herramientas avanzadas.';

  @override
  String get playerErrorProviderRefused =>
      'Tu proveedor no permitió esta transmisión.';

  @override
  String get playerErrorChannelProvider =>
      'Este canal no está disponible con tu proveedor en este momento.';

  @override
  String get playerErrorTitleProvider =>
      'Este título no está disponible con tu proveedor en este momento.';

  @override
  String get castThisDevice => 'este dispositivo';

  @override
  String castFailedChannel(String device) {
    return 'Este canal no se puede reproducir en $device. Deja de transmitir para verlo aquí.';
  }

  @override
  String castFailedTitle(String device) {
    return 'Este título no se puede reproducir en $device. Deja de transmitir para verlo aquí.';
  }

  @override
  String get playerResumeTitle => '¿Continuar viendo?';

  @override
  String playerResumeBody(String position) {
    return '¿Continuar desde $position?';
  }

  @override
  String get playerStartOver => 'Empezar de nuevo';

  @override
  String get playerResume => 'Continuar';

  @override
  String get playerVideoSemantics => 'Video';

  @override
  String get playerVideoSemanticsHint =>
      'Toca dos veces para mostrar u ocultar los controles de reproducción';

  @override
  String get playerReconnecting => 'Reconectando…';

  @override
  String playerReconnectingAttempt(int attempt, int max) {
    return 'Reconectando… ($attempt de $max)';
  }

  @override
  String get playerUpNext => 'A continuación';

  @override
  String get playerPlayNow => 'Reproducir ahora';

  @override
  String get playerStreamNotPlaying =>
      'Esta transmisión no se está reproduciendo ahora';

  @override
  String get playerTryAgain => 'Reintentar';

  @override
  String get playerGoBack => 'Volver';

  @override
  String get playerSubtitlesOff => 'Desactivados';

  @override
  String get playerNoSubtitlesLive =>
      'Aún no se detectan subtítulos en este canal. Los subtítulos aparecerán aquí en cuanto la emisión los envíe.';

  @override
  String get playerNoSubtitlesVideo => 'Este video no tiene subtítulos.';

  @override
  String get playerAudio => 'Audio';

  @override
  String get playerPicture => 'Imagen';

  @override
  String get playerPictureFit => 'Ajustar';

  @override
  String get playerPictureZoom => 'Zoom';

  @override
  String get playerPictureFill => 'Llenar pantalla';

  @override
  String get playerClock => 'Reloj';

  @override
  String get playerClockWithControls => 'Con los controles';

  @override
  String get playerClockAlwaysOn => 'Siempre visible';

  @override
  String get playerAudioDelay => 'Retraso de audio';

  @override
  String get playerAudioDelayNone => 'Ninguno';

  @override
  String get playerStreamDetailsLabel => 'Detalles de la transmisión';

  @override
  String get playerShow => 'Mostrar';

  @override
  String get playerHide => 'Ocultar';

  @override
  String get playerSpeed => 'Velocidad';

  @override
  String get playerSpeedNormal => 'Normal';

  @override
  String get playerCaptions => 'Subtítulos';

  @override
  String playerCaptionsNumbered(int channel) {
    return 'Subtítulos $channel';
  }

  @override
  String get playerDigitalCaptions => 'Subtítulos digitales';

  @override
  String playerDigitalCaptionsNumbered(int channel) {
    return 'Subtítulos digitales $channel';
  }

  @override
  String get playerLangEn => 'Inglés';

  @override
  String get playerLangEs => 'Español';

  @override
  String get playerLangFr => 'Francés';

  @override
  String get playerLangDe => 'Alemán';

  @override
  String get playerLangIt => 'Italiano';

  @override
  String get playerLangPt => 'Portugués';

  @override
  String get playerLangNl => 'Neerlandés';

  @override
  String get playerLangAr => 'Árabe';

  @override
  String get playerLangRu => 'Ruso';

  @override
  String get playerLangTr => 'Turco';

  @override
  String get playerLangPl => 'Polaco';

  @override
  String get playerLangHi => 'Hindi';

  @override
  String get playerLangJa => 'Japonés';

  @override
  String get playerLangKo => 'Coreano';

  @override
  String get playerLangZh => 'Chino';

  @override
  String get playerLangEl => 'Griego';

  @override
  String get playerLangSv => 'Sueco';

  @override
  String get playerLangDa => 'Danés';

  @override
  String get playerLangNo => 'Noruego';

  @override
  String get playerLangFi => 'Finlandés';

  @override
  String get playerLangHe => 'Hebreo';

  @override
  String get playerLangRo => 'Rumano';

  @override
  String get carLibrarySetup => 'Abre OpenIPTV en tu teléfono para empezar';

  @override
  String get carLibraryLiveTv => 'TV en vivo';

  @override
  String get carLibraryMovies => 'Películas';

  @override
  String get carLibrarySeries => 'Series';

  @override
  String get carLibraryFavorites => 'Favoritos';

  @override
  String get carLibraryRecentlyWatched => 'Vistos recientemente';

  @override
  String get carLibraryContinueWatching => 'Continuar viendo';

  @override
  String get categoryToolsRename => 'Cambiar nombre de la categoría';

  @override
  String get categoryToolsMoveUp => 'Subir';

  @override
  String get categoryToolsMoveDown => 'Bajar';

  @override
  String get categoryToolsResetName => 'Restablecer nombre';

  @override
  String get categoryToolsHide => 'Ocultar categoría';

  @override
  String get categoryToolsNameHint => 'Nombre de la categoría';

  @override
  String get categoryToolsRenameNote =>
      'Solo cambia cómo se ve aquí. Déjalo vacío para volver al nombre original.';

  @override
  String get categoryToolsSave => 'Guardar';

  @override
  String get liveTvRemoveFromRecent => 'Quitar de vistos recientemente';

  @override
  String get liveTvTitle => 'TV en vivo';

  @override
  String get liveTvLoadError =>
      'No se pudieron cargar los canales. Revisa tu conexión a internet.';

  @override
  String get liveTvFavorites => 'Favoritos';

  @override
  String get liveTvRecentlyWatched => 'Vistos recientemente';

  @override
  String get liveTvCategories => 'Categorías';

  @override
  String get liveTvAllChannels => 'Todos los canales';

  @override
  String get liveTvNoChannels => 'Aún no hay canales aquí.';

  @override
  String get liveTvRenameChannel => 'Cambiar nombre del canal';

  @override
  String get liveTvChannelNameHint => 'Nombre del canal';

  @override
  String get liveTvChannelHidden =>
      'Canal oculto. Para volver a mostrarlo, ve a Ajustes → Visualización → Listas de canales → Canales ocultos.';

  @override
  String get liveTvCatchupAvailable => 'Diferido disponible';

  @override
  String liveTvNextProgramme(String time, String title) {
    return 'Sigue  $time  $title';
  }

  @override
  String get liveTvRemoveFromFavorites => 'Quitar de favoritos';

  @override
  String get liveTvAddToFavorites => 'Agregar a favoritos';

  @override
  String get liveTvUseOriginalName => 'Usar el nombre original';

  @override
  String get liveTvChangeGuide => 'Cambiar guía';

  @override
  String get liveTvHideChannel => 'Ocultar canal';

  @override
  String get liveTvLiveBadge => 'Vivo';

  @override
  String get epgPanelCatchupUnavailable =>
      'El diferido no está disponible para este programa.';

  @override
  String get epgPanelToday => 'Hoy';

  @override
  String get epgPanelLoadError =>
      'No se pudo cargar la guía de TV. Tus canales siguen funcionando; la información de la guía se volverá a intentar sola.';

  @override
  String get epgPanelNoInfo => 'No hay información de la guía para este día.';

  @override
  String get epgPanelLiveBadge => 'VIVO';

  @override
  String get tvGuideCategoryLocked =>
      'Esta categoría está bloqueada. Presiona OK en ella para desbloquearla.';

  @override
  String get tvGuideStreamDenied =>
      'Tu proveedor no permitió esta transmisión.';

  @override
  String get tvGuideChannelUnavailable =>
      'Este canal no está disponible en este momento.';

  @override
  String get tvGuidePressOkToPreview => 'Presiona OK para ver una vista previa';

  @override
  String get tvGuideNoInfo => 'Sin información de la guía';

  @override
  String get searchLoadError =>
      'No se pudieron cargar los resultados. Inténtalo de nuevo.';

  @override
  String searchNoResultsTitle(String query) {
    return 'Sin resultados para «$query»';
  }

  @override
  String get searchNoResultsBody =>
      'Revisa la ortografía o prueba con el nombre de un canal, una película o un programa.';

  @override
  String get searchHint => 'Buscar canales, películas y series';

  @override
  String get searchWelcomeTitle => 'Encuentra algo para ver';

  @override
  String get searchWelcomeBody =>
      'Busca canales de TV en vivo, películas, series y lo que se emite ahora.';

  @override
  String get searchRecentTitle => 'Búsquedas recientes';

  @override
  String get searchClearRecent => 'Borrar búsquedas recientes';

  @override
  String searchEnterPinToUnlock(String label) {
    return 'Escribe el PIN de administrador para desbloquear «$label»';
  }

  @override
  String searchTomorrowAt(String time) {
    return 'Mañana $time';
  }

  @override
  String searchYesterdayAt(String time) {
    return 'Ayer $time';
  }

  @override
  String get searchOnNow => 'En emisión';

  @override
  String get searchLiveTv => 'TV en vivo';

  @override
  String get searchLive => 'En vivo';

  @override
  String get searchComingUp => 'Próximamente';

  @override
  String get searchEarlier => 'Anteriores';

  @override
  String get searchMovies => 'Películas';

  @override
  String get searchSeries => 'Series';

  @override
  String get mediaRailSeeAll => 'Ver todo';

  @override
  String get mediaRailEnterPin => 'Escribe el PIN para ver';

  @override
  String get detailLess => 'Menos';

  @override
  String get detailMore => 'Más';

  @override
  String detailStarring(String cast) {
    return 'Reparto  $cast';
  }

  @override
  String detailDirector(String director) {
    return 'Director  $director';
  }

  @override
  String get detailPlay => 'Reproducir';

  @override
  String detailResumeFrom(String time) {
    return 'Continuar desde $time';
  }

  @override
  String get detailStartOver => 'Empezar de nuevo';

  @override
  String get detailFavorited => 'En favoritos';

  @override
  String get detailFavorite => 'Favorito';

  @override
  String get detailClearProgress => 'Borrar progreso';

  @override
  String get detailMoreLikeThis => 'Más como esto';

  @override
  String get detailGoBack => 'Volver';

  @override
  String get detailMovieLoadError =>
      'No se pudo cargar esta película. Inténtalo de nuevo.';

  @override
  String get detailSeriesLoadError =>
      'No se pudo cargar esta serie. Inténtalo de nuevo.';

  @override
  String get seriesLoadingEpisodes => 'Cargando episodios…';

  @override
  String get seriesNoEpisodesYet => 'Aún no hay episodios';

  @override
  String seriesResumeEpisode(String label) {
    return 'Continuar $label';
  }

  @override
  String seriesPlayEpisode(String label) {
    return 'Reproducir $label';
  }

  @override
  String seriesShortEpisode(int episode, int season) {
    return 'T$season E$episode';
  }

  @override
  String seriesSeasonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count temporadas',
      one: '$count temporada',
    );
    return '$_temp0';
  }

  @override
  String get seriesUpNext => 'Siguiente';

  @override
  String get seriesEpisodes => 'Episodios';

  @override
  String get seriesNoEpisodesAvailable => 'Aún no hay episodios disponibles.';

  @override
  String seriesSeason(int number) {
    return 'Temporada $number';
  }

  @override
  String get detailFavorites => 'Favoritos';

  @override
  String get detailContinueWatching => 'Continuar viendo';

  @override
  String get detailBrowseByGenre => 'Explorar por género';

  @override
  String get detailAllGenre => 'Todo';

  @override
  String get detailAddToFavorites => 'Agregar a favoritos';

  @override
  String get detailRemoveFromFavorites => 'Quitar de favoritos';

  @override
  String get detailRemoveFromContinueWatching => 'Quitar de Continuar viendo';

  @override
  String get moviesTitle => 'Películas';

  @override
  String get moviesLoadError =>
      'No se pudieron cargar las películas. Inténtalo de nuevo.';

  @override
  String get moviesAll => 'Todas las películas';

  @override
  String get moviesNoneFound => 'No se encontraron películas.';

  @override
  String get seriesTitle => 'Series';

  @override
  String get seriesLoadError =>
      'No se pudieron cargar las series. Inténtalo de nuevo.';

  @override
  String get seriesAll => 'Todas las series';

  @override
  String get seriesNoneFound => 'No se encontraron series.';

  @override
  String get shellPressBackAgain => 'Presiona Atrás otra vez para salir';

  @override
  String get navLiveTv => 'TV en vivo';

  @override
  String get navMovies => 'Películas';

  @override
  String get navSeries => 'Series';

  @override
  String get navSearch => 'Buscar';

  @override
  String get navSettings => 'Ajustes';

  @override
  String pullRefreshOne(String name, String reason) {
    return 'No se pudo actualizar $name. $reason';
  }

  @override
  String pullRefreshMany(String names) {
    return 'No se pudo actualizar $names. Inténtalo de nuevo más tarde.';
  }

  @override
  String get genreActionsHideGenre => 'Ocultar género';

  @override
  String get filePickerNoFiles =>
      'No se encontraron archivos en este dispositivo. Copia el archivo a la carpeta Download, o a Android/data/com.openiptv.app/files, y vuelve a intentarlo.';

  @override
  String get starRemoveFavorite => 'Quitar de favoritos';

  @override
  String get starAddFavorite => 'Agregar a favoritos';

  @override
  String formatRuntimeHours(int hours) {
    return '$hours h';
  }

  @override
  String formatRuntimeMinutes(String minutes) {
    return '$minutes min';
  }

  @override
  String formatRuntimeHoursMinutes(int hours, String minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get formatStateEnded => 'Finalizado';

  @override
  String get formatStateNext => 'Siguiente';

  @override
  String get formatStateLive => 'En vivo';

  @override
  String get formatStateNotStarted => 'No ha comenzado';

  @override
  String get formatGeoBlocked => 'Bloqueado por región';
}
