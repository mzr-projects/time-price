"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const engine = require("../Extensions/Safari/Resources/engine.js");
const { parseHTML } = require("./mini-dom.js");

const fixtures = path.join(__dirname, "fixtures");

function read(name) {
  return fs.readFileSync(path.join(fixtures, name), "utf8");
}

function usd(hourly = "30") {
  return { netHourly: hourly, currencyCode: "USD", enabled: true };
}

test("formats the spec examples and the one-minute minimum", () => {
  assert.equal(engine.formatMinutes(engine.minutesForPrice("15", "30")), "30 minutes");
  assert.equal(engine.formatMinutes(engine.minutesForPrice("30", "30")), "1 hour");
  assert.equal(engine.formatMinutes(engine.minutesForPrice("45", "30")), "1 hour 30 minutes");
  assert.equal(engine.formatMinutes(engine.minutesForPrice("135", "30")), "4 hours 30 minutes");
  assert.equal(engine.formatMinutes(engine.minutesForPrice("0.01", "10000")), "1 minute");
  assert.equal(engine.formatMinutes(engine.minutesForPrice("0", "30")), "0 minutes");
  assert.equal(engine.formatMinutes(engine.minutesForPrice("90", "3600")), "2 minutes");
});

test("parses US and European amounts", () => {
  assert.equal(engine.parseMoneyToken("$1,299.00").amount, "1299.00");
  assert.equal(engine.parseMoneyToken("$1,299.00").currency, "USD");
  assert.equal(engine.parseMoneyToken("1.299,00 €").amount, "1299.00");
  assert.equal(engine.parseMoneyToken("1.299,00 €").currency, "EUR");
  assert.equal(engine.parseMoneyToken("€12,50").amount, "12.50");
  assert.equal(engine.parseMoneyToken("£9.99").currency, "GBP");
  assert.equal(engine.parseMoneyToken("2024"), null);
  assert.equal(engine.parseMoneyToken("20%"), null);
  assert.equal(engine.parseMoneyToken("(415) 555-2671"), null);
  assert.equal(engine.parseMoneyToken("Order #104938275610"), null);
});

test("amazon buy box keeps the original price and shows hours once", () => {
  const doc = parseHTML(read("amazon-buy-box.html"));
  const result = engine.annotateDocument(doc, usd("30"), "https://www.amazon.com/dp/B00TEST");
  assert.equal(result.annotated, 1);
  const marks = doc.querySelectorAll("[data-timeprice]");
  assert.equal(marks.length, 1);
  assert.equal(marks[0].getAttribute("data-original"), "$29.99");
  assert.match(marks[0].getAttribute("aria-label"), /\$29\.99/);
  assert.equal(doc.querySelector(".timeprice-original").textContent, "$29.99");
  assert.equal(doc.querySelector(".timeprice-hours").textContent, "1 hour");
  assert.equal(doc.querySelectorAll(".timeprice-hours").length, 1);
  const scriptless = doc.querySelector("#corePriceDisplay_desktop_feature_div").textContent;
  assert.equal(scriptless.match(/1 hour/g).length, 1);
});

test("json-ld product price is annotated from the visible price", () => {
  const doc = parseHTML(read("jsonld-product.html"));
  const before = doc.querySelector("script").textContent;
  const result = engine.annotateDocument(doc, usd("24"), "https://shop.example/mug");
  assert.equal(result.annotated, 1);
  assert.equal(doc.querySelector(".timeprice-hours").textContent, "1 hour");
  assert.equal(doc.querySelector(".timeprice-original").textContent, "$24.00");
  assert.equal(doc.querySelector("script").textContent, before);
});

test("meta itemprop and bare JSON-LD amount use the structured currency", () => {
  const meta = parseHTML(`
    <meta itemprop="price" content="15.00">
    <meta itemprop="priceCurrency" content="USD">
    <span class="meta-price">15.00</span>
  `);
  engine.annotateDocument(meta, usd("30"), "https://shop.example/item");
  assert.equal(meta.querySelector(".timeprice-hours").textContent, "30 minutes");
  assert.equal(meta.querySelector("[data-original]").getAttribute("data-original"), "15.00");

  const bare = parseHTML(`
    <script type="application/ld+json">{"@type":"Product","offers":{"@type":"Offer","price":"24.00","priceCurrency":"EUR"}}</script>
    <span class="only">24.00</span>
  `);
  const skipped = engine.annotateDocument(bare, usd("24"), "https://shop.example/item");
  assert.equal(skipped.annotated, 0);
  assert.equal(bare.querySelector(".only").textContent.trim(), "24.00");
  assert.equal(bare.querySelector("[data-timeprice]"), null);
});

test("US and European amounts annotate only in the wage currency", () => {
  const dollars = parseHTML(read("amounts.html"));
  engine.annotateDocument(dollars, usd("30"), "https://shop.example/list");
  assert.equal(dollars.querySelector(".us .timeprice-hours").textContent, "43 hours 18 minutes");
  assert.equal(dollars.querySelector(".eu").textContent.trim(), "1.299,00 €");
  assert.equal(dollars.querySelector(".gbp").textContent.trim(), "£9.99");
  assert.equal(dollars.querySelector(".euro-prefix").textContent.trim(), "€12,50");
  assert.equal(dollars.querySelector(".eu [data-timeprice]"), null);

  const euros = parseHTML(read("amounts.html"));
  engine.annotateDocument(euros, { netHourly: "30", currencyCode: "EUR", enabled: true }, "https://shop.example/list");
  assert.equal(euros.querySelector(".eu .timeprice-hours").textContent, "43 hours 18 minutes");
  assert.equal(euros.querySelector(".us").textContent.trim(), "$1,299.00");
  assert.equal(euros.querySelector(".euro-prefix .timeprice-original").textContent, "€12,50");
});

