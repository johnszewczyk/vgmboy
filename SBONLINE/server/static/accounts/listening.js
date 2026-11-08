(() => {
  const page = document.querySelector(".listening-page[data-now-playing-url]");
  const list = document.querySelector("#listening-now-playing-list");
  const liveCount = document.querySelector("#now-playing-live-count");
  if (!page || !list || !liveCount) return;

  const tabs=[...page.querySelectorAll('[data-listening-tab]')];
  function select(name,write=false) {
    if(!['now-playing','played'].includes(name))name='now-playing';
    for(const tab of tabs){const active=tab.dataset.listeningTab===name;tab.setAttribute('aria-selected',String(active));tab.tabIndex=active?0:-1;document.getElementById(tab.dataset.listeningTab).hidden=!active;}
    if(write){const url=new URL(location.href);url.hash=name;history.replaceState({},'',url);}
  }
  for(const tab of tabs){
    tab.addEventListener('click',()=>select(tab.dataset.listeningTab,true));
    tab.addEventListener('keydown',event=>{if(!['ArrowLeft','ArrowRight','Home','End'].includes(event.key))return;event.preventDefault();const next=event.key==='Home'?tabs[0]:event.key==='End'?tabs.at(-1):tabs[(tabs.indexOf(tab)+1)%tabs.length];next.focus();select(next.dataset.listeningTab,true);});
  }
  select(location.hash==='#played'||new URLSearchParams(location.search).has('day')?'played':'now-playing');
  let lastState = "";

  function render(members, onlineCount = 0) {
    const activeMembers = members.filter((member) => member.nowPlaying);
    const state = JSON.stringify(activeMembers.map((member) => [
      member.userId,
      member.nowPlaying.trackId,
      member.nowPlaying.startedAt,
      member.cardHtml,
    ]));
    onlineCount = Math.max(0, Number(onlineCount) || 0);
    liveCount.textContent = `${activeMembers.length} playing · ${onlineCount} online`;
    const navCount = page.querySelector('.listening-page-nav [data-listening-tab="now-playing"] span');
    if (navCount) navCount.textContent = String(activeMembers.length);
    if (state === lastState) return;
    lastState = state;
    list.replaceChildren();
    if (!activeMembers.length) {
      const empty = document.createElement("li");
      empty.className = "listening-empty";
      const message = document.createElement("p");
      message.className = "empty-state";
      message.textContent = "Nothing is playing right now.";
      empty.append(message);
      list.append(empty);
      return;
    }
    for (const member of activeMembers) {
      if (typeof member.cardHtml !== "string") continue;
      // Same-origin, authenticated, escaped HTML from the canonical card partial.
      const card = document.createElement("template");
      card.innerHTML = member.cardHtml;
      const row = document.createElement("li");
      row.dataset.userId = String(member.userId);
      row.append(card.content);
      list.append(row);
    }
  }

  let pending = false;
  const abort = new AbortController();
  async function refresh() {
    if (pending || abort.signal.aborted) return;
    pending = true;
    try {
      const response = await fetch(page.dataset.nowPlayingUrl, {
        credentials: "same-origin", signal: abort.signal, cache: "no-store",
        headers: { Accept: "application/json" },
      });
      if (!response.ok) return;
      const payload = await response.json();
      if (Array.isArray(payload.members)) render(payload.members, payload.onlineCount);
    } catch {
      /* Keep the server-rendered cards while the network is temporarily unavailable. */
    } finally { pending = false; }
  }

  refresh();
  const timer = window.setInterval(refresh, 15_000);
  document.addEventListener("siteplayer:presence", refresh);
  document.addEventListener("site:pageleave", () => {
    abort.abort(); window.clearInterval(timer);
    document.removeEventListener("siteplayer:presence", refresh);
  }, {once:true});
})();
