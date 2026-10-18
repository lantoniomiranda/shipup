// Browser smoke test for the appearance settings and tab drag-and-drop. Needs a running dev
// server with seeded data (see script/check_keys.mjs for how to run and the env vars).
import { spawn } from "node:child_process"

const BASE = process.env.BASE || "http://127.0.0.1:3000"
const browser = spawn(process.env.CHROMIUM_BIN || "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser",
  ["--headless=new", "--disable-gpu", "--remote-debugging-port=9336", "--window-size=1440,960", "--user-data-dir=/tmp/brave-appearance", "about:blank"], { stdio: "ignore" })
const sleep = (ms) => new Promise((r) => setTimeout(r, ms))
let tabs
for (let attempt = 0; attempt < 40 && !tabs; attempt++) {
  await sleep(500)
  tabs = await fetch("http://127.0.0.1:9336/json").then((r) => r.json()).catch(() => null)
}
if (!tabs) throw new Error("the browser did not start; set CHROMIUM_BIN")
const ws = new WebSocket(tabs.find((t) => t.type === "page").webSocketDebuggerUrl)
await new Promise((r) => (ws.onopen = r))
let id = 0; const pending = new Map()
ws.onmessage = (m) => { const d = JSON.parse(m.data); pending.get(d.id)?.(d) }
const send = (method, params = {}) => new Promise((r) => { const i = ++id; pending.set(i, r); ws.send(JSON.stringify({ id: i, method, params })) })
const ev = async (expression) => (await send("Runtime.evaluate", { expression, returnByValue: true, awaitPromise: true })).result.result.value
const go = async (url) => { await send("Page.navigate", { url }); await sleep(1800) }
const results = []
const check = (label, ok, detail = "") => results.push(`${ok ? "PASS" : "FAIL"}  ${label}${detail ? "  -> " + detail : ""}`)
const csrf = "document.querySelector('meta[name=csrf-token]').content"
const patch = (url, body) => ev(`fetch('${url}', { method: 'PATCH', headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': ${csrf} }, body: JSON.stringify(${JSON.stringify(body)}) }).then(r => r.status)`)

await send("Emulation.setDeviceMetricsOverride", { width: 1440, height: 960, deviceScaleFactor: 1, mobile: false })
await go(`${BASE}/dev/sign_in?to=/appearance`)

// 1. live preview of the choices on the appearance page
await ev("document.querySelector('input[name=\"preference[font]\"][value=mono]').click()")
check("font radio sets data-font", (await ev("document.documentElement.dataset.font")) === "mono")
await ev("document.querySelector('input[name=\"preference[corners]\"][value=round]').click()")
check("corners radio sets data-corners", (await ev("document.documentElement.dataset.corners")) === "round")
check("round corners change the radius token", (await ev("getComputedStyle(document.documentElement).getPropertyValue('--radius-sm').trim()")) === "12px")
await ev("(() => { const el = document.querySelector('input[type=color]'); el.value = '#3366cc'; el.dispatchEvent(new Event('input', { bubbles: true })) })()")
check("custom colour applies live", (await ev("document.documentElement.dataset.accent")) === "custom" && (await ev("document.documentElement.style.getPropertyValue('--accent')")) === "#3366cc")
await ev("document.querySelector('input[name=\"preference[density]\"][value=compact]').click()")
check("compact density sets the zoom", (await ev("document.documentElement.style.getPropertyValue('--zoom')")).startsWith("0.92"))
await ev("document.querySelector('input[name=\"preference[theme_bg]\"][value=night]').click()")
check("night background applies", (await ev("getComputedStyle(document.body).backgroundColor")) !== "rgb(243, 234, 216)")

// 2. saving, then the layout still fills the window when zoomed (compact + large text)
await patch("/appearance", { preference: { theme_bg: "paper", theme_accent: "orange", font: "exo", density: "compact", text_size: "large", corners: "square" } })
await ev(`fetch('/appearance', { method: 'PATCH', headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'X-CSRF-Token': ${csrf} }, body: 'preference[density]=compact&preference[text_size]=large' })`)
await go(`${BASE}/projects/APO/topics`)
const sizes = JSON.parse(await ev("JSON.stringify({ shell: document.querySelector('.shell').getBoundingClientRect().height, window: innerHeight, zoom: getComputedStyle(document.documentElement).zoom })"))
check("zoomed shell still fills the window", Math.abs(sizes.shell - sizes.window) <= 2, JSON.stringify(sizes))
await ev(`fetch('/appearance', { method: 'PATCH', headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'X-CSRF-Token': ${csrf} }, body: 'reset=1' })`)

// 3. drag and drop of the project tabs
await go(`${BASE}/projects/APO/topics`)
const order = () => ev("JSON.stringify([...document.querySelectorAll('.tabs .tab')].map(t => t.dataset.tabKey))")
const before = JSON.parse(await order())
await ev(`(() => {
  const tabs = [...document.querySelectorAll('.tabs .tab')]
  const dt = new DataTransfer()
  const fire = (el, type, x) => el.dispatchEvent(new DragEvent(type, { bubbles: true, cancelable: true, dataTransfer: dt, clientX: x }))
  const source = tabs.find(t => t.dataset.tabKey === 'analytics')
  const target = tabs[0]
  fire(source, 'dragstart', 0)
  fire(target, 'dragover', target.getBoundingClientRect().left + 2)
  fire(source, 'dragend', 0)
})()`)
await sleep(800)
const after = JSON.parse(await order())
check("dragging a tab reorders the DOM", after[0] === "analytics" && before[0] === "topics", after.join(","))
await go(`${BASE}/projects/APO/board`)
const persisted = JSON.parse(await order())
check("the order is remembered on other pages", persisted[0] === "analytics", persisted.join(","))
await ev(`fetch('/preferences/project_tabs', { method: 'DELETE', headers: { 'X-CSRF-Token': ${csrf} } })`)
await go(`${BASE}/projects/APO/board`)
check("reset restores the default order", JSON.parse(await order())[0] === "topics")

console.log(results.join("\n"))
const failed = results.filter((line) => line.startsWith("FAIL")).length
console.log(failed ? `${failed} check(s) failed` : "All appearance checks pass")
browser.kill(); process.exit(failed ? 1 : 0)
