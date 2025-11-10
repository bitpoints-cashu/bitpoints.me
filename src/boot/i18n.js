import { boot } from "quasar/wrappers";
import { createI18n } from "vue-i18n";
import messages from "src/i18n";
import { getActiveBrandId } from "src/utils/branding";

const brandDefaultLocales = {
  pandewaffle: "es-ES",
};

const availableLocales = Object.keys(messages);

function matchSupportedLocale(locale) {
  if (!locale) {
    return undefined;
  }
  if (availableLocales.includes(locale)) {
    return locale;
  }
  const base = locale.split("-")[0];
  return availableLocales.find((entry) => entry.startsWith(base));
}

function getStoredLocale() {
  try {
    return localStorage.getItem("cashu.language") || undefined;
  } catch (error) {
    return undefined;
  }
}

function resolveInitialLocale() {
  const stored = matchSupportedLocale(getStoredLocale());
  if (stored) {
    return stored;
  }

  const brand = getActiveBrandId();
  const brandDefault = matchSupportedLocale(brandDefaultLocales[brand]);
  if (brandDefault) {
    return brandDefault;
  }

  if (typeof navigator !== "undefined") {
    const browserLocale = matchSupportedLocale(navigator.language);
    if (browserLocale) {
      return browserLocale;
    }
  }

  return "en-US";
}

const initialLocale = resolveInitialLocale();

export const i18n = createI18n({
  locale: initialLocale,
  fallbackLocale: "en-US",
  globalInjection: true,
  messages,
});

export default boot(async ({ app }) => {
  app.use(i18n);
});
