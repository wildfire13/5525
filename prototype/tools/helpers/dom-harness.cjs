'use strict';

// Narrow, dependency-free DOM simulation for app/cycle event wiring, not browser QA.
// No layout, CSS, images, WebGL, network, native dialogs, or browser security checks.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '../..');
const voidTags = new Set(['area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'link', 'meta', 'param', 'source', 'track', 'wbr']);
const decode = text => text.replace(/&(amp|lt|gt|quot|apos|nbsp);/g, (_, name) => ({amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' '})[name]);
const dataKey = name => name.slice(5).replace(/-([a-z])/g, (_, c) => c.toUpperCase());

class Event {
  constructor(type, options = {}) { Object.assign(this, {type, defaultPrevented: false, bubbles: false}, options); }
  preventDefault() { this.defaultPrevented = true; }
}
class TextNode {
  constructor(text) { this.textContent = decode(text); this.parentElement = null; }
}
class Element {
  constructor(tagName, document) {
    this.tagName = tagName.toLowerCase(); this.ownerDocument = document; this.parentElement = null;
    this.childNodes = []; this.attributes = {}; this.dataset = {}; this.listeners = {};
    this.disabled = false; this.hidden = false; this.checked = false; this.open = false;
    this.style = {};
    this.classList = {
      contains: name => this.className.split(/\s+/).includes(name),
      add: (...names) => { this.className = [...new Set([...this.className.split(/\s+/).filter(Boolean), ...names])].join(' '); },
      remove: (...names) => { this.className = this.className.split(/\s+/).filter(name => !names.includes(name)).join(' '); },
      toggle: (name, force) => { const present = force === undefined ? !this.classList.contains(name) : !!force; this.classList[present ? 'add' : 'remove'](name); return present; },
    };
  }
  get children() { return this.childNodes.filter(node => node instanceof Element); }
  get id() { return this.attributes.id || ''; }
  set id(value) { this.attributes.id = String(value); }
  get className() { return this.attributes.class || ''; }
  set className(value) { this.attributes.class = String(value); }
  get textContent() { return this.childNodes.map(node => node.textContent).join(''); }
  set textContent(value) { this.replaceChildren(new TextNode(String(value))); }
  get text() { return this.textContent; }
  set text(value) { this.textContent = value; }
  get options() { return this.querySelectorAll('option'); }
  get value() { return this._value ?? this.attributes.value ?? (this.tagName === 'select' ? this.options[0]?.value : '') ?? ''; }
  set value(value) { this._value = String(value); }
  set innerHTML(html) { this.replaceChildren(...parse(String(html), this.ownerDocument)); }
  get innerHTML() { return this.childNodes.map(node => node instanceof Element ? `<${node.tagName}>${node.innerHTML}</${node.tagName}>` : node.textContent).join(''); }
  setAttribute(name, value) {
    this.attributes[name] = String(value);
    if (name.startsWith('data-')) this.dataset[dataKey(name)] = String(value);
    if (['disabled', 'hidden', 'checked', 'open'].includes(name)) this[name] = true;
  }
  getAttribute(name) { return this.attributes[name] ?? null; }
  removeAttribute(name) { delete this.attributes[name]; if (['disabled', 'hidden', 'checked', 'open'].includes(name)) this[name] = false; }
  append(...nodes) { for (const node of nodes) { const child = typeof node === 'string' ? new TextNode(node) : node; child.parentElement?.removeChild(child); child.parentElement = this; this.childNodes.push(child); } }
  prepend(...nodes) { const old = [...this.childNodes]; this.replaceChildren(...nodes, ...old); }
  removeChild(node) { const index = this.childNodes.indexOf(node); if (index < 0) throw Error('Node is not a child'); this.childNodes.splice(index, 1); node.parentElement = null; return node; }
  remove() { this.parentElement?.removeChild(this); }
  replaceChildren(...nodes) { for (const node of this.childNodes) node.parentElement = null; this.childNodes = []; this.append(...nodes); }
  insertAdjacentHTML(position, html) {
    const nodes = parse(html, this.ownerDocument);
    if (position === 'beforeend') this.append(...nodes);
    else if (position === 'afterbegin') this.prepend(...nodes);
    else if (position === 'beforebegin' || position === 'afterend') {
      if (!this.parentElement) throw Error('Adjacent insertion needs a parent');
      const parent = this.parentElement, index = parent.childNodes.indexOf(this) + Number(position === 'afterend');
      nodes.forEach(node => { node.parentElement = parent; }); parent.childNodes.splice(index, 0, ...nodes);
    } else throw Error(`Unsupported insertion: ${position}`);
  }
  contains(node) { for (let current = node; current; current = current.parentElement) if (current === this) return true; return false; }
  closest(selector) { for (let node = this; node; node = node.parentElement) if (matches(node, selector)) return node; return null; }
  querySelectorAll(selector) {
    const found = [];
    const walk = node => { for (const child of node.children) { if (selector.split(',').some(part => matches(child, part.trim()))) found.push(child); walk(child); } };
    walk(this); return found;
  }
  querySelector(selector) { return this.querySelectorAll(selector)[0] || null; }
  addEventListener(type, listener) { (this.listeners[type] ||= []).push(listener); }
  dispatchEvent(event) {
    event.target ||= this; event.currentTarget = this;
    this[`on${event.type}`]?.(event);
    for (const listener of this.listeners[event.type] || []) listener(event);
    if (event.bubbles) this.parentElement?.dispatchEvent(event);
    return !event.defaultPrevented;
  }
  click() {
    if (this.disabled) return;
    if (this.tagName === 'input' && this.attributes.type === 'checkbox') { this.checked = !this.checked; this.dispatchEvent(new Event('change')); }
    this.dispatchEvent(new Event('click'));
    if (this.tagName === 'a' && this.download) this.ownerDocument.downloads.push({filename: this.download, href: this.href, blob: this.ownerDocument.objectURLs.get(this.href), element: this});
  }
  showModal() { this.open = true; this.ownerDocument.activeElement = this.querySelector('[autofocus]') || this; }
  close() { this.open = false; }
}
function matches(node, selector) {
  // Only the selectors actually used by the app are supported. Unsupported
  // syntax is an error so it cannot accidentally produce a false-positive pass.
  const parts = selector.replace(/\s*>\s*/g, '>').split(/(>|\s+)/).filter(Boolean);
  function test(current, index) {
    if (!current || !simple(current, parts[index])) return false;
    if (index === 0) return true;
    const combinator = parts[index - 1];
    if (combinator === '>') return test(current.parentElement, index - 2);
    for (let parent = current.parentElement; parent; parent = parent.parentElement) if (test(parent, index - 2)) return true;
    return false;
  }
  return test(node, parts.length - 1);
}
function simple(node, selector) {
  let rest = selector;
  const tokens = /^(\*|[a-zA-Z][\w-]*|#[\w-]+|\.[\w-]+|\[[\w-]+(?:=(?:"[^"]*"|'[^']*'|[^\]]+))?\]|:checked)/;
  while (rest) {
    const match = rest.match(tokens); if (!match) throw Error(`Unsupported simulated DOM selector: ${selector}`);
    const token = match[0]; rest = rest.slice(token.length);
    if (token === '*') continue;
    if (token === ':checked') { if (!node.checked) return false; }
    else if (token[0] === '#') { if (node.id !== token.slice(1)) return false; }
    else if (token[0] === '.') { if (!node.classList.contains(token.slice(1))) return false; }
    else if (token[0] === '[') {
      const attribute = token.slice(1, -1).match(/^([\w-]+)(?:=(.*))?$/), name = attribute[1];
      const actual = name.startsWith('data-') ? node.dataset[dataKey(name)] : node.getAttribute(name);
      if (actual == null) return false;
      if (attribute[2] !== undefined && String(actual) !== attribute[2].replace(/^['"]|['"]$/g, '')) return false;
    } else if (node.tagName !== token.toLowerCase()) return false;
  }
  return true;
}
function parse(html, document) {
  const fragment = new Element('fragment', document), stack = [fragment];
  for (const token of html.match(/<!--[\s\S]*?-->|<![^>]*>|<[^>]+>|[^<]+/g) || []) {
    if (token.startsWith('<!')) continue;
    if (token.startsWith('</')) {
      const tag = token.slice(2, -1).trim().toLowerCase();
      const index = stack.map(node => node.tagName).lastIndexOf(tag); if (index > 0) stack.length = index;
    } else if (token[0] === '<') {
      const open = token.match(/^<([\w-]+)([\s\S]*?)\/?\s*>$/); if (!open) throw Error(`Invalid HTML token: ${token}`);
      const node = new Element(open[1], document);
      for (const attribute of open[2].matchAll(/([^\s=/>]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+)))?/g)) node.setAttribute(attribute[1], decode(attribute[2] ?? attribute[3] ?? attribute[4] ?? ''));
      stack.at(-1).append(node); if (!voidTags.has(node.tagName)) stack.push(node);
    } else stack.at(-1).append(new TextNode(token));
  }
  const nodes = [...fragment.childNodes]; for (const node of nodes) node.parentElement = null; return nodes;
}
function createHarness(entry = 'index.html') {
  const document = new Element('document', null); document.ownerDocument = document;
  document.createElement = tag => new Element(tag, document);
  document.getElementById = id => document.querySelector(`#${id}`);
  document.objectURLs = new Map(); document.downloads = [];
  const html = fs.readFileSync(path.join(root, entry), 'utf8'); document.innerHTML = html;
  document.body = document.querySelector('body'); document.activeElement = document.body;
  const timers = [], worldCalls = [];
  class FakeURL extends URL {
    static createObjectURL(blob) { const url = `blob:simulated/${document.objectURLs.size + 1}`; document.objectURLs.set(url, blob); return url; }
    static revokeObjectURL(url) { document.objectURLs.delete(url); }
  }
  const context = vm.createContext({document, console, Event, CustomEvent: Event, Blob, TextEncoder, URL: FakeURL, setTimeout: callback => { timers.push(callback); return timers.length; }, clearTimeout() {}, scrollTo() {}, World: {progress: stage => worldCalls.push(['progress', stage]), burst: (...args) => worldCalls.push(['burst', ...args]), ready: () => true}});
  context.window = context; context.globalThis = context;
  const scripts = [...html.matchAll(/<script\b[^>]*\bsrc="([^"]+)"[^>]*>/g)].map(match => match[1]);
  for (const script of scripts) {
    if (script === 'vendor/three/three.min.js' || script === 'src/world.js') continue;
    if (!/^src\/[\w-]+\.js$/.test(script)) throw Error(`Unexpected script in test entry: ${script}`);
    vm.runInContext(fs.readFileSync(path.join(root, script), 'utf8'), context, {filename: script, timeout: 10000});
  }
  return {
    document, context, worldCalls, loadedScripts: scripts.filter(script => script !== 'vendor/three/three.min.js' && script !== 'src/world.js'),
    run: source => vm.runInContext(source, context, {timeout: 10000}),
    snapshot: source => JSON.parse(vm.runInContext(`JSON.stringify(${source})`, context)),
    click: selector => { const element = document.querySelector(selector); if (!element) throw Error(`Missing clickable element: ${selector}`); if (element.disabled) throw Error(`Disabled element: ${selector}`); element.click(); return element; },
    cancelDialog: () => { const dialog = document.querySelector('dialog[open]') || document.querySelector('dialog'); if (!dialog?.open) throw Error('No open dialog'); dialog.dispatchEvent(new Event('cancel')); dialog.close(); },
    flushTimers: () => { while (timers.length) timers.shift()(); },
  };
}
module.exports = {createHarness, Event};
