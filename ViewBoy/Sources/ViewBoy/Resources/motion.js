// SB2's shared CSS timing curve: cubic-bezier(0.2, 0, 0, 1).
// Time is x(u), not the Bezier parameter u. Invert x before evaluating y.
export function snappyEase(progress) {
  if (progress <= 0) return 0;
  if (progress >= 1) return 1;
  let low = 0;
  let high = 1;
  for (let iteration = 0; iteration < 24; iteration += 1) {
    const u = (low + high) / 2;
    const x = 0.6 * u * (1 - u) ** 2 + u ** 3;
    if (x < progress) low = u;
    else high = u;
  }
  const u = (low + high) / 2;
  return u * u * (3 - 2 * u);
}
