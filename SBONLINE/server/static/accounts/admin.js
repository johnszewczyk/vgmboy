(() => {
  const root = document.documentElement;
  const themeColor = document.querySelector('meta[name="theme-color"]');
  const deviceTheme = window.matchMedia?.("(prefers-color-scheme: dark)");

  function setTheme() {
    const preference = document.body.classList.contains("sbonline-site") ? "dark" : root.dataset.themeMode || "system";
    const theme = preference === "dark" || preference === "light"
      ? preference
      : (deviceTheme?.matches ? "dark" : "light");
    root.dataset.theme = theme;
    if (themeColor) themeColor.content = theme === "dark" ? "#090b0f" : "#f4f6f9";
  }

  setTheme();
  deviceTheme?.addEventListener?.("change", () => {
    if (!root.dataset.themeMode || root.dataset.themeMode === "system") setTheme();
  });
  document.addEventListener("site:navigated", setTheme);

  const status = document.querySelector(".copy-status");

  function selectCopyValue(element) {
    try {
      element.focus({ preventScroll: true });
    } catch {
      element.focus();
    }
    element.select?.();
  }

  async function copyValue(target) {
    const element = document.getElementById(target);
    if (!element) return;
    const value = "value" in element ? element.value : element.textContent;

    try {
      // Invoke the Clipboard API directly from the click handler so Safari
      // still has the user's transient activation. This also avoids selecting
      // the field on the normal successful path.
      const write = navigator.clipboard?.writeText?.(value);
      if (write) {
        await write;
        if (status) status.textContent = "Copied to clipboard.";
        return;
      }
    } catch {
      // Fall through to the synchronous compatibility path.
    }

    try {
      selectCopyValue(element);
      if (document.execCommand("copy")) {
        if (status) status.textContent = "Copied to clipboard.";
        return;
      }
    } catch {
      // Show a selected value if the browser denies both copy mechanisms.
    }

    selectCopyValue(element);
    if (status) status.textContent = "Text selected. Press ⌘C or Ctrl+C to copy.";
  }

  document.querySelectorAll("[data-copy-target]").forEach((button) => {
    button.addEventListener("click", () => copyValue(button.dataset.copyTarget));
  });

  const hasPasskeySupport = Boolean(
    window.isSecureContext
    && window.PublicKeyCredential
    && navigator.credentials?.create
    && navigator.credentials?.get
  );

  function decodeBase64Url(value) {
    const padded = value.replace(/-/g, "+").replace(/_/g, "/") + "=".repeat((4 - value.length % 4) % 4);
    const binary = atob(padded);
    return Uint8Array.from(binary, (character) => character.charCodeAt(0));
  }

  function encodeBase64Url(value) {
    const bytes = new Uint8Array(value);
    let binary = "";
    bytes.forEach((byte) => { binary += String.fromCharCode(byte); });
    return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
  }

  async function passkeyJson(url, csrfToken, body) {
    const response = await fetch(url, {
      method: "POST",
      credentials: "same-origin",
      headers: { "Content-Type": "application/json", "X-CSRFToken": csrfToken },
      body: body ? JSON.stringify(body) : "{}",
    });
    const result = await response.json();
    if (!response.ok) throw new Error(result.error || "The passkey request failed.");
    return result;
  }

  function csrfFor(element) {
    return element.closest("form")?.querySelector('input[name="csrfmiddlewaretoken"]')?.value
      || document.querySelector('input[name="csrfmiddlewaretoken"]')?.value
      || "";
  }

  document.querySelectorAll("[data-passkey-register]").forEach((button) => {
    const controls = button.closest("[data-passkey-controls]");
    const status = controls?.querySelector("[data-passkey-status]");
    if (!hasPasskeySupport) {
      button.disabled = true;
      if (status) status.textContent = "Passkey setup needs a compatible browser and device. Open this invitation on one to continue.";
      return;
    }
    button.addEventListener("click", async () => {
      button.disabled = true;
      if (status) status.textContent = "Waiting for your device…";
      try {
        const urls = controls.dataset;
        const options = await passkeyJson(urls.passkeyOptions, csrfFor(button));
        options.challenge = decodeBase64Url(options.challenge);
        options.user.id = decodeBase64Url(options.user.id);
        options.excludeCredentials = (options.excludeCredentials || []).map((item) => ({
          ...item,
          id: decodeBase64Url(item.id),
        }));
        const credential = await navigator.credentials.create({ publicKey: options });
        if (!credential) throw new Error("The device did not create a passkey.");
        const response = credential.response;
        const name = controls.querySelector("[data-passkey-name]")?.value?.trim() || "";
        const result = await passkeyJson(urls.passkeyVerify, csrfFor(button), {
          id: credential.id,
          rawId: encodeBase64Url(credential.rawId),
          type: credential.type,
          authenticatorAttachment: credential.authenticatorAttachment,
          response: {
            attestationObject: encodeBase64Url(response.attestationObject),
            clientDataJSON: encodeBase64Url(response.clientDataJSON),
            transports: response.getTransports ? response.getTransports() : [],
          },
          clientExtensionResults: credential.getClientExtensionResults(),
          name,
        });
        if (result.redirect_url) {
          window.location.assign(result.redirect_url);
          return;
        }
        if (result.username_required) {
          const setupForm = button.closest("form");
          const usernameForm = controls.querySelector("[data-enrollment-username]");
          if (setupForm) setupForm.hidden = true;
          if (usernameForm) {
            usernameForm.hidden = false;
            usernameForm.querySelector('input[name="username"]')?.focus();
          }
          if (status) status.textContent = "Passkey ready. Choose a username to finish setup.";
          return;
        }
        button.textContent = "Passkey added";
        if (status) status.textContent = "Passkey ready. Use it the next time you sign in.";
      } catch (error) {
        button.disabled = false;
        if (status) status.textContent = error.name === "NotAllowedError"
          ? "Passkey setup was canceled. You can try again."
          : error.message || "Passkey setup could not be completed.";
      }
    });
  });

  document.querySelectorAll("[data-enrollment-username]").forEach((form) => {
    form.addEventListener("submit", async (event) => {
      event.preventDefault();
      const controls = form.closest("[data-passkey-controls]");
      const status = controls?.querySelector("[data-passkey-status]");
      const button = form.querySelector('button[type="submit"]');
      const username = form.querySelector('input[name="username"]');
      if (!controls || !button || !username) return;
      button.disabled = true;
      if (status) status.textContent = "Saving your username…";
      try {
        const result = await passkeyJson(controls.dataset.passkeyUsernameUrl, csrfFor(form), {
          username: username.value,
        });
        window.location.assign(result.redirect_url);
      } catch (error) {
        button.disabled = false;
        if (status) status.textContent = error.message || "The username could not be saved. Try another.";
      }
    });
  });

  document.querySelectorAll("[data-passkey-login]").forEach((button) => {
    if (!hasPasskeySupport) {
      button.disabled = true;
      const status = document.querySelector("[data-passkey-login-status]");
      if (status) status.textContent = "Passkey sign-in needs a compatible browser and device.";
      return;
    }
    button.addEventListener("click", async () => {
      const status = document.querySelector("[data-passkey-login-status]");
      button.disabled = true;
      if (status) status.textContent = "Waiting for your passkey…";
      try {
        const options = await passkeyJson(button.dataset.passkeyOptions, csrfFor(button));
        options.challenge = decodeBase64Url(options.challenge);
        options.allowCredentials = (options.allowCredentials || []).map((item) => ({
          ...item,
          id: decodeBase64Url(item.id),
        }));
        const credential = await navigator.credentials.get({ publicKey: options });
        if (!credential) throw new Error("The device did not return a passkey.");
        const response = credential.response;
        const next = button.closest("form")?.querySelector('input[name="next"]')?.value || "";
        const result = await passkeyJson(button.dataset.passkeyVerify, csrfFor(button), {
          id: credential.id,
          rawId: encodeBase64Url(credential.rawId),
          type: credential.type,
          authenticatorAttachment: credential.authenticatorAttachment,
          response: {
            authenticatorData: encodeBase64Url(response.authenticatorData),
            clientDataJSON: encodeBase64Url(response.clientDataJSON),
            signature: encodeBase64Url(response.signature),
            userHandle: response.userHandle ? encodeBase64Url(response.userHandle) : null,
          },
          clientExtensionResults: credential.getClientExtensionResults(),
          next,
        });
        window.location.assign(result.redirect_url);
      } catch (error) {
        button.disabled = false;
        if (status) status.textContent = error.name === "NotAllowedError"
          ? "Passkey sign-in was canceled. You can try again."
          : error.message || "Passkey sign-in could not be completed.";
      }
    });
  });

})();
