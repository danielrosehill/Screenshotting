// Swap sensitive text on a live page for stand-ins, in the browser only.
// Nothing is sent to the app: a reload restores the real page.
//
// Load this file into the page (javascript_tool, DevTools console or any
// browser tool with JS evaluate), then:
//   __spoof.apply({"Real Name": "Stand-in Name", ...})  -> {replaced, warnings}
//   __spoof.verify()                                    -> {clean, hits, unspoofable}
//   __spoof.stop()                                      -> stop watching for re-renders
//
// Handles open shadow roots (web-component apps such as Lit), same-origin
// iframes, attributes, form values and the document title. A MutationObserver
// reapplies the map when a framework re-renders.
(() => {
  if (window.__spoof) window.__spoof.stop();

  const ATTRS = ['title', 'alt', 'placeholder', 'aria-label', 'aria-description', 'value', 'label', 'data-tooltip'];
  const SKIP = new Set(['SCRIPT', 'STYLE', 'NOSCRIPT', 'TEMPLATE']);
  const esc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

  let map = {}, lookup = new Map(), regex = null, count = 0;
  const observers = new Map();

  const swap = (s) => {
    if (!regex || !s) return s;
    return s.replace(regex, (m) => {
      count++;
      return lookup.get(m.toLowerCase());
    });
  };

  // Every root reachable from the document, piercing shadow DOM and iframes.
  const roots = (start = document, out = []) => {
    out.push(start);
    for (const el of start.querySelectorAll('*')) {
      if (el.shadowRoot) roots(el.shadowRoot, out);
      if (el.tagName === 'IFRAME') {
        try { if (el.contentDocument) roots(el.contentDocument, out); } catch (e) { /* cross-origin */ }
      }
    }
    return out;
  };

  const textNodes = (root) => {
    const w = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
    const out = [];
    while (w.nextNode()) {
      if (!SKIP.has(w.currentNode.parentNode?.nodeName)) out.push(w.currentNode);
    }
    return out;
  };

  const sweep = () => {
    for (const root of roots()) {
      for (const n of textNodes(root)) {
        const v = swap(n.nodeValue);
        if (v !== n.nodeValue) n.nodeValue = v;
      }
      for (const el of root.querySelectorAll('*')) {
        for (const a of ATTRS) {
          if (el.hasAttribute(a)) {
            const cur = el.getAttribute(a), v = swap(cur);
            if (v !== cur) el.setAttribute(a, v);
          }
        }
        if ('value' in el && typeof el.value === 'string' && el.value) {
          const v = swap(el.value);
          if (v !== el.value) el.value = v;
        }
      }
      if (root.nodeType === 9) {
        const v = swap(root.title);
        if (v !== root.title) root.title = v;
      }
    }
  };

  const pause = () => observers.forEach((mo) => mo.disconnect());
  const resume = () => observers.forEach((mo, root) => mo.observe(root, {
    childList: true, subtree: true, characterData: true, attributes: true, attributeFilter: ATTRS,
  }));

  const watch = () => {
    for (const root of roots()) {
      if (observers.has(root)) continue;
      observers.set(root, new MutationObserver(() => {
        pause();
        sweep();
        watch();
      }));
    }
    resume();
  };

  const apply = (newMap, { wholeWord = true } = {}) => {
    const keys = Object.keys(newMap).filter(Boolean).sort((a, b) => b.length - a.length);
    const warnings = [];
    for (const k of keys) {
      for (const other of keys) {
        if (newMap[k].toLowerCase().includes(other.toLowerCase())) {
          throw new Error(`stand-in "${newMap[k]}" contains the original "${other}": pick another`);
        }
      }
      if (k.length < 3) warnings.push(`"${k}" is very short and may hit unrelated words`);
    }
    map = newMap;
    lookup = new Map(keys.map((k) => [k.toLowerCase(), newMap[k]]));
    const body = keys.map(esc).join('|');
    regex = wholeWord
      ? new RegExp(`(?<![\\p{L}\\p{N}])(?:${body})(?![\\p{L}\\p{N}])`, 'giu')
      : new RegExp(body, 'giu');
    count = 0;
    pause();
    sweep();
    watch();
    return { replaced: count, roots: observers.size, warnings };
  };

  // Substring match, deliberately wider than apply(): false alarms beat leaks.
  const verify = (terms = Object.keys(map)) => {
    const needles = terms.map((t) => t.toLowerCase());
    const hits = [];
    const check = (where, s) => {
      if (!s) return;
      const low = s.toLowerCase();
      for (const t of needles) {
        if (low.includes(t)) hits.push({ term: t, where, context: s.slice(0, 80) });
      }
    };
    const unspoofable = { img: 0, canvas: 0, video: 0, crossOriginIframe: 0 };
    check('document.title', document.title);
    for (const root of roots()) {
      for (const n of textNodes(root)) check('text', n.nodeValue);
      for (const el of root.querySelectorAll('*')) {
        for (const a of ATTRS) if (el.hasAttribute(a)) check(`@${a}`, el.getAttribute(a));
        if ('value' in el && typeof el.value === 'string') check('value', el.value);
        if (el.tagName === 'IMG') unspoofable.img++;
        if (el.tagName === 'CANVAS') unspoofable.canvas++;
        if (el.tagName === 'VIDEO') unspoofable.video++;
        if (el.tagName === 'IFRAME') {
          try { if (!el.contentDocument) unspoofable.crossOriginIframe++; } catch (e) { unspoofable.crossOriginIframe++; }
        }
      }
      // Catches a term split across sibling elements (<b>Asp</b>irin).
      const joined = root === document ? document.body?.innerText : root.textContent;
      if (joined) check('rendered text', joined.replace(/\s+/g, ' '));
    }
    return { clean: hits.length === 0, hits: hits.slice(0, 30), unspoofable };
  };

  const stop = () => { pause(); observers.clear(); };

  window.__spoof = { apply, verify, stop };
  return 'spoof loaded';
})();
