#!/usr/bin/env node
// accept-drive.mjs — drive the finished app's UNIFORM acceptance battery
// AS A USER WOULD, on camera, and score it. (harness v1.6.26, catMarvin S721)
//
// Method (decided S721): keyboard-first for basic arithmetic (a GRADED
// PROJECT-BRIEF requirement — "Keyboard entry works"), button-click fallback
// for scientific functions the keyboard spec does not guarantee. Everything
// runs through Safari `do JavaScript` (one Automation TCC path + the Safari
// "Allow JavaScript from Apple Events" pref — no Accessibility needed). One
// osascript call PER keystroke/click with a delay between, so entry is visible
// and human-paced on the recording.
//
// Usage: node accept-drive.mjs <spec.json> [--out <results.json>] [--txt <acceptance.txt>]
//   Exit 0  = ran (see results.json for per-test pass/fail).
//   Exit 2  = could not drive Safari (Automation not granted / JS-from-AppleEvents
//             off / no front document) -> caller should fall back to MANUAL entry.
//             acceptance.txt is still written so the guide + manual path work.

import { readFileSync, writeFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';

const args = process.argv.slice(2);
const specPath = args[0];
const outPath = argVal('--out') || `${process.env.HOME}/tta/acceptance-results.json`;
const txtPath = argVal('--txt') || `${process.env.HOME}/tta/acceptance.txt`;
function argVal(f){ const i = args.indexOf(f); return i >= 0 ? args[i+1] : null; }

if (!specPath) { console.error('accept-drive: no spec.json given'); process.exit(2); }
const spec = JSON.parse(readFileSync(specPath, 'utf8'));
const TYPE_DELAY = spec.typeDelayMs ?? 190;
const SETTLE = spec.settleMs ?? 650;

// ---- always write the human-readable battery (guide render + manual fallback) ----
writeAcceptanceTxt();

// ---- the JS helper library injected into the page (idempotent, single-line-safe) ----
// No comments, every statement ;-terminated: the osascript escaper flattens
// newlines to spaces, so comments or bare newlines would corrupt it.
const LIB = `
window.__tta = (function(){
  function keyInfo(ch){
    var map = {
      '+':{key:'+',code:'NumpadAdd',kc:107}, '-':{key:'-',code:'NumpadSubtract',kc:109},
      '*':{key:'*',code:'NumpadMultiply',kc:106}, '/':{key:'/',code:'NumpadDivide',kc:111},
      '.':{key:'.',code:'Period',kc:190}, '(':{key:'(',code:'Digit9',kc:57},
      ')':{key:')',code:'Digit0',kc:48}, '=':{key:'=',code:'Equal',kc:187},
      '!':{key:'!',code:'Digit1',kc:49}, 'Enter':{key:'Enter',code:'Enter',kc:13},
      'Escape':{key:'Escape',code:'Escape',kc:27}
    };
    if (map[ch]) return map[ch];
    if (ch >= '0' && ch <= '9') return {key:ch,code:'Digit'+ch,kc:48+(+ch)};
    return {key:ch,code:'Key'+ch.toUpperCase(),kc:ch.toUpperCase().charCodeAt(0)};
  }
  function fireOne(ch){
    var info = keyInfo(ch);
    var targets = [document, document.activeElement && document.activeElement !== document.body ? document.activeElement : null].filter(Boolean);
    var t2 = document.querySelector("input, [contenteditable='true']");
    if (t2 && targets.indexOf(t2) < 0) targets.push(t2);
    ['keydown','keypress','keyup'].forEach(function(type){
      targets.forEach(function(tg){
        try {
          var e = new KeyboardEvent(type, {key:info.key, code:info.code, keyCode:info.kc, which:info.kc, bubbles:true, cancelable:true, composed:true});
          tg.dispatchEvent(e);
        } catch(_){}
      });
    });
    var inp = document.activeElement;
    if (inp && (inp.tagName === 'INPUT' || inp.isContentEditable) && ch.length === 1 && '0123456789.+-*/()!'.indexOf(ch) >= 0){
      try { document.execCommand && document.execCommand('insertText', false, ch); } catch(_){}
    }
    return true;
  }
  function key(ch){ if (ch === '=') { fireOne('='); fireOne('Enter'); return true; } return fireOne(ch); }
  function norm(s){ return (s||'').replace(/\\s+/g,'').toLowerCase(); }
  function click(labels){
    var els = Array.prototype.slice.call(document.querySelectorAll("button, [role='button'], a, .btn, .key, [data-key], [data-value]"));
    els = els.filter(function(el){ return el.offsetParent !== null; });
    for (var i=0;i<labels.length;i++){
      var want = norm(labels[i]);
      var m = els.find(function(el){ return norm(el.getAttribute('data-key')||el.getAttribute('data-value')||'') === want || norm(el.textContent) === want; });
      if (!m) m = els.find(function(el){ var t = norm(el.textContent); return t.length && t.length <= want.length + 2 && t.indexOf(want) >= 0; });
      if (m){ m.click(); return {ok:true, hit:(m.textContent||'').trim().slice(0,12)}; }
    }
    return {ok:false, hit:null};
  }
  function inHistory(el){
    var n = el;
    while (n && n !== document.body){
      if (n.tagName === 'LI' || n.tagName === 'UL' || n.tagName === 'OL') return true;
      var c = (n.getAttribute && n.getAttribute('class')) || '';
      if (c && /history|tape|past|recent|entries|entry/i.test(c)) return true;
      n = n.parentElement;
    }
    return false;
  }
  function read(selectors){
    // Calculators often reuse the same class (e.g. .result) for the LIVE display
    // AND every entry in a history tape. Exclude anything inside a history/list
    // ancestor, and take the FIRST (most-specific-selector) live match — not the
    // last, which was the stale history entry (S721 calc-A-basic-3 frozen-5 bug).
    var cand = [];
    (selectors||[]).forEach(function(s){
      try { document.querySelectorAll(s).forEach(function(el){
        if (inHistory(el)) return;
        var v = (el.value !== undefined && el.value !== '') ? el.value : el.textContent;
        v = (v||'').trim(); if (v) cand.push(v);
      }); } catch(_){}
    });
    var chosen = cand.length ? cand[0] : null;
    if (chosen === null){
      var best = null, all = document.querySelectorAll('*');
      for (var i=0;i<all.length;i++){
        var el = all[i]; if (el.children.length) continue; if (inHistory(el)) continue;
        var t = (el.textContent||'').trim();
        if (/^-?[0-9][0-9.,]*(e[-+]?[0-9]+)?$/i.test(t)){
          if (!best || t.length > best.length) best = t;
        }
      }
      chosen = best;
    }
    return JSON.stringify({chosen: chosen, candidates: cand.slice(0,6)});
  }
  return {key:key, click:click, read:read, ping:function(){return 'ok';}};
})(); 'tta-ready';
`;

function osa(js){
  const escaped = js.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, ' ');
  const script = `tell application "Safari" to do JavaScript "${escaped}" in front document`;
  return execFileSync('osascript', ['-e', script], { encoding: 'utf8', timeout: 10000 }).trim();
}
const sleep = (ms) => execFileSync('sleep', [String(ms / 1000)]);

