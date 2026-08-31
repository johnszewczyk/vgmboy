(() => {
  async function resolveIntent(node, gesture, wasSelected = false) {
    const kind = node?.kind === "folder" ? "folder" : "leaf";
    return window.spcBoyWK.resolveSidebarRowIntent(kind, gesture, Boolean(wasSelected));
  }

  window.SPCBoySidebarController = Object.freeze({ resolveIntent });
})();
