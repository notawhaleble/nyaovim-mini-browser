const {ipcRenderer} = require('electron');

let overlayId = null;
let pendingCtrlBackslash = false;

ipcRenderer.on('mini-browser:set-overlay-id', (_event, id) => {
  overlayId = id;
  ipcRenderer.sendToHost('mini-browser:precise-ready', {
    overlayId,
    timestamp: Date.now(),
  });
});

function forwardBrowserNotification(title, options) {
  const payload = {
    overlayId,
    title: typeof title === 'string' ? title : '',
    body: options && typeof options.body === 'string' ? options.body : '',
    tag: options && typeof options.tag === 'string' ? options.tag : undefined,
    icon: options && typeof options.icon === 'string' ? options.icon : undefined,
    silent: options ? !!options.silent : undefined,
    renotify: options ? !!options.renotify : undefined,
    requireInteraction: options ? !!options.requireInteraction : undefined,
    timestamp: Date.now(),
  };
  if (options && options.data !== undefined) {
    try {
      payload.data = JSON.parse(JSON.stringify(options.data));
    } catch (_err) {
      payload.data = undefined;
    }
  }
  ipcRenderer.sendToHost('mini-browser:notification', payload);
}

const NativeNotification = typeof window !== 'undefined' ? window.Notification : null;

if (typeof NativeNotification === 'function') {
  const NotificationProxy = function NotificationProxy(title, options) {
    let instance = null;
    let error = null;
    try {
      instance = Reflect.construct(
        NativeNotification,
        [title, options],
        new.target || NotificationProxy,
      );
    } catch (err) {
      error = err;
    }
    try {
      forwardBrowserNotification(title, options || {});
    } catch (forwardErr) {
      console.error('[mini-browser] forwarding notification failed', forwardErr);
    }
    if (error) {
      throw error;
    }
    return instance;
  };

  NotificationProxy.prototype = NativeNotification.prototype;
  Object.defineProperty(NotificationProxy.prototype, 'constructor', {
    value: NotificationProxy,
    writable: true,
    configurable: true,
  });
  Object.setPrototypeOf(NotificationProxy, NativeNotification);

  Object.defineProperty(NotificationProxy, 'permission', {
    configurable: true,
    enumerable: true,
    get() {
      return NativeNotification.permission;
    },
  });

  Object.defineProperty(NotificationProxy, 'maxActions', {
    configurable: true,
    enumerable: true,
    get() {
      return NativeNotification.maxActions;
    },
  });

  NotificationProxy.requestPermission = NativeNotification.requestPermission
    ? NativeNotification.requestPermission.bind(NativeNotification)
    : undefined;

  window.Notification = NotificationProxy;
}

