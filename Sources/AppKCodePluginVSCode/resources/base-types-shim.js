'use strict';

const path = require('path');

const Disposable = class Disposable {
  constructor(disposeCallback) {
    this._dispose = disposeCallback;
    this._disposed = false;
  }
  dispose() {
    if (this._disposed) return;
    this._disposed = true;
    if (typeof this._dispose === 'function') {
      this._dispose();
    }
  }
  static from(...disposables) {
    return new Disposable(() => {
      for (let i = disposables.length - 1; i >= 0; i--) {
        try { disposables[i].dispose(); } catch (e) { }
      }
    });
  }
};

const EventEmitter = class EventEmitter {
  constructor() {
    this._listeners = [];
  }
  event = (listener, thisArgs, disposables) => {
    const wrapped = thisArgs ? listener.bind(thisArgs) : listener;
    this._listeners.push(wrapped);
    const d = new Disposable(() => {
      const idx = this._listeners.indexOf(wrapped);
      if (idx >= 0) this._listeners.splice(idx, 1);
    });
    if (disposables) disposables.push(d);
    return d;
  };
  fire(data) {
    for (const listener of this._listeners.slice()) {
      try { listener(data); } catch (e) { }
    }
  }
  dispose() {
    this._listeners = [];
  }
};

const Event = {
  None: () => Disposable.from(),
  map: (event, map) => (listener, thisArgs, disposables) => event(i => listener(map(i)), thisArgs, disposables),
  filter: (event, filter) => (listener, thisArgs, disposables) => event(i => filter(i) ? listener(i) : undefined, thisArgs, disposables),
  fromPromise: (promise) => (listener, thisArgs, disposables) => {
    promise.then(result => listener(result));
    return Disposable.from();
  },
  debounce: (event, merge, delay) => (listener, thisArgs, disposables) => {
    let lastEvent = undefined;
    let timer = null;
    return event(e => {
      lastEvent = merge ? merge(lastEvent, e) : e;
      if (timer) clearTimeout(timer);
      timer = setTimeout(() => { timer = null; listener(lastEvent); }, delay);
    }, thisArgs, disposables);
  }
};

