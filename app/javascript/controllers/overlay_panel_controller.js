import { Controller } from "@hotwired/stimulus"
import { gsap } from "gsap"

// Dialog-style overlay over the landing hero, animated with GSAP.
// - chevron click / nav link / hash deep-link opens the panel
// - backdrop, ESC, or close button closes it
// - timelines are re-entrant: open during close or vice versa kills the prior tween
export default class extends Controller {
  static targets = ["panel", "backdrop", "frame", "link", "section"]
  static classes = ["open"]
  static values = { defaultSection: { type: String, default: "plan" } }

  connect() {
    this.boundKeydown = this.handleKeydown.bind(this)
    this.boundWheel = this.handleWheel.bind(this)
    this.boundTouchStart = this.handleTouchStart.bind(this)
    this.boundTouchMove = this.handleTouchMove.bind(this)
    this.scrollAccum = 0
    this.touchStartY = null
    this.reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches

    gsap.set(this.backdropTarget, { autoAlpha: 0 })
    gsap.set(this.frameTarget, { autoAlpha: 0, y: this.reduceMotion ? 0 : 48 })

    const initial = this.sectionFromHash() || this.defaultSectionValue
    this.activate(initial, { updateHash: false })
    if (this.sectionFromHash()) this.open()

    window.addEventListener("wheel", this.boundWheel, { passive: true })
    window.addEventListener("touchstart", this.boundTouchStart, { passive: true })
    window.addEventListener("touchmove", this.boundTouchMove, { passive: true })
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeydown)
    window.removeEventListener("wheel", this.boundWheel)
    window.removeEventListener("touchstart", this.boundTouchStart)
    window.removeEventListener("touchmove", this.boundTouchMove)
    this.killTimeline()
    this.unlockScroll()
  }

  open(event) {
    if (event) event.preventDefault()
    if (this.isOpen()) return

    this.panelTarget.classList.add(this.openClass)
    this.panelTarget.setAttribute("aria-hidden", "false")
    this.lockScroll()
    document.addEventListener("keydown", this.boundKeydown)
    this.previousFocus = document.activeElement

    this.killTimeline()
    const navLinks = this.linkTargets
    const activeSection = this.sectionTargets.find((s) => s.classList.contains("is-active"))

    this.timeline = gsap.timeline({
      defaults: { ease: "power3.out" },
      onComplete: () => {
        const activeLink = navLinks.find((l) => l.classList.contains("is-active"))
        if (activeLink) activeLink.focus({ preventScroll: true })
      }
    })
      .to(this.backdropTarget, { autoAlpha: 1, duration: 0.26 })
      .to(this.frameTarget,
          { autoAlpha: 1, y: 0, duration: this.reduceMotion ? 0.2 : 0.48 },
          "-=0.18")

    if (!this.reduceMotion) {
      this.timeline.from(navLinks,
          { autoAlpha: 0, y: 8, stagger: 0.05, duration: 0.3, ease: "power2.out" },
          "-=0.32")
      if (activeSection) {
        this.timeline.from(activeSection,
            { autoAlpha: 0, y: 12, duration: 0.34, ease: "power2.out" },
            "-=0.4")
      }
    }
  }

  close(event) {
    if (event) event.preventDefault()
    if (!this.isOpen()) return

    this.killTimeline()
    this.timeline = gsap.timeline({
      defaults: { ease: "power2.in" },
      onComplete: () => {
        this.panelTarget.classList.remove(this.openClass)
        this.panelTarget.setAttribute("aria-hidden", "true")
        this.unlockScroll()
        document.removeEventListener("keydown", this.boundKeydown)
        if (window.location.hash) {
          history.replaceState(null, "", window.location.pathname + window.location.search)
        }
        if (this.previousFocus && typeof this.previousFocus.focus === "function") {
          this.previousFocus.focus({ preventScroll: true })
        }
      }
    })
      .to(this.frameTarget,
          { autoAlpha: 0, y: this.reduceMotion ? 0 : 32, duration: 0.24 })
      .to(this.backdropTarget, { autoAlpha: 0, duration: 0.2 }, "-=0.14")
  }

  select(event) {
    event.preventDefault()
    const section = event.currentTarget.dataset.section
    if (!section) return
    this.activate(section, { updateHash: true })
  }

  activate(section, { updateHash }) {
    const nextSection = this.sectionTargets.find((s) => s.dataset.section === section)
    const prevSection = this.sectionTargets.find((s) => s.classList.contains("is-active"))

    this.linkTargets.forEach((link) => {
      const match = link.dataset.section === section
      link.classList.toggle("is-active", match)
      if (match) link.setAttribute("aria-current", "true")
      else link.removeAttribute("aria-current")
    })

    const applyState = () => {
      this.sectionTargets.forEach((panel) => {
        const match = panel.dataset.section === section
        panel.classList.toggle("is-active", match)
        panel.toggleAttribute("hidden", !match)
      })
    }

    if (!nextSection || nextSection === prevSection || this.reduceMotion || !this.isOpen()) {
      applyState()
    } else {
      gsap.to(prevSection, {
        autoAlpha: 0,
        y: -10,
        duration: 0.18,
        ease: "power2.in",
        onComplete: () => {
          applyState()
          gsap.fromTo(nextSection,
            { autoAlpha: 0, y: 12 },
            { autoAlpha: 1, y: 0, duration: 0.28, ease: "power3.out" })
        }
      })
    }

    if (updateHash) {
      history.replaceState(null, "", `#${section}`)
    }
  }

  handleKeydown(event) {
    if (event.key === "Escape") this.close()
  }

  handleWheel(event) {
    if (this.isOpen()) {
      this.scrollAccum = 0
      return
    }
    if (event.deltaY <= 0) {
      this.scrollAccum = 0
      return
    }
    this.scrollAccum += event.deltaY
    if (this.scrollAccum > 80) {
      this.scrollAccum = 0
      this.open()
    }
  }

  handleTouchStart(event) {
    if (this.isOpen()) return
    this.touchStartY = event.touches[0]?.clientY ?? null
  }

  handleTouchMove(event) {
    if (this.isOpen() || this.touchStartY === null) return
    const currentY = event.touches[0]?.clientY
    if (currentY === undefined) return
    if (this.touchStartY - currentY > 48) {
      this.touchStartY = null
      this.open()
    }
  }

  isOpen() {
    return this.panelTarget.classList.contains(this.openClass)
  }

  killTimeline() {
    if (this.timeline) {
      this.timeline.kill()
      this.timeline = null
    }
  }

  sectionFromHash() {
    const hash = window.location.hash.replace("#", "")
    const valid = this.linkTargets.some((link) => link.dataset.section === hash)
    return valid ? hash : null
  }

  lockScroll() {
    this.previousOverflow = document.body.style.overflow
    document.body.style.overflow = "hidden"
  }

  unlockScroll() {
    document.body.style.overflow = this.previousOverflow || ""
  }
}