window.addEventListener(
  'keydown',
  event => {
    const key = event.key ? event.key.toLowerCase() : '';
    const code = event.code || '';
    if ((event.ctrlKey || event.metaKey) && (key === '\\' || code === 'Backslash')) {
      pendingCtrlBackslash = true;
      event.preventDefault();
      event.stopPropagation();
      return;
    }
    if (pendingCtrlBackslash) {
      if ((event.ctrlKey || event.metaKey) && (key === 'n' || code === 'KeyN')) {
        pendingCtrlBackslash = false;
        ipcRenderer.sendToHost('mini-browser:focus', false);
        event.preventDefault();
        event.stopPropagation();
        return;
      }
      pendingCtrlBackslash = false;
    }
    if ((event.ctrlKey || event.metaKey) && (key === ']' || code === 'BracketRight')) {
      ipcRenderer.sendToHost('mini-browser:toggle');
      event.preventDefault();
      event.stopPropagation();
      return;
    }
    if ((event.ctrlKey || event.metaKey) && (key === 'r' || code === 'KeyR')) {
      ipcRenderer.sendToHost('mini-browser:reload', {
        ignoreCache: !!event.shiftKey,
      });
      event.preventDefault();
      event.stopPropagation();
      return;
    }
    if ((event.ctrlKey || event.metaKey) && (key === '+' || key === '=' || code === 'Equal' || code === 'NumpadAdd')) {
      ipcRenderer.sendToHost('mini-browser:zoom-in');
      event.preventDefault();
      event.stopPropagation();
      return;
    }
    if (
      (event.ctrlKey || event.metaKey) &&
      (key === '-' || key === '_' || code === 'Minus' || code === 'NumpadSubtract')
    ) {
      ipcRenderer.sendToHost('mini-browser:zoom-out');
      event.preventDefault();
      event.stopPropagation();
      return;
    }
    if ((event.ctrlKey || event.metaKey) && (key === 'o' || code === 'KeyO')) {
      ipcRenderer.sendToHost('mini-browser:history-back');
      event.preventDefault();
      event.stopPropagation();
      return;
    }
    if ((event.ctrlKey || event.metaKey) && (key === 'i' || code === 'KeyI')) {
      ipcRenderer.sendToHost('mini-browser:history-forward');
      event.preventDefault();
      event.stopPropagation();
      return;
    }
    if ((event.ctrlKey || event.metaKey) && (key === 'w' || code === 'KeyW')) {
      ipcRenderer.sendToHost('mini-browser:ctrl-w');
      event.preventDefault();
      event.stopPropagation();
    }
  },
  true,
);

window.addEventListener('keyup', event => {
  const key = event.key ? event.key.toLowerCase() : '';
  const code = event.code || '';
  if ((event.ctrlKey || event.metaKey) && (key === ']' || code === 'BracketRight')) {
    event.preventDefault();
    event.stopPropagation();
  }
  if ((event.ctrlKey || event.metaKey) && (key === 'r' || code === 'KeyR')) {
    event.preventDefault();
    event.stopPropagation();
  }
  if ((event.ctrlKey || event.metaKey) && (key === '+' || key === '=' || code === 'Equal' || code === 'NumpadAdd')) {
    event.preventDefault();
    event.stopPropagation();
  }
  if (
    (event.ctrlKey || event.metaKey) &&
    (key === '-' || key === '_' || code === 'Minus' || code === 'NumpadSubtract')
  ) {
    event.preventDefault();
    event.stopPropagation();
  }
  if ((event.ctrlKey || event.metaKey) && (key === 'o' || code === 'KeyO')) {
    event.preventDefault();
    event.stopPropagation();
  }
  if ((event.ctrlKey || event.metaKey) && (key === 'i' || code === 'KeyI')) {
    event.preventDefault();
    event.stopPropagation();
  }
}, true);

window.addEventListener('focus', () => {
  ipcRenderer.sendToHost('mini-browser:focus', true);
}, true);

window.addEventListener('blur', () => {
  ipcRenderer.sendToHost('mini-browser:focus', false);
}, true);

window.addEventListener(
  'mousedown',
  () => {
    ipcRenderer.sendToHost('mini-browser:mouse-down');
  },
  true,
);

const preciseState = {
  enabled: false,
  building: false,
  indexMap: [],
  lines: [],
  lineHeight: 16,
  lastCursorIndex: null,
  lastSelection: null,
  suppressAutoScrollOnce: false,
  overlay: {
    root: null,
    caret: null,
    selectionRoot: null,
    selectionNodes: [],
  },
  pendingRender: false,
};

const PRECISE_MAX_CHARS = 200000;

const COLLAPSIBLE_WHITESPACE = /[ \t\n\f\r]/;

function isCollapsibleWhitespace(ch) {
  return COLLAPSIBLE_WHITESPACE.test(ch);
}

