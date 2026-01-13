import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="clipboard"
export default class extends Controller {
  static targets = ["source", "button"]
  static values = { successText: { type: String, default: "Copied!" } }

  copy() {
    const text = this.sourceTarget.textContent
    
    navigator.clipboard.writeText(text).then(() => {
      this.showSuccess()
    }).catch(() => {
      // Fallback for older browsers
      this.fallbackCopy(text)
    })
  }

  fallbackCopy(text) {
    const textarea = document.createElement("textarea")
    textarea.value = text
    textarea.style.position = "fixed"
    textarea.style.opacity = "0"
    document.body.appendChild(textarea)
    textarea.select()
    document.execCommand("copy")
    document.body.removeChild(textarea)
    this.showSuccess()
  }

  showSuccess() {
    const originalText = this.buttonTarget.textContent
    this.buttonTarget.textContent = this.successTextValue
    this.buttonTarget.classList.add("bg-green-600")
    this.buttonTarget.classList.remove("bg-gray-700", "hover:bg-gray-600")
    
    setTimeout(() => {
      this.buttonTarget.textContent = originalText
      this.buttonTarget.classList.remove("bg-green-600")
      this.buttonTarget.classList.add("bg-gray-700", "hover:bg-gray-600")
    }, 2000)
  }
}
