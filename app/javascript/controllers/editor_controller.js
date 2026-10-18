import { Controller } from "@hotwired/stimulus"

// Minimal markdown helper for the toolbar: wraps the selection (bold, italic) or prefixes the line (list).
export default class extends Controller {
  static targets = ["input"]
  static values = { linkSample: { type: String, default: "text" } }

  format({ params: { token, kind } }) {
    const input = this.inputTarget
    const { selectionStart: start, selectionEnd: end, value } = input
    const selected = value.slice(start, end)

    let insert
    if (kind === "bold" || kind === "italic") insert = `${token}${selected || kind}${token}`
    else if (kind === "link") insert = `[${selected || this.linkSampleValue}](https://)`
    else if (kind === "list") insert = selected ? selected.split("\n").map((line) => `- ${line}`).join("\n") : "- "
    else insert = token

    input.setRangeText(insert, start, end, "end")
    input.focus()
    input.dispatchEvent(new Event("input", { bubbles: true }))
  }
}
