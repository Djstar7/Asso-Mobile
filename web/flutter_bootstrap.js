{{flutter_js}}
{{flutter_build_config}}

// CanvasKit est servi par l'application (canvaskit/, fourni par
// `flutter run` comme par `flutter build web`) plutôt que par le CDN
// gstatic : sur une connexion instable, son téléchargement échouait au
// démarrage (« Failed to fetch dynamically imported module … canvaskit.js »)
// et l'application restait blanche.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit/",
  },
});