test("does not convert a mismatched currency", () => {
  const doc = parseHTML("<p>€19,50</p>");
  const result = engine.annotateDocument(doc, usd("20"), "https://shop.example/eu");
  assert.equal(result.annotated, 0);
  assert.equal(doc.querySelector("p").textContent.trim(), "€19,50");
  assert.equal(doc.querySelector("[data-timeprice]"), null);
});

test("ignores years, order ids, percentages, and phone numbers", () => {
  const doc = parseHTML(read("ignore.html"));
  const result = engine.annotateDocument(doc, usd("20"), "https://shop.example/about");
  assert.equal(result.annotated, 1);
  assert.equal(doc.querySelector(".real .timeprice-original").textContent, "$20.00");
  const body = doc.documentElement.textContent;
  assert.match(body, /2024/);
  assert.match(body, /2026/);
  assert.match(body, /104938275610/);
  assert.match(body, /555-2671/);
  assert.match(body, /20%/);
  assert.match(body, /18\.5%/);
  assert.equal(doc.querySelectorAll("[data-timeprice]").length, 1);
});

test("skips inputs, textareas, selects, contenteditable, and payment iframes", () => {
  const doc = parseHTML(read("inputs.html"));
  engine.annotateDocument(doc, usd("16"), "https://shop.example/product");
  assert.equal(doc.querySelector("#shown .timeprice-hours").textContent, "30 minutes");
  assert.equal(doc.querySelector("#price").getAttribute("value"), "$8.00");
  assert.equal(doc.querySelector("#note").textContent.trim(), "$8.00");
  assert.equal(doc.querySelector("#choice").textContent.trim(), "$8.00");
  assert.equal(doc.querySelector("#edit").textContent.trim(), "$8.00");
  assert.equal(doc.querySelector("#note [data-timeprice]"), null);
  assert.equal(doc.querySelector("#edit [data-timeprice]"), null);
  assert.equal(doc.querySelector("#iframe-price").textContent.trim(), "$50.00");
  assert.equal(doc.querySelector("#iframe-price [data-timeprice]"), null);
  assert.ok(doc.querySelector("#outside [data-timeprice]"));
});

test("skips checkout and payment URLs", () => {
  assert.equal(engine.shouldSkipURL("https://shop.example/cart/checkout?step=1"), true);
  assert.equal(engine.shouldSkipURL("https://shop.example/pay/payment"), true);
  assert.equal(engine.shouldSkipURL("https://shop.example/products/lamp"), false);
  const doc = parseHTML(read("checkout.html"));
  const result = engine.annotateDocument(doc, usd("32"), "https://shop.example/checkout");
  assert.equal(result.skippedURL, true);
  assert.equal(result.annotated, 0);
  assert.equal(doc.querySelector("[data-timeprice]"), null);
  assert.match(doc.querySelector(".due").textContent, /\$64\.00/);
  const payment = engine.annotateDocument(parseHTML(read("checkout.html")), usd("32"), "https://shop.example/order/payment");
  assert.equal(payment.skippedURL, true);
});

test("a second pass does not annotate twice", () => {
  const doc = parseHTML("<p>Pay only $12.00 today</p>");
  const first = engine.annotateDocument(doc, usd("24"), "https://shop.example/p");
  const second = engine.annotateDocument(doc, usd("24"), "https://shop.example/p");
  assert.equal(first.annotated, 1);
  assert.equal(second.annotated, 0);
  assert.equal(doc.querySelectorAll("[data-timeprice]").length, 1);
  assert.equal(doc.querySelectorAll(".timeprice-hours").length, 1);
  assert.equal(doc.querySelector(".timeprice-hours").textContent, "30 minutes");
  assert.equal(doc.querySelector(".timeprice-original").textContent, "$12.00");
  assert.match(doc.querySelector("p").textContent, /Pay only/);
  assert.match(doc.querySelector("p").textContent, /today/);
});

test("caps annotations so a huge DOM cannot be rewritten in one pass", () => {
  const spans = Array.from({ length: 200 }, () => "<span>$1.00</span>").join("");
  const doc = parseHTML(`<div>${spans}</div>`);
  const result = engine.annotateDocument(doc, { netHourly: "60", currencyCode: "USD", enabled: true }, "https://shop.example/grid");
  assert.equal(result.annotated, engine.MAX_ANNOTATIONS);
  assert.equal(result.capped, true);
  assert.equal(doc.querySelectorAll("[data-timeprice]").length, engine.MAX_ANNOTATIONS);
});

test("disabled config leaves the page alone", () => {
  const doc = parseHTML("<span>$9.00</span>");
  const result = engine.annotateDocument(doc, { netHourly: "30", currencyCode: "USD", enabled: false }, "https://shop.example/x");
  assert.equal(result.disabled, true);
  assert.equal(doc.querySelector("span").textContent.trim(), "$9.00");
});
