import { Controller } from "@hotwired/stimulus"

// Drag-and-drop file picker for the project banner image. Wires the visible
// dropzone to a hidden <input type="file"> and surfaces the chosen filename.
export default class extends Controller {
  static targets = ["input", "prompt", "filename"]
  static classes = ["active"]

  connect() {
    this.activeClass ||= "heist-create__dropzone--active"
  }

  open(event) {
    if (event.target === this.inputTarget) return
    this.inputTarget.click()
  }

  onChange() {
    const file = this.inputTarget.files && this.inputTarget.files[0]
    if (!file) {
      this.reset()
      return
    }
    this.filenameTarget.textContent = file.name
    this.filenameTarget.hidden = false
    this.promptTarget.hidden = true
  }

  onDragOver(event) {
    event.preventDefault()
    this.element.classList.add(this.activeClass)
  }

  onDragLeave() {
    this.element.classList.remove(this.activeClass)
  }

  onDrop(event) {
    event.preventDefault()
    this.element.classList.remove(this.activeClass)
    const files = event.dataTransfer && event.dataTransfer.files
    if (!files || files.length === 0) return
    this.inputTarget.files = files
    this.onChange()
  }

  reset() {
    this.filenameTarget.textContent = ""
    this.filenameTarget.hidden = true
    this.promptTarget.hidden = false
  }
}