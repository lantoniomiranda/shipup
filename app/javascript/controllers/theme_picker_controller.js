import { Controller } from "@hotwired/stimulus"

// Live preview for the Appearance page: every choice is applied to <html> straight away (the whole
// page is the preview). Saving is a normal form submit; leaving without saving restores the saved
// look on the next page load. Mirrors what the Appearance model renders on the server.
export default class extends Controller {
  static targets = ["density", "text", "customRadio", "customChip", "customColor"]
  static values = { density: Object, text: Object, fonts: Object }

  get root() {
    return document.documentElement
  }

  // Radios and switches that map to a data attribute: data-attr plus, for switches, data-on / data-off.
  apply({ currentTarget }) {
    const el = currentTarget
    const value = el.type === "checkbox" ? (el.checked ? el.dataset.on : el.dataset.off) : el.value
    this.root.setAttribute(el.dataset.attr, value)
  }

  accent({ currentTarget }) {
    const custom = currentTarget.value === "custom"
    this.root.setAttribute("data-accent", currentTarget.value)
    custom ? this.paintCustom(this.customColorTarget.value) : this.clearCustom()
  }

  custom({ currentTarget }) {
    this.customRadioTarget.checked = true
    this.root.setAttribute("data-accent", "custom")
    this.customChipTarget.style.background = currentTarget.value
    this.paintCustom(currentTarget.value)
  }

  font({ currentTarget }) {
    this.apply({ currentTarget })
    const family = this.fontsValue[currentTarget.value]
    if (family && !document.querySelector(`link[data-font-preview="${currentTarget.value}"]`)) {
      const link = document.createElement("link")
      link.rel = "stylesheet"
      link.dataset.fontPreview = currentTarget.value
      link.href = `https://fonts.googleapis.com/css2?family=${family}&display=swap`
      document.head.appendChild(link)
    }
  }

  zoom() {
    const checked = (targets) => targets.find((el) => el.checked)?.value
    const factor = (this.densityValue[checked(this.densityTargets)] || 1) * (this.textValue[checked(this.textTargets)] || 1)
    this.root.style.setProperty("--zoom", factor.toFixed(4))
  }

  paintCustom(color) {
    const style = this.root.style
    style.setProperty("--accent", color)
    style.setProperty("--accent-soft", `color-mix(in srgb, ${color} 28%, var(--surface))`)
    style.setProperty("--accent-ink", `color-mix(in srgb, ${color} 62%, var(--ink))`)
    style.setProperty("--accent-tint", `color-mix(in srgb, ${color} 12%, var(--surface))`)
    style.setProperty("--accent-a55", `${color}55`)
    style.setProperty("--on-accent", this.readableOn(color))
  }

  clearCustom() {
    ;["--accent", "--accent-soft", "--accent-ink", "--accent-tint", "--accent-a55", "--on-accent"].forEach((name) => this.root.style.removeProperty(name))
  }

  // Same WCAG luminance rule as Appearance#readable_on.
  readableOn(hex) {
    const [r, g, b] = hex.replace("#", "").match(/../g).map((pair) => parseInt(pair, 16) / 255).map((c) => (c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b > 0.35 ? "#2B211A" : "#FFFFFF"
  }
}
