const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const logic = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname,
    '../dotfiles/quickshell/LauncherLogic.js'), 'utf8').replace(/^\.pragma library\s*/, ''), logic);
const entry = (id, name, extra = {}) => ({ id, name, ...extra });
const ids = (entries, query = '', excluded = []) =>
    Array.from(logic.applications(entries, query, excluded), app => app.id);

test('terminal and menu-hidden entries never appear, including for exact searches', () => {
    const entries = [
        entry('firefox', 'Firefox'),
        entry('helix', 'Helix', { runInTerminal: true }),
        entry('helper', 'Import Helper', { noDisplay: true }),
        entry('foot', 'Foot', { runInTerminal: false }),
    ];
    assert.deepEqual(ids(entries), ['firefox', 'foot']);
    assert.deepEqual(ids(entries, 'helix'), []);
    assert.deepEqual(ids(entries, 'helper'), []);
    assert.deepEqual(ids(entries, '', ['firefox']), ['foot']);
});

test('empty and whitespace queries sort by name with stable desktop ID ties', () => {
    const entries = [entry('z', 'Writer'), entry('b', 'Browser'), entry('a', 'Browser')];
    assert.deepEqual(ids(entries), ['a', 'b', 'z']);
    assert.deepEqual(ids(entries, '  \t '), ['a', 'b', 'z']);
    assert.deepEqual(ids([]), []);
});

test('exact names precede prefixes, substrings and metadata matches', () => {
    const entries = [
        entry('metadata', 'A Browser', { genericName: 'Firefox Web Browser' }),
        entry('substring', 'My Firefox'),
        entry('prefix', 'Firefox Beta'),
        entry('exact', 'Firefox'),
    ];
    assert.deepEqual(ids(entries, 'FIREFOX'), ['exact', 'prefix', 'substring', 'metadata']);
});

test('all search terms must match and localized accents and keywords are searchable', () => {
    const entries = [
        entry('files', 'Dóssiers', { genericName: 'File Manager', keywords: ['folder', 'documents'] }),
        entry('writer', 'Writer', { keywords: ['documents'] }),
    ];
    assert.deepEqual(ids(entries, 'dossiers'), ['files']);
    assert.deepEqual(ids(entries, ' folder  manager '), ['files']);
    assert.deepEqual(ids(entries, 'folder writer'), []);
    assert.deepEqual(ids(entries, 'nothing-matches'), []);
});

test('ranking preserves executable desktop objects and does not reorder the source', () => {
    const writer = entry('writer', 'Writer', { execute() {} });
    const browser = entry('browser', 'Browser');
    const entries = [writer, browser];
    const result = logic.applications(entries, 'writer', []);
    assert.equal(result[0], writer);
    assert.equal(result[0].execute, writer.execute);
    assert.deepEqual(entries, [writer, browser]);
});
