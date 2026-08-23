# Playback and transport

SPCBoy WK obtains transport state, elapsed position, decoder statistics, and reached-end state
from the in-process VGMBoy bridge. While a track is playing, the frontend polls that state so the
elapsed/track/playlist readout stays current and the next playlist item can begin when playback
ends. Playback timing remains owned by VGMBoy; SPCBoy owns queue order and presentation.

The root window's sidebar divider is draggable. Its persisted width is also available from the
appearance settings controls, and the divider supports keyboard adjustment when focused.
