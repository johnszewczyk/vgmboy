(() => {
  function setAnimation(state, normalize, key, value) {
    state[key] = normalize(value);
  }

  function setWindowLevel(state, key, enabled) {
    state[key] = Boolean(enabled);
  }

  function syncToggleButtons(root = document) {
    root.querySelectorAll(".option-toggle").forEach((group) => {
      const checkbox = group.querySelector('input[type="checkbox"]');
      if (!checkbox) return;
      group.querySelectorAll("button[data-value]").forEach((button) => {
        const selected = (button.dataset.value === "true") === checkbox.checked;
        button.setAttribute("aria-pressed", selected ? "true" : "false");
        button.classList.toggle("is-selected", selected);
      });
    });
  }

  document.addEventListener("click", (event) => {
    const button = event.target.closest(".option-toggle button[data-value]");
    if (!button) return;
    const group = button.closest(".option-toggle");
    const checkbox = group?.querySelector('input[type="checkbox"]');
    if (!checkbox) return;
    checkbox.checked = button.dataset.value === "true";
    syncToggleButtons(group.parentElement);
    checkbox.dispatchEvent(new Event("change", { bubbles: true }));
  });

  window.SB2OptionsController = Object.freeze({ setAnimation, setWindowLevel, syncToggleButtons });
  syncToggleButtons();
})();
