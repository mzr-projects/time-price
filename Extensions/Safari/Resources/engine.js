/*
 * TimePrice price engine.
 * Plain functions over a DOM-shaped document. Safari's content script and the Node tests
 * both call annotateDocument. This file does not touch browser.* or chrome.*.
 */
(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) {
    module.exports = api;
  }
  root.TimePriceEngine = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  const MAX_ANNOTATIONS = 150;
  const MAX_TEXT_NODES = 2000;
  const SKIP_TAGS = new Set([
    "SCRIPT",
    "STYLE",
    "NOSCRIPT",
    "TEXTAREA",
    "INPUT",
    "SELECT",
    "OPTION",
    "IFRAME",
    "CANVAS",
    "SVG",
    "HEAD",
    "TITLE",
    "META",
  ]);

  const AMAZON_SELECTORS = [
    ".a-price .a-offscreen",
    "#corePriceDisplay_desktop_feature_div",
    "#corePrice_feature_div",
    "#corePrice_desktop",
    "#newBuyBoxPrice",
    ".a-price",
  ];

  function shouldSkipURL(url) {
    if (!url) return false;
    let path = "";
    try {
      path = new URL(url, "https://timeprice.invalid").pathname.toLowerCase();
    } catch (error) {
      return false;
    }
    return path.includes("/checkout") || path.includes("/payment");
  }

  function formatMinutes(minutes) {
    const safe = Math.max(0, minutes | 0);
    const hours = Math.floor(safe / 60);
    const mins = safe % 60;
    if (hours === 0 && mins === 0) return "0 minutes";
    if (hours === 0 && mins === 1) return "1 minute";
    if (hours === 0) return mins + " minutes";
    if (hours === 1 && mins === 0) return "1 hour";
    if (hours === 1 && mins === 1) return "1 hour 1 minute";
    if (hours === 1) return "1 hour " + mins + " minutes";
    if (mins === 0) return hours + " hours";
    if (mins === 1) return hours + " hours 1 minute";
    return hours + " hours " + mins + " minutes";
  }

  function toScaled(str, scale) {
    if (typeof str !== "string" || str.length === 0) return null;
    const negative = str.charAt(0) === "-";
    const body = negative ? str.slice(1) : str;
    const pieces = body.split(".");
    if (pieces.length > 2) return null;
    const whole = pieces[0];
    const frac = pieces[1] || "";
    if (!/^\d+$/.test(whole) || (frac && !/^\d+$/.test(frac))) return null;
    const padded = (frac + "0".repeat(scale)).slice(0, scale);
    const extra = frac.slice(scale);
    let digits = (whole + padded).replace(/^0+(?=\d)/, "");
    if (digits.length === 0) digits = "0";
    let value = BigInt(digits);
    if (extra && extra[0] >= "5") value += 1n;
    return negative ? -value : value;
  }

  function roundDiv(numerator, denominator) {
    if (denominator === 0n) return null;
    const negative = numerator < 0n;
    const a = negative ? -numerator : numerator;
    const b = denominator < 0n ? -denominator : denominator;
    const quotient = a / b;
    const remainder = a % b;
    const rounded = remainder * 2n >= b ? quotient + 1n : quotient;
    return negative ? -rounded : rounded;
  }

  function minutesForPrice(priceStr, hourlyStr) {
    const scale = 8;
    const price = toScaled(priceStr, scale);
    const hourly = toScaled(hourlyStr, scale);
    if (price === null || hourly === null || hourly <= 0n || price < 0n) return null;
    const under30 = price * 3600n < hourly * 30n;
    const rounded = roundDiv(price * 60n, hourly);
    if (rounded === null) return null;
    let minutes = Number(rounded);
    if (!Number.isFinite(minutes)) return null;
    if (price > 0n && under30 && minutes < 1) minutes = 1;
    if (price === 0n) minutes = 0;
    return minutes;
  }

  function currencyFromSymbol(symbol) {
    switch (symbol.toUpperCase()) {
      case "$":
      case "US$":
      case "USD":
        return "USD";
      case "€":
      case "EUR":
        return "EUR";
      case "£":
      case "GBP":
        return "GBP";
      default:
        return null;
    }
  }

  function normalizeNumber(raw, currency) {
    const num = raw.trim();
    if (!/^\d[\d.,]*$/.test(num)) return null;
    const lastDot = num.lastIndexOf(".");
    const lastComma = num.lastIndexOf(",");
    let normalized;
    if (lastDot !== -1 && lastComma !== -1) {
      if (lastDot > lastComma) normalized = num.replace(/,/g, "");
      else normalized = num.replace(/\./g, "").replace(",", ".");
    } else if (lastComma !== -1) {
      const groups = num.split(",");
      const fractionLength = num.length - lastComma - 1;
      if (groups.length > 2 || fractionLength === 3) normalized = num.replace(/,/g, "");
      else if (fractionLength === 1 || fractionLength === 2) normalized = num.replace(",", ".");
      else return null;
    } else if (lastDot !== -1) {
      const groups = num.split(".");
      const fractionLength = num.length - lastDot - 1;
      if (groups.length > 2) {
        if (currency === "EUR" && groups.every((group, index) => (index === 0 ? group.length >= 1 && group.length <= 3 : group.length === 3))) {
          normalized = num.replace(/\./g, "");
        } else return null;
      } else if (fractionLength === 1 || fractionLength === 2) normalized = num;
      else if (fractionLength === 3 && currency === "EUR") normalized = num.replace(".", "");
      else return null;
    } else {
      normalized = num;
    }
    if (!/^\d+(\.\d{1,2})?$/.test(normalized)) return null;
    if (/^0\d/.test(normalized)) return null;
    return normalized;
  }

  function findMoneyMatches(text) {
    const matches = [];
    if (!text) return matches;
    const pattern = /(?:(USD|EUR|GBP|US\$|\$|€|£)\s*(\d[\d.,]*))|(?:(\d[\d.,]*)\s*(USD|EUR|GBP|US\$|\$|€|£))/gi;
    let match;
    while ((match = pattern.exec(text)) !== null) {
      const symbol = match[1] || match[4];
      const rawNumber = match[2] || match[3];
      const currency = currencyFromSymbol(symbol);
      if (!currency || !rawNumber) continue;
      const after = text.slice(match.index + match[0].length);
      if (/^\s*%/.test(after)) continue;
      const amount = normalizeNumber(rawNumber, currency);
      if (!amount) continue;
      matches.push({
        start: match.index,
        end: match.index + match[0].length,
        raw: match[0],
        amount: amount,
        currency: currency,
      });
    }
    return matches;
  }

  function parseMoneyToken(text) {
    const matches = findMoneyMatches(text);
    if (matches.length !== 1) return null;
    if (matches[0].raw.trim() !== String(text).trim() && matches[0].start !== 0) return matches[0];
    return matches[0];
  }

  function isEligible(element) {
    let node = element;
    while (node) {
      if (node.nodeType === 1) {
        if (SKIP_TAGS.has(node.tagName)) return false;
        const editable = (node.getAttribute && node.getAttribute("contenteditable") || "").toLowerCase();
        if (editable === "true") return false;
        if (node.getAttribute && node.getAttribute("data-timeprice") === "1") return false;
      }
      node = node.parentElement;
    }
    return true;
  }

  function alreadyAnnotated(element) {
    if (!element || element.nodeType !== 1) return true;
    if (element.getAttribute("data-timeprice") === "1") return true;
    if (typeof element.closest === "function" && element.closest("[data-timeprice]")) return true;
    if (typeof element.querySelector === "function" && element.querySelector("[data-timeprice]")) return true;
    return false;
  }

  function makeAnnotation(doc, hoursText, originalText) {
    const wrap = doc.createElement("span");
    wrap.setAttribute("data-timeprice", "1");
    wrap.setAttribute("data-original", originalText);
    wrap.setAttribute("aria-label", hoursText + ". Original price " + originalText);
    wrap.setAttribute("role", "text");
    wrap.classList.add("timeprice-annotation");

    const hours = doc.createElement("span");
    hours.classList.add("timeprice-hours");
    hours.textContent = hoursText;

    const original = doc.createElement("span");
    original.classList.add("timeprice-original");
    original.textContent = originalText;

    wrap.appendChild(hours);
    wrap.appendChild(original);
    return wrap;
  }

  function hoursTextFor(amount, currency, hourly, wageCurrency) {
    if (currency !== wageCurrency) return null;
    const minutes = minutesForPrice(amount, hourly);
    if (minutes === null) return null;
    return formatMinutes(minutes);
  }

  function priceHost(element) {
    if (element.matches && element.matches(".a-offscreen")) {
      const price = element.closest && element.closest(".a-price");
      if (price) return price;
    }
    return element;
  }

  function sourceText(element) {
    if (typeof element.querySelector === "function") {
      const offscreen = element.querySelector(".a-offscreen");
      if (offscreen && offscreen.textContent && offscreen.textContent.trim()) {
        return offscreen.textContent.trim();
      }
    }
    return (element.textContent || "").trim();
  }

  function annotateElement(element, hourly, wageCurrency) {
    const host = priceHost(element);
    if (!host || alreadyAnnotated(host) || !isEligible(host)) return false;
    const source = sourceText(host);
    const matches = findMoneyMatches(source);
    const match = matches.find((item) => item.currency === wageCurrency);
    if (!match) return false;
    const hoursText = hoursTextFor(match.amount, match.currency, hourly, wageCurrency);
    if (!hoursText) return false;
    const doc = host.ownerDocument || host;
    const original = match.raw.trim();
    host.textContent = "";
    host.appendChild(makeAnnotation(doc, hoursText, original));
    return true;
  }

  function replaceTextNode(textNode, hourly, wageCurrency) {
    const parent = textNode.parentElement;
    if (!parent || !isEligible(parent) || alreadyAnnotated(parent)) return 0;
    const raw = textNode.data || "";
    const matches = findMoneyMatches(raw);
    if (matches.length === 0) return 0;
    const doc = parent.ownerDocument || parent;
    const pieces = [];
    let cursor = 0;
    let count = 0;
    matches.forEach((match) => {
      if (cursor < match.start) {
        pieces.push(doc.createTextNode(raw.slice(cursor, match.start)));
      }
      const hoursText = hoursTextFor(match.amount, match.currency, hourly, wageCurrency);
      if (!hoursText) {
        pieces.push(doc.createTextNode(raw.slice(match.start, match.end)));
      } else {
        pieces.push(makeAnnotation(doc, hoursText, match.raw.trim()));
        count += 1;
      }
      cursor = match.end;
    });
    if (cursor < raw.length) pieces.push(doc.createTextNode(raw.slice(cursor)));
    if (count === 0) return 0;
    if (typeof parent.replaceChild === "function") {
      const first = pieces[0];
      parent.replaceChild(first, textNode);
      let after = first;
      for (let index = 1; index < pieces.length; index += 1) {
        if (after.nextSibling) parent.insertBefore(pieces[index], after.nextSibling);
        else parent.appendChild(pieces[index]);
        after = pieces[index];
      }
    }
    return count;
  }

  function collectTextNodes(node, out, state) {
    const children = node.childNodes || [];
    for (let index = 0; index < children.length; index += 1) {
      if (state.visited >= MAX_TEXT_NODES) {
        state.capped = true;
        return;
      }
      const child = children[index];
      state.visited += 1;
      if (child.nodeType === 3) {
        if (child.parentElement && isEligible(child.parentElement)) out.push(child);
      } else if (child.nodeType === 1) {
        if (!isEligible(child)) continue;
        collectTextNodes(child, out, state);
      }
    }
  }

  function readStructuredPrices(doc) {
    const found = [];
    if (!doc.querySelectorAll) return found;
    const scripts = doc.querySelectorAll('script[type="application/ld+json"]');
    scripts.forEach((script) => {
      try {
        collectStructured(JSON.parse(script.textContent || ""), found);
      } catch (error) {
        /* Broken JSON-LD is ignored. Visible prices still use their own symbols. */
      }
    });
    const priceMetas = doc.querySelectorAll("meta[itemprop=price]");
    const currencyMeta = doc.querySelector("meta[itemprop=priceCurrency]");
    const currency = currencyMeta ? currencyFromSymbol(currencyMeta.getAttribute("content") || "") : null;
    priceMetas.forEach((meta) => {
      const content = meta.getAttribute("content") || "";
      const amount = normalizeNumber(content, currency || "USD");
      if (amount && currency) found.push({ amount: amount, currency: currency });
    });
    return found;
  }

  function collectStructured(value, found) {
    if (!value || typeof value !== "object") return;
    if (Array.isArray(value)) {
      value.forEach((item) => collectStructured(item, found));
      return;
    }
    const typeValue = value["@type"];
    const types = Array.isArray(typeValue) ? typeValue : [typeValue];
    const interesting = types.some((type) => type === "Product" || type === "Offer" || type === "AggregateOffer");
    if (interesting && value.price != null && value.priceCurrency) {
      const currency = currencyFromSymbol(String(value.priceCurrency));
      const amount = typeof value.price === "number" ? value.price.toFixed(2) : normalizeNumber(String(value.price), currency || "USD");
      if (currency && amount) found.push({ amount: amount, currency: currency });
    }
    if (value.offers) collectStructured(value.offers, found);
    if (value["@graph"]) collectStructured(value["@graph"], found);
  }

  function annotateBareStructured(element, structured, hourly, wageCurrency) {
    if (!element || alreadyAnnotated(element) || !isEligible(element)) return false;
    const text = (element.textContent || "").trim();
    if (!text || text.length > 40) return false;
    const hit = structured.find((item) => item.currency === wageCurrency && (item.amount === text || item.amount === normalizeNumber(text, wageCurrency)));
    if (!hit) return false;
    const hoursText = hoursTextFor(hit.amount, hit.currency, hourly, wageCurrency);
    if (!hoursText) return false;
    const doc = element.ownerDocument || element;
    element.textContent = "";
    element.appendChild(makeAnnotation(doc, hoursText, text));
    return true;
  }

  function annotateDocument(doc, config, url) {
    const result = { annotated: 0, skippedURL: false, capped: false, disabled: false };
    if (!config || config.enabled === false || !config.netHourly || !config.currencyCode) {
      result.disabled = true;
      return result;
    }
    const hourly = String(config.netHourly);
    if (toScaled(hourly, 8) === null || toScaled(hourly, 8) <= 0n) {
      result.disabled = true;
      return result;
    }
    if (shouldSkipURL(url)) {
      result.skippedURL = true;
      return result;
    }
    const wageCurrency = String(config.currencyCode).toUpperCase();
    const structured = readStructuredPrices(doc);

    for (let selectorIndex = 0; selectorIndex < AMAZON_SELECTORS.length; selectorIndex += 1) {
      if (result.annotated >= MAX_ANNOTATIONS) {
        result.capped = true;
        break;
      }
      const nodes = doc.querySelectorAll ? doc.querySelectorAll(AMAZON_SELECTORS[selectorIndex]) : [];
      for (let nodeIndex = 0; nodeIndex < nodes.length; nodeIndex += 1) {
        if (result.annotated >= MAX_ANNOTATIONS) {
          result.capped = true;
          break;
        }
        if (annotateElement(nodes[nodeIndex], hourly, wageCurrency)) result.annotated += 1;
      }
    }

    const state = { visited: 0, capped: false };
    const texts = [];
    collectTextNodes(doc, texts, state);
    if (state.capped) result.capped = true;
    for (let index = 0; index < texts.length; index += 1) {
      if (result.annotated >= MAX_ANNOTATIONS) {
        result.capped = true;
        break;
      }
      const added = replaceTextNode(texts[index], hourly, wageCurrency);
      result.annotated += added;
    }

    if (structured.length && doc.querySelectorAll) {
      const candidates = doc.querySelectorAll("span, div, p, b, strong, em");
      for (let index = 0; index < candidates.length; index += 1) {
        if (result.annotated >= MAX_ANNOTATIONS) {
          result.capped = true;
          break;
        }
        if (annotateBareStructured(candidates[index], structured, hourly, wageCurrency)) {
          result.annotated += 1;
        }
      }
    }
    return result;
  }

  return {
    annotateDocument: annotateDocument,
    shouldSkipURL: shouldSkipURL,
    formatMinutes: formatMinutes,
    findMoneyMatches: findMoneyMatches,
    parseMoneyToken: parseMoneyToken,
    minutesForPrice: minutesForPrice,
    MAX_ANNOTATIONS: MAX_ANNOTATIONS,
  };
});