const Uri = class Uri {
  constructor(scheme, authority, path, query, fragment) {
    this.scheme = scheme || 'file';
    this.authority = authority || '';
    this.path = path || '';
    this.query = query || '';
    this.fragment = fragment || '';
  }
  get fsPath() {
    if (this.scheme !== 'file') return undefined;
    let p = this.path;
    if (process.platform === 'win32' && p.startsWith('/')) {
      p = p.substring(1);
    }
    return p;
  }
  toString() {
    let s = this.scheme + '://';
    if (this.authority) s += this.authority;
    s += this.path;
    if (this.query) s += '?' + this.query;
    if (this.fragment) s += '#' + this.fragment;
    return s;
  }
  with(change) {
    return new Uri(
      change.scheme !== undefined ? change.scheme : this.scheme,
      change.authority !== undefined ? change.authority : this.authority,
      change.path !== undefined ? change.path : this.path,
      change.query !== undefined ? change.query : this.query,
      change.fragment !== undefined ? change.fragment : this.fragment
    );
  }
  static parse(value) {
    const match = /^(\w+):\/\/([^\/]*)(\/[^?#]*)(\?[^#]*)?(#.*)?$/.exec(value);
    if (!match) return new Uri('file', '', value);
    return new Uri(
      match[1],
      match[2] || '',
      match[3] || '',
      match[4] ? match[4].substring(1) : '',
      match[5] ? match[5].substring(1) : ''
    );
  }
  static file(fsPath) {
    let p = fsPath;
    if (process.platform === 'win32') {
      p = '/' + p.replace(/\\/g, '/');
    }
    return new Uri('file', '', p);
  }
  static joinPath(base, ...pathSegments) {
    const newPath = path.join(base.path, ...pathSegments);
    return base.with({ path: newPath });
  }
};

const Position = class Position {
  constructor(line, character) {
    this.line = line;
    this.character = character;
  }
  isBefore(other) { return this.line < other.line || (this.line === other.line && this.character < other.character); }
  isBeforeOrEqual(other) { return this.isBefore(other) || this.isEqual(other); }
  isEqual(other) { return this.line === other.line && this.character === other.character; }
  isAfter(other) { return !this.isBeforeOrEqual(other); }
  isAfterOrEqual(other) { return !this.isBefore(other); }
  compare(other) {
    if (this.isBefore(other)) return -1;
    if (this.isAfter(other)) return 1;
    return 0;
  }
  translate(lineDelta, characterDelta) {
    return new Position(this.line + (lineDelta || 0), this.character + (characterDelta || 0));
  }
  with(line, character) {
    return new Position(
      line !== undefined ? line : this.line,
      character !== undefined ? character : this.character
    );
  }
};

const Range = class Range {
  constructor(start, end) {
    if (typeof start === 'number') {
      this.start = new Position(arguments[0], arguments[1]);
      this.end = new Position(arguments[2], arguments[3]);
    } else {
      this.start = start;
      this.end = end;
    }
  }
  get isEmpty() { return this.start.isEqual(this.end); }
  get isSingleLine() { return this.start.line === this.end.line; }
  contains(position) {
    return this.start.isBeforeOrEqual(position) && this.end.isAfterOrEqual(position);
  }
  isEqual(other) { return this.start.isEqual(other.start) && this.end.isEqual(other.end); }
  intersection(other) {
    const start = this.start.isAfter(other.start) ? this.start : other.start;
    const end = this.end.isBefore(other.end) ? this.end : other.end;
    if (start.isAfter(end)) return undefined;
    return new Range(start, end);
  }
  union(other) {
    const start = this.start.isBefore(other.start) ? this.start : other.start;
    const end = this.end.isAfter(other.end) ? this.end : other.end;
    return new Range(start, end);
  }
  with(start, end) {
    return new Range(
      start !== undefined ? start : this.start,
      end !== undefined ? end : this.end
    );
  }
};

const CancellationToken = class CancellationToken {
  constructor() {
    this._isCancellationRequested = false;
    this._emitter = new EventEmitter();
  }
  get isCancellationRequested() { return this._isCancellationRequested; }
  get onCancellationRequested() { return this._emitter.event; }
  cancel() {
    if (!this._isCancellationRequested) {
      this._isCancellationRequested = true;
      this._emitter.fire(undefined);
    }
  }
  dispose() { this._emitter.dispose(); }
  static get None() {
    const token = new CancellationToken();
    return token;
  }
};

const TextDocument = class TextDocument {
  constructor(data) {
    this._uri = Uri.parse(data.uri);
    this._fileName = data.fileName || data.uri;
    this._languageId = data.languageId || 'plaintext';
    this._version = data.version || 1;
    this._lineCount = data.lineCount || 0;
    this._content = data.content || '';
  }
  get uri() { return this._uri; }
  get fileName() { return this._fileName; }
  get languageId() { return this._languageId; }
  get version() { return this._version; }
  get lineCount() { return this._lineCount; }
  getText(range) {
    if (!range) return this._content;
    const lines = this._content.split('\n');
    const startLine = range.start.line;
    const endLine = range.end.line;
    const selected = lines.slice(startLine, endLine + 1);
    if (selected.length > 0) {
      selected[0] = selected[0].substring(range.start.character);
      if (startLine === endLine) {
        selected[0] = selected[0].substring(0, range.end.character - range.start.character);
      } else {
        selected[selected.length - 1] = selected[selected.length - 1].substring(0, range.end.character);
      }
    }
    return selected.join('\n');
  }
  getWordRangeAtPosition(position, regexp) {
    return undefined;
  }
  validateRange(range) { return range; }
  validatePosition(position) { return position; }
  lineAt(lineOrPosition) {
    const line = typeof lineOrPosition === 'number' ? lineOrPosition : lineOrPosition.line;
    const lines = this._content.split('\n');
    const text = lines[line] || '';
    return { lineNumber: line, text, range: new Range(line, 0, line, text.length), firstNonWhitespaceCharacterIndex: text.search(/\S/) };
  }
  offsetAt(position) {
    const lines = this._content.split('\n');
    let offset = 0;
    for (let i = 0; i < position.line && i < lines.length; i++) {
      offset += lines[i].length + 1;
    }
    return offset + position.character;
  }
  positionAt(offset) {
    const lines = this._content.split('\n');
    let remaining = offset;
    for (let i = 0; i < lines.length; i++) {
      if (remaining <= lines[i].length) {
        return new Position(i, remaining);
      }
      remaining -= lines[i].length + 1;
    }
    return new Position(lines.length - 1, 0);
  }
  save() {
    return Promise.resolve(this);
  }
};

const TextEditor = class TextEditor {
  constructor(data) {
    this._document = new TextDocument(data.document || {});
    this._selections = (data.selections || []).map(s => new Range(
      new Position(s.start.line, s.start.character),
      new Position(s.end.line, s.end.character)
    ));
    this._viewColumn = data.viewColumn || 1;
  }
  get document() { return this._document; }
  get selections() { return this._selections; }
  set selections(value) { this._selections = value; }
  get viewColumn() { return this._viewColumn; }
  edit(callback, options) {
    return Promise.resolve(true);
  }
  setDecorations(decorationType, rangesOrOptions) { }
  revealRange(range, revealType) { }
};

module.exports = {
  Disposable,
  EventEmitter,
  Event,
  Uri,
  Position,
  Range,
  CancellationToken,
  TextDocument,
  TextEditor
};