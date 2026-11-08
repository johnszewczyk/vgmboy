/* One authenticated AAC request, appended incrementally to the existing audio element. */
(() => {
  const mime = 'audio/aac';
  const Source = [window.MediaSource, window.ManagedMediaSource].find(type => type?.isTypeSupported(mime));
  function attach(audio, failed, timing) {
    let active = null;
    function cancel() {
      if (!active) return;
      active.abort.abort();
      clearTimeout(active.timer);
      URL.revokeObjectURL(active.objectURL);
      active = null;
    }
    function load(url) {
      cancel();
      if (!Source) {
        failed(new Error('This browser does not support AAC streaming. Use an up-to-date browser.'));
        return;
      }
      const media = new Source(), abort = new AbortController();
      const objectURL = URL.createObjectURL(media);
      const run = active = { abort, objectURL, timer: null };
      const report = error => {
        if (active !== run || abort.signal.aborted) return;
        abort.abort(); clearTimeout(run.timer);
        failed(error);
      };
      function operation(buffer, action) {
        return new Promise((resolve, reject) => {
          const cleanup = () => {
            buffer.removeEventListener('updateend', done);
            buffer.removeEventListener('error', error);
            abort.signal.removeEventListener('abort', stopped);
          };
          const done = () => { cleanup(); resolve(); };
          const error = () => { cleanup(); reject(new Error('AAC buffer rejected media')); };
          const stopped = () => { cleanup(); reject(new DOMException('Cancelled','AbortError')); };
          buffer.addEventListener('updateend', done, {once:true});
          buffer.addEventListener('error', error, {once:true});
          abort.signal.addEventListener('abort', stopped, {once:true});
          try { action(); } catch (e) { cleanup(); reject(e); }
        });
      }
      async function append(buffer, bytes) {
        // Free played audio before appending, including on memory-constrained phones.
        if (audio.currentTime > 40 && buffer.buffered.length && buffer.buffered.start(0) < audio.currentTime-30) {
          await operation(buffer, () => buffer.remove(0,audio.currentTime-20));
        }
        try {
          await operation(buffer, () => buffer.appendBuffer(bytes));
        } catch (error) {
          if (error.name !== 'QuotaExceededError' || abort.signal.aborted) throw error;
          const cutoff = audio.currentTime - 5;
          if (cutoff <= 0 || !buffer.buffered.length || buffer.buffered.start(0) >= cutoff) throw error;
          await operation(buffer, () => buffer.remove(0,cutoff));
          // The rejected append consumed no bytes: retry exactly the same chunk once.
          await operation(buffer, () => buffer.appendBuffer(bytes));
        }
      }
      async function networkRead(action) {
        let timer;
        try {
          return await Promise.race([action(), new Promise((_, reject) => {
            timer = setTimeout(() => reject(new Error('AAC network timed out')),45000);
          })]);
        } finally { clearTimeout(timer); }
      }
      media.addEventListener('sourceopen', async () => {
        if (abort.signal.aborted) return;
        clearTimeout(run.timer);
        try {
          const buffer = media.addSourceBuffer(mime);
          const response = await networkRead(() => fetch(url, {credentials:'same-origin', cache:'no-store', signal:abort.signal}));
          if (!response.ok || !response.headers.get('content-type')?.startsWith('audio/aac')) {
            const error = new Error(`AAC response ${response.status}`);
            error.status = response.redirected ? 401 : response.status;
            throw error;
          }
          timing?.(Number(response.headers.get("X-Audio-Duration")));
          const reader = response.body.getReader();
          while (!abort.signal.aborted) {
            const {value, done} = await networkRead(() => reader.read());
            if (done) { if (media.readyState === 'open') media.endOfStream(); break; }
            // Network chunks can coalesce. Bound each append before checking
            // backpressure again so one large read cannot fill the media buffer.
            for (let offset=0; offset<value.byteLength && !abort.signal.aborted; offset+=65536) {
              while (!abort.signal.aborted && buffer.buffered.length && buffer.buffered.end(buffer.buffered.length-1) - audio.currentTime > 30) {
                await new Promise(resolve => setTimeout(resolve,250));
              }
              if (abort.signal.aborted) break;
              await append(buffer, value.subarray(offset,offset+65536));
            }
          }
        } catch (error) { report(error); }
      }, {once:true});
      media.addEventListener('sourceclose', () => report(new Error('AAC source closed')), {once:true});
      audio.disableRemotePlayback = true;
      audio.dataset.streamCodec = 'aac';
      audio.src = objectURL;
      run.timer = setTimeout(() => report(new Error('AAC source did not open')),8000);
    }
    return { load, cancel, supported:Boolean(Source), get interrupted() { return Boolean(active?.abort.signal.aborted); } };
  }
  window.SBAACStream = Object.freeze({attach});
})();
