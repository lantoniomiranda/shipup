import { Controller } from "@hotwired/stimulus"

// Email chips: type an address and press Enter / comma / Tab (or leave the field) to add it.
export default class extends Controller {
  static targets = ["entry", "template", "item"]

  focus() {
    this.entryTarget.focus()
  }

  keydown(event) {
    if (["Enter", ",", "Tab"].includes(event.key) && this.entryTarget.value.trim()) {
      event.preventDefault()
      this.commit()
    } else if (event.key === "Backspace" && !this.entryTarget.value && this.itemTargets.length) {
      this.itemTargets.at(-1).remove()
    }
  }

  commit() {
    const value = this.entryTarget.value.trim().replace(/,$/, "").toLowerCase()
    if (!value || !this.entryTarget.checkValidity()) return
    const duplicate = this.itemTargets.some((item) => item.querySelector("input").value === value)
    if (!duplicate) this.entryTarget.insertAdjacentHTML("beforebegin", this.templateTarget.innerHTML.replaceAll("EMAIL", value))
    this.entryTarget.value = ""
  }

  remove({ currentTarget }) {
    currentTarget.closest("[data-tags-target='item']").remove()
  }
}
