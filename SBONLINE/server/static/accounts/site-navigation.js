(() => {
  const shell = document.querySelector("main.page-shell");
  if (!shell || !document.body.classList.contains("has-site-player")) return;
  // Same-site navigation replaces page content while the shared player keeps running.
  const isMobileOnline = () => window.matchMedia("(max-width: 780px)").matches;

  let spcboyPage = null;
  let navigationGeneration = 0;
  const loadedStyles = new Set([...document.querySelectorAll('link[rel="stylesheet"]')].map((link) => link.href));
  const pageScriptPattern = /\/static\/accounts\/[^/]+\.js(?:\?|$)/;
  const pendingPageScripts = new Map();

  function beginNavigation() {
    navigationGeneration += 1;
    for (const [script, finish] of pendingPageScripts) {
      script.remove();
      finish();
    }
    return navigationGeneration;
  }

  function reportNavigationStatus(message) {
    window.SitePlayer?.setStatus(message, { timeout: 6000 });
  }

  function navigationHeaders() {
    return {
      Accept: "text/html",
      "X-Site-Navigation": "1",
      "X-Playback-Page-Token": document.querySelector("#site-player")?.dataset.pageLoadToken || "",
    };
  }

  function navKey(pathname) {
    if (pathname.includes("/spcboy")) return "spcboy";
    if (pathname.includes("/history")) return "history";
    if (pathname.includes("/community")) return "community";
    if (pathname.includes("/profile") || pathname.includes("/members/")) return "profile";
    if (pathname.includes("/accounts")) return "admin";
    if (pathname.includes("/usage")) return "usage";
    if (pathname.includes("/site-log")) return "log";
    return null;
  }

  function updateNavigation(pathname) {
    const key = navKey(pathname);
    document.querySelectorAll(".topbar a[data-nav-key]").forEach((link) => {
      if (link.dataset.navKey === key) link.setAttribute("aria-current", "page");
      else link.removeAttribute("aria-current");
    });
    const playerHome = document.querySelector(".mobile-player-link");
    if (playerHome) {
      if (key === "spcboy") playerHome.setAttribute("aria-current", "page");
      else playerHome.removeAttribute("aria-current");
    }
    document.querySelectorAll(".drawer-navigation nav a").forEach((link) => {
      const url = new URL(link.href, window.location.href);
      const selected = url.pathname === pathname && url.search === window.location.search;
      if (selected) link.setAttribute("aria-current", "page");
      else link.removeAttribute("aria-current");
    });
    document.dispatchEvent(new CustomEvent("site:navigated", { detail: { pathname } }));
  }

  async function loadStyles(sourceDocument) {
    const additions = [...sourceDocument.querySelectorAll('link[rel="stylesheet"]')]
      .map((link) => new URL(link.getAttribute("href"), window.location.href))
      .filter((url) => url.origin === window.location.origin && url.pathname.includes("/static/accounts/") && !loadedStyles.has(url.href));
    for (const url of additions) {
      const link = document.createElement("link");
      link.rel = "stylesheet";
      link.href = url.href;
      const skin = document.querySelector('link[href*="/accounts/sbonline.css"]');
      document.head.insertBefore(link, skin);
      loadedStyles.add(url.href);
      await new Promise((resolve) => {
        link.addEventListener("load", resolve, { once: true });
        link.addEventListener("error", resolve, { once: true });
        window.setTimeout(resolve, 1200);
      });
    }
  }

  async function loadPageScripts(sourceDocument, isCurrentNavigation) {
    const urls = [...sourceDocument.querySelectorAll("script[src]:not([data-site-global])")]
      .map((script) => new URL(script.getAttribute("src"), window.location.href))
      .filter((url) => url.origin === window.location.origin && pageScriptPattern.test(`${url.pathname}${url.search}`));
    for (const url of urls) {
      if (!isCurrentNavigation()) return;
      await new Promise((resolve) => {
        const script = document.createElement("script");
        let finished = false;
        const finish = () => {
          if (finished) return;
          finished = true;
          pendingPageScripts.delete(script);
          resolve();
        };
        script.src = url.href;
        script.async = false;
        script.addEventListener("load", finish, { once: true });
        script.addEventListener("error", finish, { once: true });
        pendingPageScripts.set(script, finish);
        document.body.append(script);
      });
      if (!isCurrentNavigation()) return;
    }
  }

  async function displayPage(nextDocument, url, options = {}) {
    const isCurrentNavigation = () => options.navigationId === undefined || options.navigationId === navigationGeneration;
    if (!isCurrentNavigation()) return false;
    const nextShell = nextDocument.querySelector("main.page-shell");
    if (!nextShell) {
      reportNavigationStatus("Page content could not be loaded · playback continues");
      return false;
    }
    if (!nextDocument.querySelector("#site-player")) {
      reportNavigationStatus("Sign-in required to load this page · playback continues");
      return false;
    }
    document.dispatchEvent(new Event("site:pageleave"));
    extractSPCBoy();
    await loadStyles(nextDocument);
    if (!isCurrentNavigation()) return false;
    document.documentElement.dataset.themeMode = nextDocument.documentElement.dataset.themeMode || "system";
    shell.innerHTML = nextShell.innerHTML;
    document.body.className = [...nextDocument.body.classList, "has-site-player"].filter((name, index, names) => names.indexOf(name) === index).join(" ");
    document.title = nextDocument.title;
    if (options.replace) history.replaceState({}, "", `${url.pathname}${url.search}${url.hash}`);
    else if (!options.popstate) history.pushState({}, "", `${url.pathname}${url.search}${url.hash}`);
    updateNavigation(url.pathname);
    await loadPageScripts(nextDocument, isCurrentNavigation);
    if (!isCurrentNavigation()) return false;
    if (url.hash) document.getElementById(decodeURIComponent(url.hash.slice(1)))?.scrollIntoView();
    else window.scrollTo(0, 0);
    return true;
  }

  function extractSPCBoy() {
    const page = shell.querySelector(".spcboy-page");
    if (!page) return;
    spcboyPage = document.createDocumentFragment();
    spcboyPage.append(page);
  }

  async function navigate(url, options = {}) {
    if (url.origin !== window.location.origin) return false;
    const navigationId = beginNavigation();
    const navigationOptions = { ...options, navigationId };
    if (url.pathname.endsWith("/spcboy/") && spcboyPage) {
      document.dispatchEvent(new Event("site:pageleave"));
      shell.replaceChildren(spcboyPage);
      document.body.className = "sbonline-site spcboy-body has-site-player";
      document.title = "SPCBOY | Pre-Calc";
      if (options.replace) history.replaceState({}, "", `${url.pathname}${url.search}${url.hash}`);
      else if (!options.popstate) history.pushState({}, "", `${url.pathname}${url.search}${url.hash}`);
      updateNavigation(url.pathname);
      if (url.hash) document.getElementById(decodeURIComponent(url.hash.slice(1)))?.scrollIntoView();
      else window.scrollTo(0, 0);
      return true;
    }

    let response;
    try {
      response = await fetch(url.href, { credentials: "same-origin", headers: navigationHeaders() });
      if (navigationId !== navigationGeneration) return false;
      if (!response.ok || !response.headers.get("content-type")?.includes("text/html")) {
        reportNavigationStatus("Page unavailable · playback continues; select again to retry");
        return false;
      }
    } catch {
      if (navigationId !== navigationGeneration) return false;
      reportNavigationStatus("Page unavailable · playback continues; select again to retry");
      return false;
    }
    const html = await response.text();
    if (navigationId !== navigationGeneration) return false;
    const nextDocument = new DOMParser().parseFromString(html, "text/html");
    return displayPage(nextDocument, new URL(response.url || url.href), navigationOptions);
  }

  async function openSPCBoyView(view) {
    if (!["all", "favorites", "recent", "gallery"].includes(view)) return;
    if (!window.location.pathname.endsWith("/spcboy/")) {
      if (!await navigate(new URL("/spcboy/", window.location.href))) return false;
    }
    for (let frame = 0; frame < 4; frame += 1) {
      const button = document.querySelector(`#spcboy-view-row [data-view="${view}"]`);
      if (button && !button.disabled) {
        button.click();
        document.dispatchEvent(new Event("site:close-player-overlays"));
        return true;
      }
      await new Promise((resolve) => requestAnimationFrame(resolve));
    }
    reportNavigationStatus("Player view could not be opened · select again to retry");
    return false;
  }

  document.addEventListener("site:show-spcboy-view", (event) => {
    void openSPCBoyView(event.detail?.view);
  });

  document.addEventListener("click", (event) => {
    if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    if (!(event.target instanceof Element)) return;
    const viewShortcut = event.target.closest("[data-spcboy-view-shortcut]");
    if (viewShortcut) {
      const view = viewShortcut.dataset.spcboyViewShortcut;
      if (view !== "favorites" && view !== "recent") return;
      event.preventDefault();
      document.dispatchEvent(new CustomEvent("site:show-spcboy-view", { detail: { view } }));
      return;
    }
    const playerHome = event.target.closest("[data-site-player-home]");
    const link = event.target.closest("a[href]");
    if (
      !link || link.target || link.hasAttribute("download") || link.hasAttribute("data-full-navigation")
      || link.getAttribute("href")?.startsWith("#")
    ) return;
    const url = new URL(link.href, window.location.href);
    if (url.origin !== window.location.origin || url.pathname.startsWith("/audio/")) return;
    if (link.id === "spcboy-current-album" && link.dataset.albumId) {
      event.preventDefault();
      document.dispatchEvent(new CustomEvent("site:open-spcboy-album", { detail: { albumId: link.dataset.albumId } }));
      navigate(url);
      return;
    }
    if (playerHome) {
      event.preventDefault();
      document.dispatchEvent(new Event("site:close-player-overlays"));
      if (url.pathname !== window.location.pathname || url.search !== window.location.search) navigate(url);
      else {
        window.scrollTo({ top: 0, behavior: "smooth" });
      }
      return;
    }
    if (url.pathname === window.location.pathname && url.search === window.location.search) {
      event.preventDefault();
      if (url.hash && url.hash !== window.location.hash) {
        history.pushState({}, "", `${url.pathname}${url.search}${url.hash}`);
        document.getElementById(decodeURIComponent(url.hash.slice(1)))?.scrollIntoView();
      }
      return;
    }
    event.preventDefault();
    navigate(url);
  });

  document.addEventListener("submit", async (event) => {
    if (event.defaultPrevented || !(event.target instanceof HTMLFormElement)) return;
    const form = event.target;
    if (form.method.toLowerCase() !== "post" || form.target || form.action.includes("/logout")) return;
    const url = new URL(form.action || window.location.href, window.location.href);
    if (url.origin !== window.location.origin) return;
    event.preventDefault();
    const navigationId = beginNavigation();
    const submitter = event.submitter;
    if (submitter) submitter.disabled = true;
    try {
      const formData = new FormData(form);
      if (submitter?.name) formData.append(submitter.name, submitter.value);
      const response = await fetch(url.href, {
        method: "POST",
        credentials: "same-origin",
        headers: navigationHeaders(),
        body: formData,
      });
      if (navigationId !== navigationGeneration) {
        if (submitter) submitter.disabled = false;
        return;
      }
      if (!response.ok || !response.headers.get("content-type")?.includes("text/html")) throw new Error("Form submission needs a full navigation.");
      const html = await response.text();
      if (navigationId !== navigationGeneration) {
        if (submitter) submitter.disabled = false;
        return;
      }
      const nextDocument = new DOMParser().parseFromString(html, "text/html");
      const displayed = await displayPage(nextDocument, new URL(response.url || url.href), { replace: true, navigationId });
      if (!displayed && submitter) submitter.disabled = false;
    } catch {
      if (submitter) submitter.disabled = false;
      if (navigationId === navigationGeneration) reportNavigationStatus("Action could not complete · playback continues");
    }
  });

  document.addEventListener("change", (event) => {
    const select = event.target.closest?.(".month-picker select[name='month']");
    if (!select || !select.form) return;
    const url = new URL(select.form.action || window.location.href, window.location.href);
    url.search = new URLSearchParams(new FormData(select.form)).toString();
    if (url.pathname === window.location.pathname && url.search === window.location.search) return;
    navigate(url);
  });

  window.addEventListener("popstate", () => {
    navigate(new URL(window.location.href), { popstate: true });
  });
  window.SiteNavigation = Object.freeze({
    refresh: () => navigate(new URL(window.location.href), { replace: true }),
  });
  document.querySelector('#mobile-header-search')?.addEventListener('submit', async event => {
    if (!isMobileOnline()) return;
    event.preventDefault(); event.stopImmediatePropagation();
    const query=document.querySelector('#mobile-header-search-input').value;
    const onPlayer=Boolean(shell.querySelector('.spcboy-page'));
    if (!onPlayer && !await navigate(new URL('/spcboy/',window.location.origin))) return;
    if (!shell.querySelector('.spcboy-page')) return;
    document.dispatchEvent(new CustomEvent('site:player-search',{detail:{query,all:!onPlayer}}));
  });
  updateNavigation(window.location.pathname);
})();
