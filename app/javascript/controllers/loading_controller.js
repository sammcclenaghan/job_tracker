import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="loading"
export default class extends Controller {
  static targets = ["button", "spinner", "text"]
  static values = { loadingText: { type: String, default: "Generating..." } }

  submit() {
    // Disable button
    this.buttonTarget.disabled = true
    this.buttonTarget.classList.add("opacity-75", "cursor-wait")

    // Show spinner, update text
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.remove("hidden")
    }
    if (this.hasTextTarget) {
      this.originalText = this.textTarget.textContent
      this.textTarget.textContent = this.loadingTextValue
    }
  }
}