function applyTextTransform(text, transform) {
  const mode = (transform || '').toLowerCase();
  let transformed = text;
  if (mode === 'uppercase') {
    transformed = text.toUpperCase();
  } else if (mode === 'lowercase') {
    transformed = text.toLowerCase();
  } else if (mode === 'capitalize') {
    transformed = text.replace(/\b[a-z]/g, match => match.toUpperCase());
  }
  if (transformed.length !== text.length) {
    return text;
  }
  return transformed;
}

function normalizeNodeText(text, whiteSpace, textTransform, lastWasSpace) {
  const ws = (whiteSpace || '').toLowerCase();
  const preserve = ws === 'pre' || ws === 'pre-wrap' || ws === 'break-spaces';
  const preLine = ws === 'pre-line';
  let normalized = '';
  const offsets = [];
  let lastSpace = lastWasSpace;
  for (let i = 0; i < text.length; i += 1) {
    const ch = text[i];
    if (ch === '\r') {
      continue;
    }
    if (isCollapsibleWhitespace(ch)) {
      if (preserve) {
        normalized += ch;
        offsets.push(i);
        lastSpace = ch === ' ' || ch === '\t';
        continue;
      }
      if (preLine && ch === '\n') {
        normalized += '\n';
        offsets.push(i);
        lastSpace = false;
        continue;
      }
      if (lastSpace) {
        continue;
      }
      normalized += ' ';
      offsets.push(i);
      lastSpace = true;
      continue;
    }
    normalized += ch;
    offsets.push(i);
    lastSpace = false;
  }
  const transformed = applyTextTransform(normalized, textTransform);
  return {text: transformed, offsets, lastWasSpace: lastSpace};
}

function isTextNodeVisible(node) {
  if (!node || node.nodeType !== Node.TEXT_NODE) {
    return false;
  }
  const parent = node.parentElement;
  if (!parent) {
    return false;
  }
  const tag = parent.tagName ? parent.tagName.toLowerCase() : '';
  if (tag === 'script' || tag === 'style' || tag === 'noscript') {
    return false;
  }
  const style = window.getComputedStyle(parent);
  if (!style || style.display === 'none' || style.visibility === 'hidden') {
    return false;
  }
  if (parent.closest && parent.closest('[aria-hidden="true"]')) {
    return false;
  }
  return true;
}

function ensureOverlay() {
  if (preciseState.overlay.root && preciseState.overlay.root.isConnected) {
    return;
  }
  const root = preciseState.overlay.root || document.createElement('div');
  root.id = 'mini-browser-precise-overlay';
  root.style.position = 'absolute';
  root.style.top = '0px';
  root.style.left = '0px';
  root.style.width = '100%';
  root.style.height = '100%';
  root.style.pointerEvents = 'none';
  root.style.zIndex = '2147483647';
  const caret = preciseState.overlay.caret || document.createElement('div');
  caret.style.position = 'absolute';
  caret.style.width = '2px';
  caret.style.background = '#111';
  caret.style.boxShadow = '0 0 0 1px rgba(255,255,255,0.5)';
  caret.style.display = 'none';
  const selectionRoot = preciseState.overlay.selectionRoot || document.createElement('div');
  selectionRoot.style.position = 'absolute';
  selectionRoot.style.top = '0px';
  selectionRoot.style.left = '0px';
  selectionRoot.style.width = '100%';
  selectionRoot.style.height = '100%';
  selectionRoot.style.pointerEvents = 'none';
  if (!selectionRoot.isConnected) {
    root.appendChild(selectionRoot);
  }
  if (!caret.isConnected) {
    root.appendChild(caret);
  }
  const container = document.body || document.documentElement;
  if (container && !root.isConnected) {
    container.appendChild(root);
  }
  preciseState.overlay.root = root;
  preciseState.overlay.caret = caret;
  preciseState.overlay.selectionRoot = selectionRoot;
}

function updateLineHeight() {
  const target = document.body || document.documentElement;
  if (!target) {
    return;
  }
  const style = window.getComputedStyle(target);
  const raw = style ? style.lineHeight : '';
  let height = parseFloat(raw);
  if (!Number.isFinite(height) || height <= 0) {
    height = 16;
  }
  preciseState.lineHeight = height;
}

