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

  const form = document.querySelector("#profile-form");
  const sourceInput = document.querySelector("#avatar-source");
  const outputInput = document.querySelector("#id_avatar");
  const cropper = document.querySelector("#avatar-cropper");
  const canvas = document.querySelector("#avatar-crop-canvas");
  const zoomInput = document.querySelector("#avatar-zoom");
  const currentAvatar = document.querySelector("#profile-avatar-current");
  if (!form || !sourceInput || !outputInput || !cropper || !canvas || !zoomInput) return;

  const context = canvas.getContext("2d");
  const maximumBytes = Number(form.dataset.maxImageBytes) || 10 * 1024 * 1024;
  let image = null;
  let centerX = 0;
  let centerY = 0;
  let pointer = null;

  function dimensions() {
    return {
      width: image.naturalWidth || image.width,
      height: image.naturalHeight || image.height,
    };
  }

  function cropSize() {
    const { width, height } = dimensions();
    return Math.min(width, height) / (Number(zoomInput.value) / 100);
  }

  function showMessage(text, isError = false) {
    document.querySelectorAll(".profile-fields > .field-error[role='alert'], .profile-fields > .crop-note").forEach((node) => node.remove());
    if (!text) return;
    const note = document.createElement("span");
    note.className = isError ? "field-error" : "security-note crop-note";
    if (isError) note.setAttribute("role", "alert");
    note.textContent = text;
    sourceInput.insertAdjacentElement("afterend", note);
  }

  function drawCrop() {
    if (!image || !context) return;
    const { width, height } = dimensions();
    const size = cropSize();
    centerX = Math.max(size / 2, Math.min(width - size / 2, centerX));
    centerY = Math.max(size / 2, Math.min(height - size / 2, centerY));
    context.clearRect(0, 0, canvas.width, canvas.height);
    context.drawImage(image, centerX - size / 2, centerY - size / 2, size, size, 0, 0, canvas.width, canvas.height);
  }

  function loadImage(file) {
    if (typeof createImageBitmap === "function") return createImageBitmap(file);
    return new Promise((resolve, reject) => {
      const objectURL = URL.createObjectURL(file);
      const fallbackImage = new Image();
      fallbackImage.onload = () => {
        URL.revokeObjectURL(objectURL);
        resolve(fallbackImage);
      };
      fallbackImage.onerror = () => {
        URL.revokeObjectURL(objectURL);
        reject(new Error("Image preview is unavailable."));
      };
      fallbackImage.src = objectURL;
    });
  }

  function submitOriginal(submitButton) {
    image = null;
    cropper.hidden = true;
    if (currentAvatar) currentAvatar.hidden = false;
    outputInput.value = "";
    outputInput.removeAttribute("name");
    sourceInput.name = "avatar";
    if (submitButton) submitButton.disabled = false;
    form.requestSubmit(submitButton || undefined);
  }

  sourceInput.addEventListener("change", async () => {
    outputInput.value = "";
    outputInput.removeAttribute("name");
    sourceInput.name = "avatar";
    cropper.hidden = true;
    image = null;
    if (currentAvatar) currentAvatar.hidden = false;
    showMessage("");
    const file = sourceInput.files?.[0];
    if (!file) return;
    if (file.size > maximumBytes) {
      sourceInput.value = "";
      showMessage("Choose an image no larger than 10 MB.", true);
      return;
    }
    try {
      image = await loadImage(file);
    } catch {
      showMessage("This browser could not preview the crop. The original image will be center-cropped when saved.");
      return;
    }
    if (!context) {
      image = null;
      showMessage("Square crop preview is unavailable. The original image will be center-cropped when saved.");
      return;
    }
    const { width, height } = dimensions();
    centerX = width / 2;
    centerY = height / 2;
    zoomInput.value = "100";
    cropper.hidden = false;
    if (currentAvatar) currentAvatar.hidden = true;
    drawCrop();
  });

  zoomInput.addEventListener("input", drawCrop);
  canvas.addEventListener("pointerdown", (event) => {
    if (!image) return;
    pointer = { id: event.pointerId, x: event.clientX, y: event.clientY };
    canvas.setPointerCapture(event.pointerId);
  });
  canvas.addEventListener("pointermove", (event) => {
    if (!image || !pointer || pointer.id !== event.pointerId) return;
    const bounds = canvas.getBoundingClientRect();
    const sourcePixelsPerCSSPixel = cropSize() / bounds.width;
    centerX -= (event.clientX - pointer.x) * sourcePixelsPerCSSPixel;
    centerY -= (event.clientY - pointer.y) * sourcePixelsPerCSSPixel;
    pointer.x = event.clientX;
    pointer.y = event.clientY;
    drawCrop();
  });
  for (const eventName of ["pointerup", "pointercancel", "lostpointercapture"]) {
    canvas.addEventListener(eventName, () => { pointer = null; });
  }

  form.addEventListener("submit", async (event) => {
    if (!image || !sourceInput.files?.length || outputInput.files?.length) return;
    event.preventDefault();
    const submit = form.querySelector("button[type='submit']");
    if (submit) submit.disabled = true;
    try {
      const blob = await new Promise((resolve, reject) => {
        canvas.toBlob((result) => result ? resolve(result) : reject(new Error("Crop could not be prepared.")), "image/webp", 0.9);
      });
      if (blob.size > maximumBytes) throw new Error("The cropped image is too large.");
      const transfer = new DataTransfer();
      const extension = blob.type === "image/webp" ? "webp" : "png";
      transfer.items.add(new File([blob], `profile-crop.${extension}`, { type: blob.type || "image/png" }));
      outputInput.files = transfer.files;
      outputInput.name = "avatar";
      sourceInput.removeAttribute("name");
      if (submit) submit.disabled = false;
      form.requestSubmit(submit || undefined);
    } catch {
      showMessage("The crop could not be applied. Saving the original image with a centered square crop instead.");
      submitOriginal(submit);
    }
  });
})();
