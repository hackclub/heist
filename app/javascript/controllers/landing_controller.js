import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay", "nav", "navItem"]

  sections = ["how-it-works", "the-plan", "faqs", "credits"]
  currentIndex = -1
  scrolling = false

  connect() {
    document.body.style.overflow = "hidden"
    this.boundWheel = this.handleWheel.bind(this)
    window.addEventListener("wheel", this.boundWheel, { passive: false })
  }

  disconnect() {
    document.body.style.overflow = ""
    window.removeEventListener("wheel", this.boundWheel)
  }

  handleWheel(e) {
    e.preventDefault()
    if (this.scrolling) return
    this.scrolling = true
    setTimeout(() => { this.scrolling = false }, 600)

    if (e.deltaY > 0 && this.currentIndex < this.sections.length - 1) {
      this.currentIndex++
    } else if (e.deltaY < 0 && this.currentIndex > -1) {
      this.currentIndex--
    }
    this.updateOverlay()
  }

  open(e) {
    const section = e.currentTarget.dataset.section
    this.currentIndex = this.sections.indexOf(section)
    this.updateOverlay()
  }

  closeOnBackdrop(e) {
    if (e.target === e.currentTarget) this.close()
  }

  close() {
    this.currentIndex = -1
    this.updateOverlay()
  }

  updateOverlay() {
    const modalOpen = this.currentIndex >= 0
    this.overlayTargets.forEach((overlay, i) => {
      overlay.classList.toggle("active", i === this.currentIndex)
    })
    this.navTarget.style.visibility = modalOpen ? "visible" : "hidden"
    this.navItemTargets.forEach((item, i) => {
      item.classList.toggle("nav-active", i === this.currentIndex)
    })
    document.body.style.overflow = modalOpen ? "hidden" : ""
  }
}
