import { Controller } from "@hotwired/stimulus"

// Per-segment tooltip on the home progress bar.
// - click pins the tooltip open (touch + keyboard friendly)
// - clicking outside dismisses any pinned tooltip
// - flips horizontal anchor when the natural position overflows the viewport
export default class extends Controller {
  static targets = ["tooltip"]

  connect() {
    this.boundDocumentClick = this.handleDocumentClick.bind(this)
    this.boundMeasure = this.measure.bind(this)
    document.addEventListener("click", this.boundDocumentClick)
    window.addEventListener("resize", this.boundMeasure)
    requestAnimationFrame(this.boundMeasure)
  }

  disconnect() {
    document.removeEventListener("click", this.boundDocumentClick)
    window.removeEventListener("resize", this.boundMeasure)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    const wasPinned = this.element.classList.contains("is-pinned")
    document.querySelectorAll(".heist-progress__seg-wrap.is-pinned")
      .forEach((el) => el.classList.remove("is-pinned"))
    if (!wasPinned) {
      this.element.classList.add("is-pinned")
      this.measure()
    }
  }

  handleDocumentClick(event) {
    if (this.element.contains(event.target)) return
    this.element.classList.remove("is-pinned")
  }

  measure() {
    if (!this.hasTooltipTarget) return
    this.tooltipTarget.classList.remove("is-flipped")
    const rect = this.tooltipTarget.getBoundingClientRect()
    if (rect.right > window.innerWidth - 8) {
      this.tooltipTarget.classList.add("is-flipped")
    }
  }
}
