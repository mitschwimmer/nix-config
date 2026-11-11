const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const logic = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname,
    '../dotfiles/quickshell/SidebarLogic.js'), 'utf8').replace(/^\.pragma library\s*/, ''), logic);
const screen = (name, x, y, width = 1920, height = 1080) => ({ name, x, y, width, height });
const segments = screens => JSON.parse(JSON.stringify(logic.edgeSegments(screens)))
    .map(edge => [edge.screen.name, edge.side, edge.top, edge.height]);

test('single monitor has both full-height edges', () => {
    assert.deepEqual(segments([screen('a', 0, 0)]), [
        ['a', 'left', 0, 1080], ['a', 'right', 0, 1080]
    ]);
});

test('adjacent monitors leave the shared seam unobstructed', () => {
    assert.deepEqual(segments([screen('a', -1920, 0), screen('b', 0, 0)]), [
        ['a', 'left', 0, 1080], ['b', 'right', 0, 1080]
    ]);
});

test('staggered monitors expose only the unshared edge segments', () => {
    assert.deepEqual(segments([screen('a', 0, 0), screen('b', 1920, 400)]), [
        ['a', 'left', 0, 1080], ['a', 'right', 0, 400],
        ['b', 'left', 680, 400], ['b', 'right', 0, 1080]
    ]);
});

test('two neighbours split a tall edge and hotplug restores it', () => {
    const a = screen('a', 0, 0, 1000, 2000);
    const b = screen('b', 1000, 200, 1000, 500);
    const c = screen('c', 1000, 1000, 1000, 500);
    assert.deepEqual(segments([a, b, c]).filter(edge => edge[0] === 'a'), [
        ['a', 'left', 0, 2000], ['a', 'right', 0, 200],
        ['a', 'right', 700, 300], ['a', 'right', 1500, 500]
    ]);
    assert.deepEqual(segments([a]), [['a', 'left', 0, 2000], ['a', 'right', 0, 2000]]);
});

test('stacked monitors retain both vertical edges and empty layouts are valid', () => {
    assert.equal(segments([screen('a', 0, 0), screen('b', 0, 1080)]).length, 4);
    assert.deepEqual(segments([]), []);
});

test('battery time estimates omit unknown values and format minutes', () => {
    for (const seconds of [0, -1, NaN, Infinity]) assert.equal(logic.duration(seconds), '');
    assert.equal(logic.duration(1), '1 min');
    assert.equal(logic.duration(120), '2 min');
    assert.equal(logic.duration(15600), '4 h 20 min');
});