function rectForCharacter(node, offset) {
  if (!node || node.nodeType !== Node.TEXT_NODE) {
    return null;
  }
  const range = document.createRange();
  try {
    range.setStart(node, offset);
    range.setEnd(node, offset + 1);
  } catch (_err) {
    range.detach();
    return null;
  }
  const rects = range.getClientRects();
  let rect = null;
  for (let i = 0; i < rects.length; i += 1) {
    const r = rects[i];
    if (r.width > 0 || r.height > 0) {
      rect = r;
      break;
    }
  }
  if (!rect) {
    const r = range.getBoundingClientRect();
    if (r && (r.width > 0 || r.height > 0)) {
      rect = r;
    }
  }
  range.detach();
  return rect;
}

function pushLine(lines, indexMap, currentLine, includeNewline) {
  lines.push(currentLine);
  if (includeNewline) {
    indexMap.push(null);
  }
  return '';
}

function buildMapping() {
  const root = document.body || document.documentElement;
  if (!root) {
    return {lines: [''], indexMap: [], lineHeight: preciseState.lineHeight};
  }
  updateLineHeight();
  const indexMap = [];
  const lines = [];
  let currentLine = '';
  let lastLineTop = null;
  let charCount = 0;
  let lastWasSpace = false;
  const startTime = Date.now();
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
    acceptNode(node) {
      return isTextNodeVisible(node) ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_REJECT;
    },
  });
  let node = walker.nextNode();
  while (node) {
    const text = node.nodeValue || '';
    const parent = node.parentElement;
    const style = parent ? window.getComputedStyle(parent) : null;
    const whiteSpace = style ? style.whiteSpace : '';
    const textTransform = style ? style.textTransform : '';
    const normalized = normalizeNodeText(text, whiteSpace, textTransform, lastWasSpace);
    lastWasSpace = normalized.lastWasSpace;
    for (let i = 0; i < normalized.text.length; i += 1) {
      const ch = normalized.text[i];
      const offset = normalized.offsets[i];
      if (ch === '\n') {
        currentLine = pushLine(lines, indexMap, currentLine, true);
        lastLineTop = null;
        continue;
      }
      const rect = rectForCharacter(node, offset);
      if (!rect || (rect.width === 0 && rect.height === 0)) {
        if (ch === ' ') {
          currentLine += ch;
          indexMap.push(null);
          charCount += 1;
          continue;
        }
        if (!rect) {
          continue;
        }
      }
      if (lastLineTop === null) {
        lastLineTop = rect.top;
      } else if (Math.abs(rect.top - lastLineTop) > preciseState.lineHeight * 0.6) {
        currentLine = pushLine(lines, indexMap, currentLine, true);
        lastLineTop = rect.top;
      }
      currentLine += ch;
      indexMap.push({node, offset});
      charCount += 1;
      if (charCount >= PRECISE_MAX_CHARS) {
        ipcRenderer.sendToHost('mini-browser:precise-error', {
          message: 'precise mode: page too large for character mapping',
        });
        node = null;
        break;
      }
    }
    node = walker.nextNode();
  }
  if (currentLine.length > 0 || lines.length === 0) {
    lines.push(currentLine);
  }
  console.log('[mini-browser] precise map built', {
    lines: lines.length,
    chars: indexMap.length,
    ms: Date.now() - startTime,
  });
  return {lines, indexMap, lineHeight: preciseState.lineHeight};
}

function nearestMappedIndex(index, direction) {
  if (!preciseState.indexMap || preciseState.indexMap.length === 0) {
    return null;
  }
  let i = Math.max(0, Math.min(index, preciseState.indexMap.length - 1));
  while (i >= 0 && i < preciseState.indexMap.length) {
    if (preciseState.indexMap[i]) {
      return i;
    }
    i += direction;
  }
  return null;
}

