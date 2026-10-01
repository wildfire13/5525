"use strict";
// CrimsonLilyJRPG/src/utils.js より、DOM取得・数値表示の3関数を流用。
const $ = (id) => document.getElementById(id);
const clamp = (value, min, max) => Math.max(min, Math.min(max, value));
const pct = (value, max) => `${clamp((value / max) * 100, 0, 100).toFixed(1)}%`;
