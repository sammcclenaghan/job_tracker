import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["button", "spinner", "text"];
  static values = { loadingText: { type: String, default: "Generating..." } };

  submit() {
    this.buttonTarget.disabled = true;
    this.buttonTarget.classList.add("opacity-75", "cursor-wait");

    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.remove("hidden");
    }
    if (this.hasTextTarget) {
      this.originalText = this.textTarget.textContent;
      this.textTarget.textContent = this.loadingTextValue;
    }
  }
}
