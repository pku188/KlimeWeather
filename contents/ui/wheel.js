/*
 * Mouse-wheel notch resolution, shared by the card and graph layouts.
 * Copyright 2026  pku188 — SPDX-License-Identifier: GPL-2.0-or-later
 */
.pragma library

/*
 * One wheel event yields AT MOST one step, in whichever direction it points:
 * 1 = later (scroll down), -1 = earlier (scroll up), 0 = not a whole notch yet.
 *
 * The obvious version — accumulate deltas and drain them in a while loop — is what
 * made a single notch move two days/cards: a wheel event does not reliably carry
 * exactly 120 units. Drivers send 240, high-resolution wheels send small fractions,
 * and Qt compresses bursts into one event with the deltas summed. Any of those drains
 * the accumulator twice and steps twice, from what the user experienced as one notch.
 *
 * So: accumulate (a touchpad's small deltas still need to add up to a notch), but on
 * firing, reset to zero rather than carrying the remainder. The leftover is discarded
 * ON PURPOSE — spending it would be the doubling all over again. The cost is that a
 * very fast burst compressed into one event moves one step instead of several; the
 * gain is that one notch always means one step.
 *
 * `handler` is the WheelHandler itself, which carries the running total in an `acc`
 * property. Pass it by id: inside an arrow-function signal handler `this` binds
 * lexically and is NOT the handler.
 */
function step(handler, angleDelta) {
    if (angleDelta === 0) return 0;
    handler.acc += angleDelta;
    var dir = 0;
    if (handler.acc <= -120) dir = 1;
    else if (handler.acc >= 120) dir = -1;
    if (dir !== 0) handler.acc = 0;
    return dir;
}
