import 'dart:html' as html;

void toggleBrowserFullscreen() {
  if (html.document.fullscreenElement != null) {
    html.document.exitFullscreen();
  } else {
    html.document.documentElement?.requestFullscreen();
  }
}
