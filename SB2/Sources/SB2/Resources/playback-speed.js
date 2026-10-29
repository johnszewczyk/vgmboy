(() => {
  const DEFAULT = Object.freeze({ numerator: 1, denominator: 1 });
  const MAX_COMPONENT = 1_000_000;
  const MAX_DECIMAL_PLACES = 6;
  const PLAYBACK_SPEED_STEPS_PER_UNIT = 32;
  const MAX_PLAYBACK_SPEED_STEPS = 256;
  const MAX_DISPLAY_FRACTION_DENOMINATOR = PLAYBACK_SPEED_STEPS_PER_UNIT;

  function greatestCommonDivisor(left, right) {
    let a = Math.abs(Math.trunc(left));
    let b = Math.abs(Math.trunc(right));
    while (b) [a, b] = [b, a % b];
    return a || 1;
  }

  function isValidComponents(numerator, denominator) {
    return Number.isSafeInteger(numerator) && Number.isSafeInteger(denominator) &&
      numerator >= 1 && denominator >= 1 &&
      numerator <= MAX_COMPONENT && denominator <= MAX_COMPONENT;
  }

  function normalize(value) {
    const numerator = Math.trunc(Number(value?.numerator));
    const denominator = Math.trunc(Number(value?.denominator));
    if (!isValidComponents(numerator, denominator)) {
      return { ...DEFAULT };
    }
    const steps = Math.min(
      MAX_PLAYBACK_SPEED_STEPS,
      Math.max(1, Math.round(numerator / denominator * PLAYBACK_SPEED_STEPS_PER_UNIT))
    );
    const divisor = greatestCommonDivisor(steps, PLAYBACK_SPEED_STEPS_PER_UNIT);
    return {
      numerator: steps / divisor,
      denominator: PLAYBACK_SPEED_STEPS_PER_UNIT / divisor
    };
  }

  function parse(value) {
    const text = String(value || "").trim();
    const fraction = /^(\d+)\s*\/\s*(\d+)$/.exec(text);
    if (fraction) {
      const candidate = { numerator: Number(fraction[1]), denominator: Number(fraction[2]) };
      return isValidComponents(candidate.numerator, candidate.denominator)
        ? normalize(candidate)
        : null;
    }
    const decimal = new RegExp(`^(?:(\\d+)(?:\\.(\\d{0,${MAX_DECIMAL_PLACES}}))?|\\.(\\d{1,${MAX_DECIMAL_PLACES}}))$`).exec(text);
    if (!decimal) return null;
    const decimals = decimal[2] ?? decimal[3] ?? "";
    const denominator = 10 ** decimals.length;
    const numerator = Number(decimal[1] || 0) * denominator + Number(decimals || 0);
    if (!isValidComponents(numerator, denominator)) return null;
    return normalize({ numerator, denominator });
  }

  function format(value) {
    const { numerator, denominator } = normalize(value);
    if (denominator > 1 && denominator <= MAX_DISPLAY_FRACTION_DENOMINATOR) {
      return `${numerator}/${denominator}`;
    }
    const scale = 10 ** MAX_DECIMAL_PLACES;
    if (scale % denominator !== 0) return `${numerator}/${denominator}`;
    const scaled = String(numerator * (scale / denominator)).padStart(MAX_DECIMAL_PLACES + 1, "0");
    const integer = scaled.slice(0, -MAX_DECIMAL_PLACES);
    const fraction = scaled.slice(-MAX_DECIMAL_PLACES).replace(/0+$/, "");
    return fraction ? `${integer}.${fraction}` : integer;
  }

  function scaleMilliseconds(milliseconds, speed) {
    const { numerator, denominator } = normalize(speed);
    const input = Math.max(0, Math.round(Number(milliseconds) || 0));
    return Math.floor((input * denominator + Math.floor(numerator / 2)) / numerator);
  }

  window.SB2PlaybackSpeed = Object.freeze({
    DEFAULT,
    normalize,
    parse,
    format,
    scaleMilliseconds
  });
})();