function domBoundaryForIndex(index, isEnd) {
  const map = preciseState.indexMap;
  if (!map || map.length === 0) {
    return null;
  }
  if (index <= 0) {
    const first = nearestMappedIndex(0, 1);
    return first === null ? null : map[first];
  }
  if (index >= map.length) {
    const last = nearestMappedIndex(map.length - 1, -1);
    if (last === null) {
      return null;
    }
    return {node: map[last].node, offset: map[last].offset + 1};
  }
  let mapped = map[index];
  if (!mapped) {
    if (isEnd) {
      const nearest = nearestMappedIndex(index - 1, -1);
      if (nearest === null) {
        return null;
      }
      return {node: map[nearest].node, offset: map[nearest].offset + 1};
    }
    const nearest = nearestMappedIndex(index, 1);
    if (nearest === null) {
      return null;
    }
    mapped = map[nearest];
  }
  return mapped;
}

function caretRectForIndex(index) {
  const boundary = domBoundaryForIndex(index, false);
  if (!boundary) {
    return null;
  }
  const range = document.createRange();
  try {
    range.setStart(boundary.node, boundary.offset);
    range.setEnd(boundary.node, Math.min(boundary.offset + 1, boundary.node.length));
  } catch (_err) {
    range.detach();
    return null;
  }
  const rects = range.getClientRects();
  let rect = null;
  for (let i = 0; i < rects.length; i += 1) {
    const r = rects[i];
    if (r.width > 0 || r.height > 0) {
      rect = r;
      break;
    }
  }
  if (!rect) {
    const r = range.getBoundingClientRect();
    if (r && (r.width > 0 || r.height > 0)) {
      rect = r;
    }
  }
  range.detach();
  return rect;
}

function ensureCaretVisible(rect) {
  if (!rect) {
    return;
  }
  const margin = 8;
  const topLimit = margin;
  const bottomLimit = window.innerHeight - margin;
  const deltaTop = rect.top - topLimit;
  const deltaBottom = rect.bottom - bottomLimit;
  if (deltaTop < 0) {
    window.scrollBy(0, deltaTop);
  } else if (deltaBottom > 0) {
    window.scrollBy(0, deltaBottom);
  }
}

function clearSelectionOverlay() {
  if (!preciseState.overlay.selectionRoot) {
    return;
  }
  const root = preciseState.overlay.selectionRoot;
  while (root.firstChild) {
    root.removeChild(root.firstChild);
  }
  preciseState.overlay.selectionNodes = [];
}

function renderSelection(range) {
  if (!range || range.start === undefined || range.end === undefined) {
    clearSelectionOverlay();
    return;
  }
  const startBoundary = domBoundaryForIndex(range.start, false);
  const endBoundary = domBoundaryForIndex(range.end, true);
  if (!startBoundary || !endBoundary) {
    clearSelectionOverlay();
    return;
  }
  const domRange = document.createRange();
  try {
    domRange.setStart(startBoundary.node, startBoundary.offset);
    domRange.setEnd(endBoundary.node, endBoundary.offset);
  } catch (_err) {
    domRange.detach();
    clearSelectionOverlay();
    return;
  }
  const rects = domRange.getClientRects();
  clearSelectionOverlay();
  const root = preciseState.overlay.selectionRoot;
  for (let i = 0; i < rects.length; i += 1) {
    const r = rects[i];
    if (r.width <= 0 || r.height <= 0) {
      continue;
    }
    const node = document.createElement('div');
    node.style.position = 'absolute';
    node.style.left = `${Math.round(r.left + window.scrollX)}px`;
    node.style.top = `${Math.round(r.top + window.scrollY)}px`;
    node.style.width = `${Math.max(1, Math.round(r.width))}px`;
    node.style.height = `${Math.max(1, Math.round(r.height))}px`;
    node.style.background = 'rgba(120,170,255,0.35)';
    root.appendChild(node);
    preciseState.overlay.selectionNodes.push(node);
  }
  domRange.detach();
}

