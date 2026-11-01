"use strict";

class TextNode {
  constructor(data) {
    this.nodeType = 3;
    this.data = data == null ? "" : String(data);
    this.parentElement = null;
    this.ownerDocument = null;
  }

  get nextSibling() {
    if (!this.parentElement) return null;
    const siblings = this.parentElement.childNodes;
    const index = siblings.indexOf(this);
    return index >= 0 ? siblings[index + 1] || null : null;
  }

  get textContent() {
    return this.data;
  }

  set textContent(value) {
    this.data = value == null ? "" : String(value);
  }
}

class Element {
  constructor(tagName) {
    this.nodeType = 1;
    this.tagName = String(tagName || "DIV").toUpperCase();
    this.attributes = {};
    this.childNodes = [];
    this.parentElement = null;
    this.ownerDocument = null;
  }

  get children() {
    return this.childNodes.filter((node) => node.nodeType === 1);
  }

  get textContent() {
    return this.childNodes.map((node) => node.textContent).join("");
  }

  set textContent(value) {
    const text = new TextNode(value);
    text.parentElement = this;
    text.ownerDocument = this.ownerDocument;
    this.childNodes = [text];
  }

  get nextSibling() {
    if (!this.parentElement) return null;
    const siblings = this.parentElement.childNodes;
    const index = siblings.indexOf(this);
    return index >= 0 ? siblings[index + 1] || null : null;
  }

  getAttribute(name) {
    return Object.prototype.hasOwnProperty.call(this.attributes, name) ? this.attributes[name] : null;
  }

  setAttribute(name, value) {
    this.attributes[name] = value == null ? "" : String(value);
  }

  hasAttribute(name) {
    return Object.prototype.hasOwnProperty.call(this.attributes, name);
  }

  get classList() {
    const element = this;
    return {
      add(className) {
        const parts = new Set((element.getAttribute("class") || "").split(/\s+/).filter(Boolean));
        parts.add(className);
        element.setAttribute("class", Array.from(parts).join(" "));
      },
      contains(className) {
        return (element.getAttribute("class") || "").split(/\s+/).includes(className);
      },
    };
  }

  appendChild(node) {
    if (node.parentElement) {
      node.parentElement.childNodes = node.parentElement.childNodes.filter((child) => child !== node);
    }
    node.parentElement = this;
    node.ownerDocument = this.ownerDocument;
    this.childNodes.push(node);
    return node;
  }

  insertBefore(node, reference) {
    if (node.parentElement) {
      node.parentElement.childNodes = node.parentElement.childNodes.filter((child) => child !== node);
    }
    node.parentElement = this;
    node.ownerDocument = this.ownerDocument;
    const index = this.childNodes.indexOf(reference);
    if (index < 0) this.childNodes.push(node);
    else this.childNodes.splice(index, 0, node);
    return node;
  }

  replaceChild(node, old) {
    const index = this.childNodes.indexOf(old);
    if (index < 0) return old;
    if (node.parentElement && node.parentElement !== this) {
      node.parentElement.childNodes = node.parentElement.childNodes.filter((child) => child !== node);
    }
    node.parentElement = this;
    node.ownerDocument = this.ownerDocument;
    this.childNodes.splice(index, 1, node);
    old.parentElement = null;
    return old;
  }

  matches(selector) {
    return matchesSimple(this, selector.trim());
  }

  closest(selector) {
    let node = this;
    while (node) {
      if (node.nodeType === 1 && node.matches(selector)) return node;
      node = node.parentElement;
    }
    return null;
  }

  querySelector(selector) {
    const found = this.querySelectorAll(selector);
    return found[0] || null;
  }

  querySelectorAll(selector) {
    return queryAll(this, selector);
  }
}

class Document {
  constructor() {
    this.nodeType = 9;
    this.childNodes = [];
    this.documentElement = null;
    this.ownerDocument = this;
  }

  createElement(tag) {
    const element = new Element(tag);
    element.ownerDocument = this;
    return element;
  }

  createTextNode(text) {
    const node = new TextNode(text);
    node.ownerDocument = this;
    return node;
  }

  querySelector(selector) {
    const found = this.querySelectorAll(selector);
    return found[0] || null;
  }

  querySelectorAll(selector) {
    return queryAll(this, selector);
  }
}

function parseSimple(simple) {
  let rest = simple.trim();
  let tag = "*";
  const classes = [];
  let id = null;
  const attrs = [];
  if (rest[0] && /[A-Za-z*]/.test(rest[0])) {
    if (rest[0] === "*") {
      tag = "*";
      rest = rest.slice(1);
    } else {
      const match = rest.match(/^[A-Za-z][A-Za-z0-9:-]*/);
      if (match) {
        tag = match[0].toUpperCase();
        rest = rest.slice(match[0].length);
      }
    }
  }
  while (rest.length) {
    if (rest[0] === ".") {
      const match = rest.match(/^\.([A-Za-z0-9_-]+)/);
      if (!match) break;
      classes.push(match[1]);
      rest = rest.slice(match[0].length);
    } else if (rest[0] === "#") {
      const match = rest.match(/^#([A-Za-z0-9_-]+)/);
      if (!match) break;
      id = match[1];
      rest = rest.slice(match[0].length);
    } else if (rest[0] === "[") {
      const match = rest.match(/^\[([^\]]+)\]/);
      if (!match) break;
      attrs.push(match[1]);
      rest = rest.slice(match[0].length);
    } else break;
  }
  return { tag, classes, id, attrs };
}

function attrMatches(element, expression) {
  const match = expression.match(/^([A-Za-z_:][-A-Za-z0-9_:.]*)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s\]]+)))?$/);
  if (!match) return false;
  const name = match[1];
  if (match[2] === undefined && match[3] === undefined && match[4] === undefined) {
    return element.hasAttribute(name);
  }
  const expected = match[2] ?? match[3] ?? match[4];
  return element.getAttribute(name) === expected;
}