// ---- preflight: is Safari drivable at all? ----
let driverOk = false;
try {
  osa(LIB);
  const p = osa(`(window.__tta && window.__tta.ping && window.__tta.ping()) || 'no'`);
  driverOk = (p === 'ok');
} catch (e) {
  console.error('accept-drive: Safari not drivable —', String(e.message || e).split('\n')[0]);
}
if (!driverOk){
  console.error('accept-drive: FALLING BACK TO MANUAL. Fix on the golden image:');
  console.error('  1) Safari > Settings > Advanced > "Allow JavaScript from Apple Events" (Develop menu).');
  console.error('  2) Approve the Terminal->Safari Automation prompt once.');
  process.exit(2);
}

// ---- run the battery ----
const results = [];
console.log('  ▶ auto-driving the acceptance battery (as a user would)...');
for (const t of spec.tests){
  process.stdout.write(`    ${t.id} ${t.label} ... `);
  clearCalc();
  sleep(280);
  let drove = false;
  const attempts = t.method === 'keyboard' ? [{ kind: 'keys', v: t.keys }]
    : t.method === 'keyboard-then-click' ? [{ kind: 'keys', v: t.keys }, ...(t.tries || []).map(seq => ({ kind: 'clicks', v: seq }))]
    : (t.tries || []).map(seq => ({ kind: 'clicks', v: seq }));

  let best = { pass: false, read: null, via: null };
  for (const a of attempts){
    clearCalc(); sleep(220);
    try {
      if (a.kind === 'keys'){ for (const ch of a.v) { osa(`window.__tta.key(${JSON.stringify(ch)})`); sleep(TYPE_DELAY); } }
      else {
        // a click SEQUENCE mixes digits/operators (which must be TYPED) with
        // function labels (which must be CLICKED). Type keyable tokens, click labels.
        for (const tok of a.v){
          if (isKeyable(tok)){ for (const ch of tok) { osa(`window.__tta.key(${JSON.stringify(ch)})`); sleep(TYPE_DELAY); } }
          else { osa(`JSON.stringify(window.__tta.click([${JSON.stringify(tok)}]))`); sleep(TYPE_DELAY); }
        }
      }
      drove = true;
      sleep(SETTLE);
      const raw = osa(`window.__tta.read(${JSON.stringify(spec.read.selectors)})`);
      const parsed = JSON.parse(raw);
      const ok = compare(parsed.chosen, t.expect, t.tol);
      best = { pass: ok, read: parsed.chosen, via: a.kind === 'keys' ? 'keyboard' : 'click', candidates: parsed.candidates };
      if (ok) break;
    } catch (e){ best.err = String(e.message || e).split('\n')[0]; }
  }
  const status = best.pass ? 'PASS' : (drove ? 'FAIL' : 'COULD-NOT-DRIVE');
  results.push({ id: t.id, group: t.group, label: t.label, expect: t.expect, got: best.read, via: best.via, status });
  console.log(`${best.pass ? '✅ PASS' : (drove ? '❌ FAIL (got ' + best.read + ')' : '⚠️ could not drive')}`);
}
clearCalc();

