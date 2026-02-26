import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["ollamaSettings"]

  toggle() {
    const selects = this.element.querySelectorAll('select[name^="providers["]')
    const anyOllama = Array.from(selects).some(s => s.value === "ollama")
    this.ollamaSettingsTarget.classList.toggle("hidden", !anyOllama)
  }
}
