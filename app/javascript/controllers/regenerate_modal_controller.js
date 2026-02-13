import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["modal", "feedback", "button", "spinner", "text"];

  open() {
    this.modalTarget.classList.remove("hidden");
    this.feedbackTarget.focus();
  }

  close() {
    this.modalTarget.classList.add("hidden");
    this.feedbackTarget.value = "";
  }

  closeOnBackdrop(event) {
    if (event.target === this.modalTarget) {
      this.close();
    }
  }

  submit(event) {
    if (this.feedbackTarget.value.trim() === "") {
      event.preventDefault();
      this.feedbackTarget.focus();
      return;
    }

    this.buttonTarget.disabled = true;
    this.buttonTarget.classList.add("opacity-75", "cursor-wait");
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.remove("hidden");
    }
    if (this.hasTextTarget) {
      this.textTarget.textContent = "Regenerating...";
    }
  }

  closeOnEscape(event) {
    if (event.key === "Escape") {
      this.close();
    }
  }
}