function renderCaret(index) {
  const caret = preciseState.overlay.caret;
  if (!caret) {
    return;
  }
  const rect = caretRectForIndex(index);
  if (!rect) {
    caret.style.display = 'none';
    return;
  }
  caret.style.display = 'block';
  caret.style.left = `${Math.round(rect.left + window.scrollX)}px`;
  caret.style.top = `${Math.round(rect.top + window.scrollY)}px`;
  caret.style.height = `${Math.max(1, Math.round(rect.height || preciseState.lineHeight))}px`;
  if (preciseState.suppressAutoScrollOnce) {
    preciseState.suppressAutoScrollOnce = false;
  } else {
    ensureCaretVisible(rect);
  }
}

function scheduleRender() {
  if (preciseState.pendingRender) {
    return;
  }
  preciseState.pendingRender = true;
  window.requestAnimationFrame(() => {
    preciseState.pendingRender = false;
    if (!preciseState.enabled) {
      return;
    }
    ensureOverlay();
    if (preciseState.lastCursorIndex !== null) {
      renderCaret(preciseState.lastCursorIndex);
    }
    if (preciseState.lastSelection) {
      renderSelection(preciseState.lastSelection);
    } else {
      clearSelectionOverlay();
    }
  });
}

function handlePreciseUpdate(payload) {
  if (!payload || typeof payload !== 'object') {
    return;
  }
  console.log('[mini-browser] precise update', payload);
  if (payload.type === 'mode') {
    preciseState.enabled = !!payload.enabled;
    if (!preciseState.enabled) {
      preciseState.lastSelection = null;
      if (preciseState.overlay.caret) {
        preciseState.overlay.caret.style.display = 'none';
      }
      clearSelectionOverlay();
    } else {
      ensureOverlay();
    }
    return;
  }
  if (payload.type === 'rebuild') {
    if (preciseState.building) {
      return;
    }
    preciseState.building = true;
    try {
      const result = buildMapping();
      preciseState.indexMap = result.indexMap;
      preciseState.lines = result.lines;
      ipcRenderer.sendToHost('mini-browser:precise-map', {
        lines: result.lines,
        lineHeight: result.lineHeight,
      });
    } finally {
      preciseState.building = false;
    }
    scheduleRender();
    return;
  }
  if (!preciseState.enabled) {
    return;
  }
  ensureOverlay();
  if (payload.type === 'cursor') {
    const index = Number(payload.index);
    if (Number.isFinite(index)) {
      preciseState.lastCursorIndex = Math.max(0, index);
      scheduleRender();
    }
    return;
  }
  if (payload.type === 'selection') {
    if (payload.clear) {
      preciseState.lastSelection = null;
      clearSelectionOverlay();
      return;
    }
    const start = Number(payload.start);
    const end = Number(payload.end);
    if (Number.isFinite(start) && Number.isFinite(end)) {
      preciseState.lastSelection = {
        start: Math.max(0, start),
        end: Math.max(0, end),
      };
      scheduleRender();
    }
    return;
  }
  if (payload.type === 'scroll') {
    const lines = Number(payload.lines);
    if (Number.isFinite(lines) && lines !== 0) {
      updateLineHeight();
      preciseState.suppressAutoScrollOnce = true;
      window.scrollBy(0, lines * preciseState.lineHeight);
      scheduleRender();
    }
  }
}

ipcRenderer.on('mini-browser:precise-update', (_event, payload) => {
  handlePreciseUpdate(payload);
});

window.addEventListener('scroll', () => {
  if (preciseState.enabled) {
    scheduleRender();
  }
}, true);

window.addEventListener('resize', () => {
  if (preciseState.enabled) {
    scheduleRender();
  }
}, true);
