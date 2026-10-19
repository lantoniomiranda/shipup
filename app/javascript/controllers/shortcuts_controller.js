import { Controller } from "@hotwired/stimulus"

// The "?" cheat-sheet dialog. Closes with Esc, a backdrop click or the close button. The filter box
// narrows the list by action, key or section; it is focused on open when there is a real keyboard.
export default class extends Controller {
  static targets = ["root", "filter", "section", "item", "empty"]

  connect() {
    this.onKeydown = (event) => event.key === "Escape" && !this.rootTarget.hidden && this.close()
    document.addEventListener("keydown", this.onKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
  }

  toggle() {
    this.rootTarget.hidden ? this.open() : this.close()
  }

  open() {
    this.rootTarget.hidden = false
    this.reset()
    // Wait a frame so the "?" that opened the sheet is not typed into the box.
    if (window.matchMedia("(hover: hover)").matches) requestAnimationFrame(() => this.hasFilterTarget && this.filterTarget.focus())
  }

  close() {
    this.rootTarget.hidden = true
  }

  backdrop(event) {
    if (event.target === this.rootTarget) this.close()
  }

  filter() {
    const query = this.filterTarget.value.toLowerCase().trim().replace(/\s+/g, " ") // "g b" finds the chord, "board" the action
    this.itemTargets.forEach((item) => {
      item.hidden = !(item.dataset.search || "").includes(query)
    })
    let visible = 0
    this.sectionTargets.forEach((section) => {
      const shown = section.querySelectorAll("[data-shortcuts-target~=item]:not([hidden])").length
      section.hidden = shown === 0
      visible += shown
    })
    this.emptyTarget.hidden = visible > 0
  }

  reset() {
    if (!this.hasFilterTarget || !this.filterTarget.value) return
    this.filterTarget.value = ""
    this.filter()
  }
}