function matchesSimple(element, simple) {
  if (!simple) return false;
  const parsed = parseSimple(simple);
  if (parsed.tag !== "*" && element.tagName !== parsed.tag) return false;
  if (parsed.id && element.getAttribute("id") !== parsed.id) return false;
  const className = element.getAttribute("class") || "";
  const classes = className.split(/\s+/);
  for (const required of parsed.classes) {
    if (!classes.includes(required)) return false;
  }
  for (const attr of parsed.attrs) {
    if (!attrMatches(element, attr)) return false;
  }
  return true;
}

function collectDescendants(node) {
  const found = [];
  const children = node.childNodes || [];
  for (const child of children) {
    if (child.nodeType === 1) {
      found.push(child);
      found.push(...collectDescendants(child));
    }
  }
  return found;
}

function parseSequence(selector) {
  const parts = [];
  let rest = selector.trim();
  while (rest.length) {
    rest = rest.replace(/^\s+/, "");
    if (!rest) break;
    let combinator = " ";
    if (parts.length === 0) combinator = "start";
    else if (rest[0] === ">") {
      combinator = ">";
      rest = rest.slice(1).replace(/^\s+/, "");
    }
    const match = rest.match(/^(?:[*]|[A-Za-z][A-Za-z0-9:-]*)?(?:[#.][A-Za-z0-9_-]+|\[[^\]]+\])+/);
    const tagOnly = rest.match(/^(?:[*]|[A-Za-z][A-Za-z0-9:-]*)/);
    const simple = (match && match[0]) || (tagOnly && tagOnly[0]);
    if (!simple) break;
    parts.push({ combinator, simple });
    rest = rest.slice(simple.length);
  }
  return parts;
}

function queryAll(scope, selector) {
  const groups = selector.split(",").map((part) => part.trim()).filter(Boolean);
  const seen = new Set();
  const results = [];
  groups.forEach((group) => {
    const sequence = parseSequence(group);
    if (sequence.length === 0) return;
    let candidates = collectDescendants(scope).filter((element) => matchesSimple(element, sequence[0].simple));
    for (let index = 1; index < sequence.length; index += 1) {
      const step = sequence[index];
      const next = [];
      candidates.forEach((element) => {
        const pool = step.combinator === ">" ? element.children : collectDescendants(element);
        pool.forEach((candidate) => {
          if (matchesSimple(candidate, step.simple)) next.push(candidate);
        });
      });
      candidates = next;
    }
    candidates.forEach((element) => {
      if (!seen.has(element)) {
        seen.add(element);
        results.push(element);
      }
    });
  });
  return results;
}

function decode(text) {
  return text
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, "\"")
    .replace(/&#39;/g, "'");
}

function parseAttributes(element, source) {
  const pattern = /([:@A-Za-z_][-:@A-Za-z0-9_.]*)\s*(?:=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+)))?/g;
  let match;
  while ((match = pattern.exec(source)) !== null) {
    const value = match[2] ?? match[3] ?? match[4] ?? "";
    element.setAttribute(match[1], decode(value));
  }
}

function parseHTML(html) {
  const doc = new Document();
  const root = doc.createElement("html");
  doc.childNodes = [root];
  doc.documentElement = root;
  root.parentElement = null;
  const stack = [root];
  const source = String(html);
  let index = 0;
  const voidTags = new Set(["META", "LINK", "IMG", "BR", "HR", "INPUT", "SOURCE", "WBR"]);
  while (index < source.length) {
    if (source.startsWith("<!--", index)) {
      const end = source.indexOf("-->", index + 4);
      index = end === -1 ? source.length : end + 3;
      continue;
    }
    if (source[index] === "<") {
      if (source[index + 1] === "/") {
        const end = source.indexOf(">", index);
        const name = source.slice(index + 2, end === -1 ? source.length : end).trim().split(/\s+/)[0].toUpperCase();
        index = end === -1 ? source.length : end + 1;
        for (let depth = stack.length - 1; depth > 0; depth -= 1) {
          const popped = stack.pop();
          if (popped.tagName === name) break;
        }
        continue;
      }
      const end = source.indexOf(">", index);
      if (end === -1) break;
      let raw = source.slice(index + 1, end);
      index = end + 1;
      let selfClosing = false;
      if (raw.endsWith("/")) {
        selfClosing = true;
        raw = raw.slice(0, -1);
      }
      const tagMatch = raw.match(/^([A-Za-z][A-Za-z0-9:-]*)/);
      if (!tagMatch) continue;
      const element = doc.createElement(tagMatch[1]);
      parseAttributes(element, raw.slice(tagMatch[1].length));
      stack[stack.length - 1].appendChild(element);
      const tag = element.tagName;
      if (!selfClosing && !voidTags.has(tag)) {
        stack.push(element);
        if (tag === "SCRIPT" || tag === "STYLE" || tag === "NOSCRIPT") {
          const close = new RegExp("</" + tag + ">", "i");
          const rest = source.slice(index);
          const found = rest.match(close);
          const text = found ? rest.slice(0, found.index) : rest;
          if (text) element.appendChild(doc.createTextNode(text));
          index += found ? found.index + found[0].length : rest.length;
          stack.pop();
        }
      }
      continue;
    }
    const next = source.indexOf("<", index);
    const text = source.slice(index, next === -1 ? source.length : next);
    index = next === -1 ? source.length : next;
    if (text) stack[stack.length - 1].appendChild(doc.createTextNode(decode(text)));
  }
  return doc;
}

module.exports = { parseHTML, Document, Element, TextNode };
