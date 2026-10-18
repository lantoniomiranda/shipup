import { Controller } from "@hotwired/stimulus"

// Quick-search palette. Open with "/" or Ctrl/Cmd+Space (or the top-bar hint); type to search,
// Up/Down to move, Enter to open, Tab to cycle the filter tabs, Esc to close.
export default class extends Controller {
  static targets = ["root", "input", "frame", "result", "tab"]
  static values = { url: String, key: { type: String, default: "/" } }

  // The controller sits on the whole shell so the top-bar hint can open it too.
  openFromTopBar() {
    this.open()
  }

  keydown(event) {
    const typing = ["INPUT", "TEXTAREA", "SELECT"].includes(event.target.tagName) || event.target.isContentEditable
    if (this.rootTarget.hidden) {
      if ((event.key === this.keyValue && !typing && !event.metaKey && !event.ctrlKey) || (event.key === " " && (event.ctrlKey || event.metaKey))) {
        event.preventDefault()
        this.open()
      }
      return
    }

    if (event.key === "Escape") this.close()
    else if (event.key === "ArrowDown") this.move(event, 1)
    else if (event.key === "ArrowUp") this.move(event, -1)
    else if (event.key === "Tab") this.cycleTab(event)
    else if (event.key === "Enter") this.openSelected(event)
  }

  open() {
    this.rootTarget.hidden = false
    this.filter = "everything"
    this.inputTarget.focus()
    this.inputTarget.select()
    this.load()
  }

  close() {
    this.rootTarget.hidden = true
    this.inputTarget.value = ""
  }

  backdrop(event) {
    if (event.target === this.rootTarget) this.close()
  }

  search() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.load(), 200)
  }

  load() {
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("q", this.inputTarget.value)
    url.searchParams.set("scope", this.filter)
    this.frameTarget.src = url.pathname + url.search
    this.index = -1
    // Highlight the first result once the frame has loaded.
    this.frameTarget.addEventListener("turbo:frame-load", () => this.select(0), { once: true })
  }

  move(event, step) {
    event.preventDefault()
    if (!this.hasResultTarget) return
    this.select((this.index + step + this.resultTargets.length) % this.resultTargets.length)
  }

  select(index) {
    if (!this.hasResultTarget) return
    this.index = index
    this.resultTargets.forEach((el, i) => el.classList.toggle("spotlight__result--active", i === index))
    this.resultTargets[index]?.scrollIntoView({ block: "nearest" })
  }

  openSelected(event) {
    if (this.index >= 0 && this.resultTargets[this.index]) {
      event.preventDefault()
      this.resultTargets[this.index].click()
    }
  }

  cycleTab(event) {
    if (!this.hasTabTarget) return
    event.preventDefault()
    const tabs = this.tabTargets
    const current = tabs.findIndex((tab) => tab.classList.contains("spotlight__tab--active"))
    const next = tabs[(current + (event.shiftKey ? -1 : 1) + tabs.length) % tabs.length]
    this.filter = new URL(next.href).searchParams.get("scope")
    next.click()
    this.frameTarget.addEventListener("turbo:frame-load", () => this.select(0), { once: true })
  }
}
