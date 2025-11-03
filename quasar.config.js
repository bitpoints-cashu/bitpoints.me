/* eslint-env node */

/*
 * This file runs in a Node context (it's NOT transpiled by Babel), so use only
 * the ES6 features that are supported by your Node version. https://node.green/
 */

// Configuration for your app
// https://v2.quasar.dev/quasar-cli-vite/quasar-config-js

const { configure } = require("quasar/wrappers");
const { execSync } = require("child_process");
const path = require("path");

function resolveGitCommit() {
  try {
    return execSync("git describe --always --dirty", {
      cwd: __dirname,
      stdio: "pipe",
    })
      .toString()
      .trim();
  } catch (err) {
    console.warn("Unable to resolve git commit via `git describe`");
    return "unknown";
  }
}

// Get active brand from environment or default to bitpoints
function getActiveBrandId() {
  return process.env.BRAND || "bitpoints";
}

// Load brand configuration
function getBrandConfig(brandId) {
  try {
    // In Node.js context, we can't use TypeScript directly
    // So we'll use a JSON file or require the compiled JS
    // For now, we'll inline the brand configs here for build-time use
    const brands = {
      bitpoints: {
        id: "bitpoints",
        name: "Bitpoints.me",
        shortName: "Bitpoints",
        domain: "bitpoints.me",
        logoPath: "bitpoints-logo.png",
        logoAlt: "Bitpoints",
        iconPath: "icon.png", // Root icon.png for all platforms
        colors: {
          primary: "#ff6b35",
          secondary: "#6b4fbb",
          accent: "#ff8c42",
          background: "#fffef7",
          text: "#1a1a1a",
          theme: "#6B4FBB",
        },
        description:
          "Bitcoin-backed rewards that appreciate over time. Powered by Cashu ecash, Nostr identity, and Bluetooth mesh.",
        themeColor: "#6B4FBB",
      },
      trails: {
        id: "trails",
        name: "Trails Coffee Points",
        shortName: "Trails Points",
        domain: "points.trailscoffee.com",
        logoPath: "trails-logo.png",
        logoAlt: "Trails Coffee",
        iconPath: "src/assets/brands/trails/trails-iso.png", // Trails coffee icon for PWA
        colors: {
          primary: "#8B4513",
          secondary: "#D2691E",
          accent: "#CD853F",
          background: "#FFF8DC",
          text: "#3E2723",
          theme: "#6F4E37",
        },
        description:
          "Rewards points powered by Bitcoin. Earn, send, and receive points with Trails Coffee.",
        themeColor: "#6F4E37",
      },
    };

    return brands[brandId] || brands.bitpoints;
  } catch (err) {
    console.warn(`Failed to load brand config for ${brandId}, using bitpoints`);
    return brands.bitpoints;
  }
}