const passed = results.filter(r => r.status === 'PASS').length;
const summary = { battery: spec.battery, ran_at_utc: new Date().toISOString(), driver: 'accept-drive.mjs', total: results.length, passed, results };
writeFileSync(outPath, JSON.stringify(summary, null, 2));
console.log(`  ▶ battery: ${passed}/${results.length} passed  ->  ${outPath}`);
process.exit(0);

function isKeyable(tok){ return /^[-0-9.+*/()=]+$/.test(tok); }
function clearCalc(){
  try { osa(`window.__tta.key('Escape')`); } catch(_){}
  try { osa(`JSON.stringify(window.__tta.click(['AC','C','clear','CE']))`); } catch(_){}
}
function compare(gotStr, expect, tol){
  if (gotStr == null) return false;
  const g = parseFloat(String(gotStr).replace(/[,\s]/g, '').replace(/[^0-9eE.\-+]/g, ''));
  if (!isFinite(g)) return false;
  return Math.abs(g - Number(expect)) <= (tol ?? 1e-9);
}
function writeAcceptanceTxt(){
  const lines = [];
  let group = '';
  for (const t of spec.tests){
    if (t.group !== group){ lines.push(t.group); group = t.group; }
    lines.push('  ' + t.id + '   ' + t.label);
  }
  writeFileSync(txtPath, lines.join('\n') + '\n');
}
