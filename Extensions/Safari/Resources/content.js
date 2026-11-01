/*
 * Safari content script. The DOM decisions live in engine.js.
 * One-line browser/chrome namespace guard:
 */
const browserAPI = globalThis.browser ?? globalThis.chrome;

(function () {
  if (!browserAPI || !browserAPI.runtime || !globalThis.TimePriceEngine) return;

  const EXTENSION_IDS = ["com.timeprice.ios.safari", "com.timeprice.mac.safari"];
  let config = null;
  let siteEnabled = true;
  let observer = null;
  let timer = null;

  function hostname() {
    try {
      return location.hostname || "";
    } catch (error) {
      return "";
    }
  }

  function requestNative(id) {
    return new Promise((resolve) => {
      try {
        browserAPI.runtime.sendNativeMessage(id, { type: "getConfig" }, (response) => {
          const lastError = browserAPI.runtime.lastError;
          if (lastError || !response) resolve(null);
          else resolve(response);
        });
      } catch (error) {
        resolve(null);
      }
    });
  }

  async function loadConfig() {
    const ids = [];
    if (browserAPI.runtime.id) ids.push(browserAPI.runtime.id);
    EXTENSION_IDS.forEach((id) => {
      if (!ids.includes(id)) ids.push(id);
    });
    for (const id of ids) {
      const response = await requestNative(id);
      if (response && response.netHourly) return response;
    }
    return null;
  }

  function loadSiteFlag() {
    const key = "site:" + hostname();
    return new Promise((resolve) => {
      try {
        browserAPI.storage.local.get([key], (items) => {
          const stored = items || {};
          if (Object.prototype.hasOwnProperty.call(stored, key)) resolve(stored[key] !== false);
          else resolve(true);
        });
      } catch (error) {
        resolve(true);
      }
    });
  }

  function runPass() {
    if (!config || siteEnabled === false) return;
    if (observer) observer.disconnect();
    try {
      globalThis.TimePriceEngine.annotateDocument(
        document,
        {
          netHourly: config.netHourly,
          currencyCode: config.currencyCode,
          enabled: config.enabled !== false && siteEnabled !== false,
        },
        location.href
      );
    } finally {
      if (observer && document.documentElement) {
        observer.observe(document.documentElement, { childList: true, subtree: true, characterData: true });
      }
    }
  }

  function schedule() {
    if (timer) clearTimeout(timer);
    timer = setTimeout(runPass, 200);
  }

  async function start() {
    if (window.top !== window) {
      const path = (location.pathname || "").toLowerCase();
      const host = (location.hostname || "").toLowerCase();
      if (path.includes("/payment") || path.includes("/checkout") || /pay|stripe|braintree|paypal/.test(host)) {
        return;
      }
    }
    config = await loadConfig();
    siteEnabled = await loadSiteFlag();
    if (!config) return;
    runPass();
    observer = new MutationObserver(() => schedule());
    if (document.documentElement) {
      observer.observe(document.documentElement, { childList: true, subtree: true, characterData: true });
    }
  }

  start();
})();
