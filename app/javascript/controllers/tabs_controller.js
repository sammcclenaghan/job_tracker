import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["tab", "panel"];
  static values = { active: { type: String, default: "" } };

  connect() {
    if (this.activeValue) {
      this.show(this.activeValue);
    } else if (this.tabTargets.length > 0) {
      this.show(this.tabTargets[0].dataset.tabsId);
    }
  }

  select(event) {
    event.preventDefault();
    this.show(event.currentTarget.dataset.tabsId);
  }

  show(id) {
    this.tabTargets.forEach((tab) => {
      if (tab.dataset.tabsId === id) {
        tab.classList.add("border-gh-green", "text-gray-900");
        tab.classList.remove("border-transparent", "text-gray-500", "hover:text-gray-700", "hover:border-gray-300");
      } else {
        tab.classList.remove("border-gh-green", "text-gray-900");
        tab.classList.add("border-transparent", "text-gray-500", "hover:text-gray-700", "hover:border-gray-300");
      }
    });

    this.panelTargets.forEach((panel) => {
      panel.classList.toggle("hidden", panel.dataset.tabsId !== id);
    });

    this.activeValue = id;
  }
}
