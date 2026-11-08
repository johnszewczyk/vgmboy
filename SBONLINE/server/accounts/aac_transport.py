"""Helpers for the AAC-only browser stream."""


class AACADTSPrimingFrameStripper:
    """Discard FFmpeg AAC's first complete ADTS frame before streaming."""

    def __init__(self):
        self._pending = bytearray()
        self._priming_frame_removed = False

    def push(self, chunk):
        if self._priming_frame_removed:
            return chunk

        self._pending.extend(chunk)
        if len(self._pending) < 7:
            return b""

        first, second = self._pending[0], self._pending[1]
        if first != 0xFF or second & 0xF6 != 0xF0:
            raise ValueError("AAC encoder did not emit an ADTS frame.")

        header_length = 7 if second & 1 else 9
        frame_length = (
            ((self._pending[3] & 0x03) << 11)
            | (self._pending[4] << 3)
            | (self._pending[5] >> 5)
        )
        if frame_length < header_length:
            raise ValueError("AAC encoder emitted an invalid ADTS frame length.")
        if len(self._pending) < frame_length:
            return b""

        del self._pending[:frame_length]
        self._priming_frame_removed = True
        remaining = bytes(self._pending)
        self._pending.clear()
        return remaining
