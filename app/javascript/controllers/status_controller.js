import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["button"];
  static values = { current: String };

  select(event) {
    event.preventDefault();

    const button = event.currentTarget;
    const status = button.dataset.status;
    const url = button.dataset.url;

    this.buttonTargets.forEach((btn) => {
      btn.classList.remove("bg-gh-green", "border-gh-green", "text-white");
      btn.classList.add(
        "border-gray-300",
        "text-gray-500",
        "hover:bg-gray-100",
        "hover:text-gray-700",
      );
    });

    button.classList.remove(
      "border-gray-300",
      "text-gray-500",
      "hover:bg-gray-100",
      "hover:text-gray-700",
    );
    button.classList.add("bg-gh-green", "border-gh-green", "text-white");

    fetch(url, {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')
          .content,
        Accept: "application/json",
      },
    })
      .then((response) => {
        if (!response.ok) {
          this.revertUI(button);
        }
      })
      .catch(() => {
        this.revertUI(button);
      });
  }

  revertUI(button) {
    button.classList.remove("bg-gh-green", "border-gh-green", "text-white");
    button.classList.add(
      "border-gray-300",
      "text-gray-500",
      "hover:bg-gray-100",
      "hover:text-gray-700",
    );
  }
}
