'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "480604d69d2fcda3a1efb3cee9b864e7",
"assets/AssetManifest.bin.json": "bd7be72a2fcdb59a6a7151da6658dc26",
"assets/AssetManifest.json": "5d145885c213c3fa2a84aba753598967",
"assets/assets/images/2026.png": "ff663bdfafb52553dca650b22ed292be",
"assets/assets/images/analytics.png": "c350086f1eff4a347bc78f42e4a0bf80",
"assets/assets/images/business-presentation-template.png": "755594bf390ba101bc4afe1836ef4f7c",
"assets/assets/images/collaborations.png": "1c9d0eb3769f429a81a8cb5a0a50e667",
"assets/assets/images/consulting-contract-template.jpg": "49fe294c969486beefd8ad147cea13c2",
"assets/assets/images/content_library.png": "300a350f7ffae9071224f20af421d4b1",
"assets/assets/images/Dahboard.png": "b85097b4903b79765e1ddfeed0c2f580",
"assets/assets/images/f65f74_85875a9997aa4107b0ce9b656b80d19b~mv2%25201.png": "5b5c0913ea344bc478cebfc709805ceb",
"assets/assets/images/Global%2520BG.jpg": "0a594a6e4df047c48d89fe0cac3faf77",
"assets/assets/images/Image%2520(2).png": "3f30e2b4f9be15d983ba9fb789bcdf96",
"assets/assets/images/Khonology%2520Landing%2520Page%2520Animation%2520Frame%25201.jpg": "70ac6a457d555f6074b68526013ca3cc",
"assets/assets/images/LinkedIn%2520Social_Blue%2520Badge_White.png": "806d2b3f1b5fddd548ff08146d86781a",
"assets/assets/images/Logout_KhonoBuzz.png": "3700e843c87b140816aa543246772ae6",
"assets/assets/images/marketing-campaign-document-template.jpg": "dffb1d15b6f33af29308b0c16d20bee1",
"assets/assets/images/My_Proposals.png": "5cb494f69ac4370cd6994c3dc4209b4e",
"assets/assets/images/placeholder-logo.png": "95d8d1a4a9bbcccc875e2c381e74064a",
"assets/assets/images/placeholder.jpg": "1e533b7b4545d1d605144ce893afc601",
"assets/assets/images/service-agreement-contract-template.jpg": "4f79946f014e49184c3374b038f58c95",
"assets/assets/images/software-development-proposal-template.jpg": "1a3ed4647950e86573ee684c23caedd8",
"assets/assets/images/Time%2520Allocation_Approval_Blue.png": "ec1b9382e7dac508bae37f86639909a2",
"assets/assets/images/Upload_Arrow.png": "9b9bbfe4f85e159381ad3452f5b8757f",
"assets/assets/images/User_Profile.png": "0dd741d3d8d9703ec516eba7fc148d5f",
"assets/assets/images/web-development-scope-document.jpg": "83a6b925f86440c7c28fde9cbb857a7b",
"assets/assets/images/YouTube%2520Social_White%2520Badge_Blue.png": "1b6b6ac11f8946fe26c57c8558ddc9f9",
"assets/FontManifest.json": "7b2a36307916a9721811788013e65289",
"assets/fonts/MaterialIcons-Regular.otf": "fea291321a0af624271823df2a38da05",
"assets/NOTICES": "2f58904b2babda83aa0d5a5b96e61aa9",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"canvaskit/canvaskit.js": "140ccb7d34d0a55065fbd422b843add6",
"canvaskit/canvaskit.js.symbols": "58832fbed59e00d2190aa295c4d70360",
"canvaskit/canvaskit.wasm": "07b9f5853202304d3b0749d9306573cc",
"canvaskit/chromium/canvaskit.js": "5e27aae346eee469027c80af0751d53d",
"canvaskit/chromium/canvaskit.js.symbols": "193deaca1a1424049326d4a91ad1d88d",
"canvaskit/chromium/canvaskit.wasm": "24c77e750a7fa6d474198905249ff506",
"canvaskit/skwasm.js": "1ef3ea3a0fec4569e5d531da25f34095",
"canvaskit/skwasm.js.symbols": "0088242d10d7e7d6d2649d1fe1bda7c1",
"canvaskit/skwasm.wasm": "264db41426307cfc7fa44b95a7772109",
"canvaskit/skwasm_heavy.js": "413f5b2b2d9345f37de148e2544f584f",
"canvaskit/skwasm_heavy.js.symbols": "3c01ec03b5de6d62c34e17014d1decd3",
"canvaskit/skwasm_heavy.wasm": "8034ad26ba2485dab2fd49bdd786837b",
"firebase-config.js": "1da3e82d20ef2b5441d3bd37f62abb3b",
"flutter.js": "888483df48293866f9f41d3d9274a779",
"flutter_bootstrap.js": "3414a5c3619614b8c8658a0dbc9d277d",
"index.html": "6c900208200e59b5537a7ab9ddf78f22",
"/": "6c900208200e59b5537a7ab9ddf78f22",
"main.dart.js": "7e04dca3b3b6775056256181ca254328",
"verify.html": "2b7fb7e0b3d3fe135889a0aa6f428c80",
"version.json": "355ce9d696d8875d7e988c91c1915ca9"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
