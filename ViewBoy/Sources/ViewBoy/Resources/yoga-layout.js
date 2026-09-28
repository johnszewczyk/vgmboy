/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 * @format
 */

// @ts-ignore untyped from Emscripten
import loadYoga from './yoga-wasm-base64-esm.js';
import wrapAssembly from "./yoga-wrapAssembly.js";
const Yoga = wrapAssembly(await loadYoga());
export default Yoga;
export * from "./yoga-YGEnums.js";
//# sourceMappingURL=index.js.map