(() => {
  document.querySelectorAll("[data-profile-tabs]").forEach((tablist) => {
    const tabs = [...tablist.querySelectorAll("[data-profile-tab][aria-controls]")];
    if (!tabs.length) return;

    function activate(tab, updateAddress = false) {
      const panelId = tab.getAttribute("aria-controls");
      for (const candidate of tabs) {
        const selected = candidate === tab;
        candidate.setAttribute("aria-selected", String(selected));
        candidate.tabIndex = selected ? 0 : -1;
        document.getElementById(candidate.getAttribute("aria-controls"))?.toggleAttribute("hidden", !selected);
      }
      if (updateAddress) {
        const address = new URL(window.location.href);
        address.searchParams.set("tab", tab.dataset.profileTab);
        address.hash = "";
        window.history.replaceState(null, "", address);
      }
      return panelId;
    }

    const startingTab = tabs.find((tab) => tab.dataset.profileTab === new URL(window.location.href).searchParams.get("tab"))
      || tabs.find((tab) => tab.dataset.profileTab === tablist.dataset.activeTab)
      || tabs[0];
    activate(startingTab);
    tablist.addEventListener("click", (event) => {
      const tab = event.target.closest("[data-profile-tab]");
      if (!tabs.includes(tab)) return;
      event.preventDefault();
      activate(tab, true);
    });
    tablist.addEventListener("keydown", (event) => {
      const currentIndex = tabs.indexOf(event.target.closest("[data-profile-tab]"));
      if (currentIndex < 0) return;
      let nextIndex = currentIndex;
      if (event.key === "ArrowRight") nextIndex = (currentIndex + 1) % tabs.length;
      else if (event.key === "ArrowLeft") nextIndex = (currentIndex - 1 + tabs.length) % tabs.length;
      else if (event.key === "Home") nextIndex = 0;
      else if (event.key === "End") nextIndex = tabs.length - 1;
      else return;
      event.preventDefault();
      tabs[nextIndex].focus();
      activate(tabs[nextIndex], true);
    });
    window.addEventListener("popstate", () => {
      const tab = tabs.find((candidate) => candidate.dataset.profileTab === new URL(window.location.href).searchParams.get("tab"));
      if (tab) activate(tab);
    });
  });
})();
