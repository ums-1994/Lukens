'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "c085e5044a7e52b1b5883e76f141edb7",
"assets/AssetManifest.bin.json": "cc4aace9dc6088de823e01ae4d43780a",
"assets/AssetManifest.json": "95827f4d02b86cd4bf07b85695b2cf38",
"assets/assets/fonts/poppins/Poppins-Black.ttf": "14d00dab1f6802e787183ecab5cce85e",
"assets/assets/fonts/poppins/Poppins-BlackItalic.ttf": "e9c5c588e39d0765d30bcd6594734102",
"assets/assets/fonts/poppins/Poppins-Bold.ttf": "08c20a487911694291bd8c5de41315ad",
"assets/assets/fonts/poppins/Poppins-BoldItalic.ttf": "19406f767addf00d2ea82cdc9ab104ce",
"assets/assets/fonts/poppins/Poppins-ExtraBold.ttf": "d45bdbc2d4a98c1ecb17821a1dbbd3a4",
"assets/assets/fonts/poppins/Poppins-ExtraBoldItalic.ttf": "8afe4dc13b83b66fec0ea671419954cc",
"assets/assets/fonts/poppins/Poppins-ExtraLight.ttf": "6f8391bbdaeaa540388796c858dfd8ca",
"assets/assets/fonts/poppins/Poppins-ExtraLightItalic.ttf": "a9bed017984a258097841902b696a7a6",
"assets/assets/fonts/poppins/Poppins-Italic.ttf": "c1034239929f4651cc17d09ed3a28c69",
"assets/assets/fonts/poppins/Poppins-Light.ttf": "fcc40ae9a542d001971e53eaed948410",
"assets/assets/fonts/poppins/Poppins-LightItalic.ttf": "0613c488cf7911af70db821bdd05dfc4",
"assets/assets/fonts/poppins/Poppins-Medium.ttf": "bf59c687bc6d3a70204d3944082c5cc0",
"assets/assets/fonts/poppins/Poppins-MediumItalic.ttf": "cf5ba39d9ac24652e25df8c291121506",
"assets/assets/fonts/poppins/Poppins-Regular.ttf": "093ee89be9ede30383f39a899c485a82",
"assets/assets/fonts/poppins/Poppins-SemiBold.ttf": "6f1520d107205975713ba09df778f93f",
"assets/assets/fonts/poppins/Poppins-SemiBoldItalic.ttf": "9841f3d906521f7479a5ba70612aa8c8",
"assets/assets/fonts/poppins/Poppins-Thin.ttf": "9ec263601ee3fcd71763941207c9ad0d",
"assets/assets/fonts/poppins/Poppins-ThinItalic.ttf": "01555d25092b213d2ea3a982123722c9",
"assets/assets/images/2026.png": "ff663bdfafb52553dca650b22ed292be",
"assets/assets/images/account_icon.png": "75147600bc3c768a8267f7e5e6771e0a",
"assets/assets/images/allocation.png": "8f6c88f798b2a7cc9d189e7e890c0837",
"assets/assets/images/analytics.png": "c350086f1eff4a347bc78f42e4a0bf80",
"assets/assets/images/animated_rocket.mp4": "8c8e2289d0aeae62e3fd7d949f582944",
"assets/assets/images/business-presentation-template.png": "755594bf390ba101bc4afe1836ef4f7c",
"assets/assets/images/Chatbot_Red.png": "c9ac98884d2ba457159993bd4427cc2a",
"assets/assets/images/chat_bot.png": "4dce2e6f60fc923631065f65b392df03",
"assets/assets/images/collaborations.png": "1c9d0eb3769f429a81a8cb5a0a50e667",
"assets/assets/images/consulting-contract-template.jpg": "49fe294c969486beefd8ad147cea13c2",
"assets/assets/images/content_library.png": "300a350f7ffae9071224f20af421d4b1",
"assets/assets/images/Dahboard.png": "b85097b4903b79765e1ddfeed0c2f580",
"assets/assets/images/discs.png": "74c8c9cab1251333cc35d016e58f33cb",
"assets/assets/images/f65f74_85875a9997aa4107b0ce9b656b80d19b~mv2%25201.png": "5b5c0913ea344bc478cebfc709805ceb",
"assets/assets/images/Image%2520(2).png": "3f30e2b4f9be15d983ba9fb789bcdf96",
"assets/assets/images/khono.png": "a71298a29c3d7794173d28e6e1a8825c",
"assets/assets/images/Khonology%2520Landing%2520Page%2520Animation%2520Frame%25201.jpg": "70ac6a457d555f6074b68526013ca3cc",
"assets/assets/images/LinkedIn%2520Social_Blue%2520Badge_White.png": "806d2b3f1b5fddd548ff08146d86781a",
"assets/assets/images/logo.png": "4e75dc863ccd5c642bb7634e5cef48be",
"assets/assets/images/logout.png": "54f4cc0b891b0e0ffc40296b963841ac",
"assets/assets/images/Logout_KhonoBuzz.png": "3700e843c87b140816aa543246772ae6",
"assets/assets/images/marketing-campaign-document-template.jpg": "dffb1d15b6f33af29308b0c16d20bee1",
"assets/assets/images/My_Proposals.png": "5cb494f69ac4370cd6994c3dc4209b4e",
"assets/assets/images/nathi.png": "f430380cb1fd87043135b6bb5824ab05",
"assets/assets/images/Niice_Wrld_A_dark,_abstract_background_with_a_black_background_and_a_red_lin_5c0b8290-cc74-4ad3-97c2-749fd1c67f0d.png": "d047839e6c3f8f33fb58873e39408cff",
"assets/assets/images/Niice_Wrld_A_dark,_abstract_background_with_a_black_background_and_a_red_lin_b046274a-c476-47f4-a694-8922c528f1a7.png": "91b0aeb0033b6ad0bc30f13877925f54",
"assets/assets/images/Niice_Wrld_A_dark,_abstract_background_with_a_black_background_and_a_red_lin_d01634f9-4139-422b-9c26-4428435ea403.png": "426f28e57208b850e0447918eaac109b",
"assets/assets/images/placeholder-logo.png": "95d8d1a4a9bbcccc875e2c381e74064a",
"assets/assets/images/placeholder.jpg": "1e533b7b4545d1d605144ce893afc601",
"assets/assets/images/project_data.png": "5cb494f69ac4370cd6994c3dc4209b4e",
"assets/assets/images/rokects.png": "077c2680557e9387b3433007dccee1e5",
"assets/assets/images/service-agreement-contract-template.jpg": "4f79946f014e49184c3374b038f58c95",
"assets/assets/images/software-development-proposal-template.jpg": "1a3ed4647950e86573ee684c23caedd8",
"assets/assets/images/Time%2520Allocation_Approval_Blue.png": "ec1b9382e7dac508bae37f86639909a2",
"assets/assets/images/Time_keeping.png": "70bf1abdcd7fb17501ef4342a4e1c7c1",
"assets/assets/images/Upload_Arrow.png": "9b9bbfe4f85e159381ad3452f5b8757f",
"assets/assets/images/User_Profile.png": "0dd741d3d8d9703ec516eba7fc148d5f",
"assets/assets/images/web-development-scope-document.jpg": "83a6b925f86440c7c28fde9cbb857a7b",
"assets/assets/images/YouTube%2520Social_White%2520Badge_Blue.png": "1b6b6ac11f8946fe26c57c8558ddc9f9",
"assets/FontManifest.json": "8a5950adae6d26a7179cc653b4ee5bcf",
"assets/fonts/MaterialIcons-Regular.otf": "d59141cae153e33565fcdd93b5a77922",
"assets/NOTICES": "ddf1513a073dde5fcdc7e320f404c4fb",
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
"flutter_bootstrap.js": "fdfca61d42a488b172f1fc33788ac77f",
"index.html": "6c900208200e59b5537a7ab9ddf78f22",
"/": "6c900208200e59b5537a7ab9ddf78f22",
"main.dart.js": "3a8f64700ff8d284e0fa8397f9f57e45",
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
