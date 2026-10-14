// Spatial LCD model. Component reference, not a measured DMG panel:
// Displaytech 128128A v1.1, p2: 0.39 mm dots / 0.43 mm pitch.
// https://docs.rs-online.com/6412/0900766b806dda0d.pdf
export const STN_APERTURE_RATIO = 0.39 / 0.43;
export const MATRIX_PROFILES = ["STN", "CLASSIC"];

const clamp = (value, min = 0, max = 1) => Math.max(min, Math.min(max, value));
const linear = (channel) => channel <= 0.04045
  ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4;
const srgb = (value) => value <= 0.0031308
  ? value * 12.92 : 1.055 * value ** (1 / 2.4) - 0.055;
const rgb = (hex) => [1, 3, 5].map((offset) => parseInt(hex.slice(offset, offset + 2), 16));
const hex = (channels) => `#${channels.map((value) =>
  Math.round(clamp(value, 0, 255)).toString(16).padStart(2, "0")).join("")}`.toUpperCase();

export function mixReflectance(from, to, amount) {
  const a = rgb(from).map((value) => linear(value / 255));
  const b = rgb(to).map((value) => linear(value / 255));
  return hex(a.map((value, index) => srgb(clamp(value + (b[index] - value) * amount)) * 255));
}

// A deliberate readability control, not a literal voltage calibration.
// Gain is relative to BG, so both dark-on-light and light-on-dark work.
export function contrastInk(ink, background, boost = 0) {
  const gain = 1 + clamp(Number(boost) / 100) * 2;
  return mixReflectance(background, ink, gain);
}

export function stnPalette(ink, background, boost = 0) {
  const active = contrastInk(ink, background, boost);
  return [active, mixReflectance(active, background, 0.25),
    mixReflectance(active, background, 0.8), background];
}

// Integrate the aperture over each physical display pixel. Rounding a gap up
// to a whole display pixel at 3x cuts active area from 82% to just 44%.
// This centered mask preserves the cell pitch, including at 2x and on Retina.
export function cellCoverage(size, matrix = true, profile = "STN") {
  if (!matrix) return Array(size * size).fill(1);
  if (profile === "CLASSIC") return Array.from({ length: size * size }, (_, index) =>
    index % size < size - 1 && Math.floor(index / size) < size - 1 ? 1 : 0);
  const inset = size * (1 - STN_APERTURE_RATIO) / 2;
  const axis = Array.from({ length: size }, (_, index) =>
    clamp(Math.min(index + 1, size - inset) - Math.max(index, inset)));
  return axis.flatMap((y) => axis.map((x) => x * y));
}

export function deviceCell(ink, background, coverage, boost = 0) {
  // Readability gain is separate from physical coverage. Classic 1 PX cells
  // have only binary coverage: tint their gutters toward ink, capped at 65%,
  // so saturated black/white faces still gain contrast and the grid survives.
  // Zero boost reproduces the selected aperture without this adjustment.
  const strength = clamp(Number(boost) / 100);
  const gain = 1 + strength * 2;
  return coverage.map((area) => {
    const opacity = area === 0 ? strength * 0.65
      : area < 1 ? Math.min(0.98, 1 - (1 - area) ** gain) : area;
    return mixReflectance(background, ink, opacity);
  });
}