module.exports = configure(function (ctx) {
  // Get active brand for this build
  const activeBrandId = getActiveBrandId();
  const brandConfig = getBrandConfig(activeBrandId);

  console.log(`🏷️  Building for brand: ${brandConfig.name} (${activeBrandId})`);

  // Determine brand-specific CSS file
  const brandCssFile = `brands/${activeBrandId}.scss`;

  // For PWA builds, set brand-specific output directory
  let distDir = undefined;
  if (ctx.mode.pwa) {
    distDir = path.resolve(__dirname, `dist/pwa/${activeBrandId}`);
  }

  return {
    eslint: {
      // fix: true,
      // include: [],
      // exclude: [],
      // rawOptions: {},
      warnings: true,
      errors: true,
    },

    // https://v2.quasar.dev/quasar-cli/prefetch-feature
    // preFetch: true,

    // app boot file (/src/boot)
    // --> boot files are part of "main.js"
    // https://v2.quasar.dev/quasar-cli/boot-files
    boot: ["base", "global-components", "cashu", "i18n"],

    // https://v2.quasar.dev/quasar-cli-vite/quasar-config-js#css
    css: ["app.scss", "base.scss", brandCssFile],

    // https://github.com/quasarframework/quasar/tree/dev/extras
    extras: [
      // 'ionicons-v4',
      // 'mdi-v5',
      // 'fontawesome-v6',
      // 'eva-icons',
      // 'themify',
      // 'line-awesome',
      // 'roboto-font-latin-ext', // this or either 'roboto-font', NEVER both!

      "roboto-font", // optional, you are not bound to it
      "material-icons", // optional, you are not bound to it
      ,
    ],

    // Full list of options: https://v2.quasar.dev/quasar-cli-vite/quasar-config-js#build
    build: {
      target: {
        browser: ["esnext"],
        node: "node16",
      },

      vueRouterMode: "history", // available values: 'hash', 'history'
      // vueRouterBase,
      // vueDevtools,
      // vueOptionsAPI: false,

      // rebuildCache: true, // rebuilds Vite/linter/etc cache on startup

      // publicPath: '/',
      // analyze: true,
      // env: {},
      // rawDefine: {}
      // ignorePublicFolder: true,
      // minify: false,
      // polyfillModulePreload: true,
      distDir: distDir,

      extendViteConf(viteConf) {
        viteConf.define = viteConf.define || {};
        viteConf.define.GIT_COMMIT = JSON.stringify(resolveGitCommit());

        // Inject brand configuration into build as global constants
        // Vite define replaces these at build time, so they'll be literal strings
        viteConf.define.__BRAND_ID__ = JSON.stringify(activeBrandId);
        viteConf.define.__BRAND_CONFIG__ = JSON.stringify(brandConfig);

        // Add custom plugin to transform index.html with brand values
        // This runs after Quasar's template processing
        if (!viteConf.plugins) {
          viteConf.plugins = [];
        }

        viteConf.plugins.push({
          name: "brand-html-transform",
          transformIndexHtml: {
            enforce: "post",
            transform(html) {
              // Replace productName and productDescription from package.json with brand values
              // This happens after Quasar processes the template
              const packageJson = require("./package.json");
              const defaultProductName = packageJson.productName;
              const defaultDescription = packageJson.description;

              return (
                html
                  // Replace title (uses productName from package.json)
                  .replace(
                    new RegExp(defaultProductName, "g"),
                    brandConfig.name
                  )
                  // Replace description (uses productDescription from package.json)
                  .replace(
                    new RegExp(
                      defaultDescription.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"),
                      "g"
                    ),
                    brandConfig.description
                  )
                  // Replace OpenGraph and meta tags
                  .replace(/Bitpoints\.me/g, brandConfig.name)
                  .replace(
                    /Bitpoints\.me - Bitcoin-backed Rewards/g,
                    `${brandConfig.name} - ${brandConfig.shortName}`
                  )
                  .replace(
                    /Rewards that appreciate over time\. Powered by Cashu ecash, Nostr identity, and Bluetooth mesh\./g,
                    brandConfig.description
                  )
                  .replace(
                    /https:\/\/bitpoints\.me/g,
                    `https://${brandConfig.domain}`
                  )
              );
            },
          },
        });

        // Wear OS specific configuration
        if (process.env.CAPACITOR_TARGET === "wear") {
          viteConf.define.WEAR_OS = JSON.stringify(true);
          viteConf.define.IS_WATCH = JSON.stringify(true);
        }
      },
      // viteVuePluginOptions: {},

      // vitePlugins: [
      //   [ 'package-name', { ..options.. } ]
      // ]
    },

    // Full list of options: https://v2.quasar.dev/quasar-cli-vite/quasar-config-js#devServer
    devServer: {
      https: false,
      open: true, // opens browser window automatically
      port: 8080,
    },

    // https://v2.quasar.dev/quasar-cli-vite/quasar-config-js#framework
    framework: {
      config: {},

      iconSet: "material-icons", // Quasar icon set
      // lang: 'en-US', // Quasar language pack

      // For special cases outside of where the auto-import strategy can have an impact
      // (like functional components as one of the examples),
      // you can manually specify Quasar components/directives to be available everywhere:
      //
      // components: [],
      // directives: [],

      // Quasar plugins
      plugins: ["LocalStorage", "Notify"],
    },

    animations: "all", // --- includes all animations
    // https://v2.quasar.dev/options/animations
    // animations: [],

    // https://v2.quasar.dev/quasar-cli-vite/quasar-config-js#property-sourcefiles
    // sourceFiles: {
    //   rootComponent: 'src/App.vue',
    //   router: 'src/router/index',
    //   store: 'src/store/index',
    //   registerServiceWorker: 'src-pwa/register-service-worker',
    //   serviceWorker: 'src-pwa/custom-service-worker',
    //   pwaManifestFile: 'src-pwa/manifest.json',
    //   electronMain: 'src-electron/electron-main',
    //   electronPreload: 'src-electron/electron-preload'
    // },

    // https://v2.quasar.dev/quasar-cli/developing-ssr/configuring-ssr
    ssr: {
      // ssrPwaHtmlFilename: 'offline.html', // do NOT use index.html as name!
      // will mess up SSR

      // extendSSRWebserverConf (esbuildConf) {},
      // extendPackageJson (json) {},

      pwa: false,

      // manualStoreHydration: true,
      // manualPostHydrationTrigger: true,

      prodPort: 3000, // The default port that the production server should use
      // (gets superseded if process.env.PORT is specified at runtime)

      middlewares: [
        "render", // keep this as last one
      ],
    },

    // https://v2.quasar.dev/quasar-cli/developing-pwa/configuring-pwa
    pwa: {
      workboxMode: "generateSW", // or 'injectManifest'
      injectPwaMetaTags: true,
      swFilename: "sw.js",
      manifestFilename: "manifest.json",
      useCredentialsForManifestTag: false,
      workboxOptions: {
        skipWaiting: true,
        clientsClaim: true,
      },
      // useFilenameHashes: true,
      // extendGenerateSWOptions (cfg) {}
      // extendInjectManifestOptions (cfg) {},
      extendManifestJson(json) {
        // Update manifest with brand-specific values
        json.name = brandConfig.name;
        json.short_name = brandConfig.shortName;
        json.description = brandConfig.description;
        json.theme_color = brandConfig.themeColor;
        json.background_color = brandConfig.colors.background;

        // Note: Icons should be generated separately based on brand
        // For trails brand, use trails-iso.png; for bitpoints, use icon.png
        // Icon paths in manifest should point to public/icons/icon-*.png
        // The actual icon files should be generated before build based on brandConfig.iconPath
      },
      // Override productName and productDescription for index.html template
      // Note: These come from package.json but we transform them in HTML after processing
      // extendPWACustomSWConf (esbuildConf) {}
    },

    // Full list of options: https://v2.quasar.dev/quasar-cli/developing-cordova-apps/configuring-cordova
    cordova: {
      // noIosLegacyBuildFlag: true, // uncomment only if you know what you are doing
    },

    // Full list of options: https://v2.quasar.dev/quasar-cli/developing-capacitor-apps/configuring-capacitor
    capacitor: {
      hideSplashscreen: false,

      // Wear OS specific configuration
      android: {
        path:
          process.env.CAPACITOR_TARGET === "wear" ? "android/wear" : "android",
      },
    },

    // Full list of options: https://v2.quasar.dev/quasar-cli/developing-electron-apps/configuring-electron
    electron: {
      // extendElectronMainConf (esbuildConf)
      // extendElectronPreloadConf (esbuildConf)

      inspectPort: 5858,

      bundler: "packager", // 'packager' or 'builder'

      packager: {
        // https://github.com/electron-userland/electron-packager/blob/master/docs/api.md#options
        // OS X / Mac App Store
        // appBundleId: '',
        // appCategoryType: '',
        // osxSign: '',
        // protocol: 'myapp://path',
        // Windows only
        // win32metadata: { ... }
        asar: true,
        prune: true,
        ignore: [
          /(^|[\\/])node_modules([\\/]|$)/,
          /(^|[\\/])screenshots([\\/]|$)/,
          /(^|[\\/])package-lock\.json$/,
          /(^|[\\/])yarn\.lock$/,
          /(^|[\\/])pnpm-lock\.yaml$/,
          /(^|[\\/])vitest\.config\.js$/,
          /(^|[\\/])test([\\/]|$)/,
        ],
      },

      builder: {
        // https://www.electron.build/configuration/configuration

        appId: "me.cashu",
      },
    },

    // Full list of options: https://v2.quasar.dev/quasar-cli-vite/developing-browser-extensions/configuring-bex
    bex: {
      contentScripts: ["my-content-script"],

      // extendBexScriptsConf (esbuildConf) {}
      // extendBexManifestJson (json) {}
    },
  };
});
