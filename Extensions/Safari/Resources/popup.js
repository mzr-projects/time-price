const browserAPI = globalThis.browser ?? globalThis.chrome;

const EXTENSION_IDS = ["com.timeprice.ios.safari", "com.timeprice.mac.safari"];

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
  if (browserAPI.runtime && browserAPI.runtime.id) ids.push(browserAPI.runtime.id);
  EXTENSION_IDS.forEach((id) => {
    if (!ids.includes(id)) ids.push(id);
  });
  for (const id of ids) {
    const response = await requestNative(id);
    if (response && (response.netHourly || response.currencyCode)) return response;
  }
  return null;
}

function activeHost() {
  return new Promise((resolve) => {
    browserAPI.tabs.query({ active: true, currentWindow: true }, (tabs) => {
      const url = tabs && tabs[0] && tabs[0].url;
      if (!url) {
        resolve("");
        return;
      }
      try {
        resolve(new URL(url).hostname);
      } catch (error) {
        resolve("");
      }
    });
  });
}

function storageGet(key) {
  return new Promise((resolve) => {
    browserAPI.storage.local.get([key], (items) => resolve(items || {}));
  });
}

async function init() {
  const wage = document.getElementById("wage");
  const toggle = document.getElementById("site-enabled");
  const host = await activeHost();
  const key = "site:" + host;
  const config = await loadConfig();
  if (config && config.netHourly && config.currencyCode) {
    wage.textContent = config.netHourly + " " + config.currencyCode + " / hour";
  } else {
    wage.textContent = "Set a wage in the TimePrice app.";
  }
  const stored = await storageGet(key);
  const siteOn = !Object.prototype.hasOwnProperty.call(stored, key) || stored[key] !== false;
  toggle.checked = siteOn && (!config || config.enabled !== false);
  toggle.disabled = !host;
  toggle.addEventListener("change", () => {
    const value = {};
    value[key] = toggle.checked;
    browserAPI.storage.local.set(value);
  });
}

init();
