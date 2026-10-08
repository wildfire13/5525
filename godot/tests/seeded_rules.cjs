// Deterministic encounter draws for the UI parity regression only.
Math.random = () => 0;
require('../../native/bridge.cjs');
