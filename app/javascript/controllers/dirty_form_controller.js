import { Controller } from "@hotwired/stimulus"

// Shows an "Unsaved changes" flag once any field changes, and live-previews the chosen avatar.
export default class extends Controller {
  static targets = ["flag", "avatarPreview"]

  connect() {
    this.element.addEventListener("input", () => this.markDirty())
    this.element.addEventListener("change", () => this.markDirty())
  }

  markDirty() {
    this.flagTarget.hidden = false
  }

  preview({ currentTarget }) {
    const preview = this.avatarPreviewTarget
    if (currentTarget.dataset.hue) preview.className = preview.className.replace(/avatar--\w+/, `avatar--${currentTarget.dataset.hue}`)
    if (currentTarget.dataset.icon) {
      const source = currentTarget.closest("label").querySelector("svg")
      preview.innerHTML = source.outerHTML.replace(/width="\d+"/, 'width="44"').replace(/height="\d+"/, 'height="44"')
    }
  }
}
