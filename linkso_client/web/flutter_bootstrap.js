{{flutter_js}}
{{flutter_build_config}}

// Nginx controls HTTP caching; do not erase browser caches on each launch.
// HTTP origins cannot enable cross-origin isolation, so use single-threaded
// SkWasm there. HTTPS automatically gains multi-threading when the server
// supplies the required isolation headers.
_flutter.loader.load({
  config: {
    forceSingleThreadedSkwasm: !window.crossOriginIsolated,
  },
});
