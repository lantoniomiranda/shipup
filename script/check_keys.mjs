// Browser smoke test for keyboard shortcuts (not part of bin/ci: it needs a running dev server
// with seeded data and a Chromium-based browser).
//
//   bin/rails db:seed && bin/rails server -p 3000
//   node script/check_keys.mjs                      # CHROMIUM_BIN=/path/to/chrome BASE=http://127.0.0.1:3000
//
// It signs in through /dev/sign_in, presses real keys and prints PASS/FAIL per shortcut.
import { spawn } from "node:child_process"
const brave = spawn(process.env.CHROMIUM_BIN || "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser", ["--headless=new", "--disable-gpu", "--remote-debugging-port=9334", "--window-size=1440,960", "--user-data-dir=/tmp/brave-keys", "about:blank"], { stdio: "ignore" })
const BASE = process.env.BASE || "http://127.0.0.1:3000"
const sleep = (ms) => new Promise((r) => setTimeout(r, ms))
let tabs
for (let attempt = 0; attempt < 40 && !tabs; attempt++) { // wait for the browser's debug port
  await sleep(500)
  tabs = await fetch("http://127.0.0.1:9334/json").then((r) => r.json()).catch(() => null)
}
if (!tabs) throw new Error("the browser did not start; set CHROMIUM_BIN=/path/to/a/chromium-based/browser")
const ws = new WebSocket(tabs.find((t) => t.type === "page").webSocketDebuggerUrl)
await new Promise((r) => (ws.onopen = r))
let id = 0; const pending = new Map()
ws.onmessage = (m) => { const d = JSON.parse(m.data); pending.get(d.id)?.(d) }
const send = (method, params = {}) => new Promise((r) => { const i = ++id; pending.set(i, r); ws.send(JSON.stringify({ id: i, method, params })) })
const where = async () => (await send("Runtime.evaluate", { expression: "location.pathname + (document.querySelector('.spotlight:not([hidden])') ? ' [search open]' : '') + (document.querySelector('.keyhelp:not([hidden])') ? ' [help open]' : '')", returnByValue: true })).result.result.value
const press = async (key, mods = 0) => {
  const code = key.length === 1 ? { "/": "Slash", "?": "Slash" }[key] || `Key${key.toUpperCase()}` : key
  const vk = { Enter: 13, Escape: 27, ArrowRight: 39 }[key]
  const base = { key, code, text: key.length === 1 ? key : undefined, modifiers: mods, windowsVirtualKeyCode: vk }
  await send("Input.dispatchKeyEvent", { type: "keyDown", ...base })
  await send("Input.dispatchKeyEvent", { type: "keyUp", ...base })
  await sleep(700)
}
const go = async (url) => { await send("Page.navigate", { url }); await sleep(1800) }
const results = []
const check = async (label, action, expected) => { await action(); const got = await where(); results.push(`${got.includes(expected) ? "PASS" : "FAIL"}  ${label}  -> ${got}`) }

await go(`${BASE}/dev/sign_in?to=/projects/APO/topics`)
await check("g b -> board", async () => { await press("g"); await press("b") }, "/projects/APO/board")
await check("g l -> backlog", async () => { await press("g"); await press("l") }, "/projects/APO/backlog")
await check("g m -> timeline", async () => { await press("g"); await press("m") }, "/projects/APO/timeline")
await check("g c -> clients", async () => { await press("g"); await press("c") }, "/projects/APO/clients")
await check("g a -> analytics", async () => { await press("g"); await press("a") }, "/projects/APO/analytics")
await check("g t -> topics", async () => { await press("g"); await press("t") }, "/projects/APO/topics")
await check("n -> new topic", async () => { await press("n") }, "/projects/APO/topics/new")
await check("Esc -> back to topics", async () => { await press("Escape") }, "/projects/APO/topics")
await check("g o -> time off", async () => { await press("g"); await press("o") }, "/time_off")
await check("g u -> account", async () => { await press("g"); await press("u") }, "/account")
await check("g h -> projects", async () => { await press("g"); await press("h") }, "/")
await check("1 -> open project 1", async () => { await press("1") }, "/projects/APO/topics")
await check("? -> help", async () => { await press("?", 8) }, "[help open]")
await check("Esc closes help", async () => { await press("Escape") }, "/projects/APO/topics")
await check("/ -> search", async () => { await press("/") }, "[search open]")
await check("Esc closes search", async () => { await press("Escape") }, "/projects/APO/topics")
// --- remapping through the settings page -------------------------------------------------
const evaluate = async (expression) => (await send("Runtime.evaluate", { expression, returnByValue: true, awaitPromise: true })).result.result.value
await go(`${BASE}/settings/keyboard`)
await evaluate("document.querySelector('.key-capture[data-id=board]').click()")
await press("g"); await press("x")
await evaluate("document.querySelector('.key-settings').requestSubmit()")
await sleep(1500)
await go(`${BASE}/projects/APO/topics`)
await check("remapped: g x -> board", async () => { await press("g"); await press("x") }, "/projects/APO/board")
await go(`${BASE}/projects/APO/topics`)
await check("remapped: old g b no longer navigates", async () => { await press("g"); await press("b") }, "/projects/APO/topics")
await evaluate("fetch('/settings/keyboard', { method: 'DELETE', headers: { 'X-CSRF-Token': document.querySelector('meta[name=csrf-token]').content } }).then(() => 'reset')")
await go(`${BASE}/projects/APO/topics`)
await check("after reset: g b -> board again", async () => { await press("g"); await press("b") }, "/projects/APO/board")

console.log(results.join("\n"))
const failed = results.filter((line) => line.startsWith("FAIL")).length
console.log(failed ? `${failed} shortcut(s) failed` : "All shortcuts work")
brave.kill(); process.exit(failed ? 1 : 0)
