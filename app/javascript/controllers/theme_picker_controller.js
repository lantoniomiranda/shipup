import { Controller } from "@hotwired/stimulus"

// Applies the picked background/accent to <html> immediately so the whole page is a live preview.
// Cancelling (leaving without saving) restores the saved values when the page is next rendered.
export default class extends Controller {
  preview({ currentTarget }) {
    document.documentElement.setAttribute(currentTarget.dataset.attribute, currentTarget.dataset.value)
  }
}
