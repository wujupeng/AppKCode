'use strict';

const baseTypes = require('./base-types-shim.js');
const workspaceFsShim = require('./workspace-fs-shim.js');
const windowCommandsShim = require('./window-commands-shim.js');
const languagesExtensionsShim = require('./languages-extensions-shim.js');

function createVscodeShim(rpc, base) {
  const Disposable = base.Disposable;
  const Event = base.Event;
  const Uri = base.Uri;
  const Position = base.Position;
  const Range = base.Range;
  const CancellationToken = base.CancellationToken;
  const TextDocument = base.TextDocument;
  const TextEditor = base.TextEditor;

  const workspace = workspaceFsShim.create(rpc, base);
  const { window, commands } = windowCommandsShim.create(rpc, base);
  const { languages, extensions, env, tasks } = languagesExtensionsShim.create(rpc, base);

  const vscode = {
    workspace,
    window,
    commands,
    languages,
    extensions,
    env,
    tasks,
    Disposable,
    Event,
    Uri,
    Position,
    Range,
    CancellationToken,
    TextDocument,
    TextEditor,
    version: '1.0.0'
  };

  return vscode;
}

module.exports = { create: createVscodeShim };
const Module = require('module');
const originalLoad = Module._load;
Module._load = function(request, parent, isMain) {
  if (request.startsWith('vscode.proposed.')) {
    const error = new Error('该 Extension 使用 proposed API，不支持: ' + request);
    error.code = 'PROPOSED_API_REJECTED';
    error.proposedModule = request;
    throw error;
  }
  return originalLoad.apply(this, arguments);
};
