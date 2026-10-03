'use strict';

const vscodeShim = require('./vscode-shim.js');
const baseTypes = require('./base-types-shim.js');

const RPC = {
  _nextId: 1,
  _pending: new Map(),
  _handlers: new Map(),

  init() {
    process.stdin.setEncoding('utf8');
    let buffer = '';
    process.stdin.on('data', (chunk) => {
      buffer += chunk;
      let idx;
      while ((idx = buffer.indexOf('\n')) >= 0) {
        const line = buffer.substring(0, idx);
        buffer = buffer.substring(idx + 1);
        if (line.trim()) {
          this._handleMessage(line);
        }
      }
    });
    process.stdin.on('end', () => {
      process.exit(0);
    });
  },

  send(message) {
    process.stdout.write(JSON.stringify(message) + '\n');
  },

  request(method, params) {
    return new Promise((resolve, reject) => {
      const id = this._nextId++;
      this._pending.set(id, { resolve, reject });
      this.send({ jsonrpc: '2.0', id, method, params });
    });
  },

  notification(method, params) {
    this.send({ jsonrpc: '2.0', method, params });
  },

  registerHandler(method, handler) {
    this._handlers.set(method, handler);
  },

  _registerProviderHandler(providerId, provider) {
    this.registerHandler(providerId + '.provideCompletionItems', (params) => {
      if (typeof provider.provideCompletionItems === 'function') {
        return provider.provideCompletionItems(
          params.document, params.position, params.token, params.context
        );
      }
      return undefined;
    });
    this.registerHandler(providerId + '.provideHover', (params) => {
      if (typeof provider.provideHover === 'function') {
        return provider.provideHover(params.document, params.position, params.token);
      }
      return undefined;
    });
    this.registerHandler(providerId + '.provideDefinition', (params) => {
      if (typeof provider.provideDefinition === 'function') {
        return provider.provideDefinition(params.document, params.position, params.token);
      }
      return undefined;
    });
    this.registerHandler(providerId + '.provideCodeActions', (params) => {
      if (typeof provider.provideCodeActions === 'function') {
        return provider.provideCodeActions(
          params.document, params.range, params.context, params.token
        );
      }
      return undefined;
    });
    this.registerHandler(providerId + '.provideTasks', (params) => {
      if (typeof provider.provideTasks === 'function') {
        return provider.provideTasks(params.token);
      }
      return undefined;
    });
  },

  _handleMessage(line) {
    let msg;
    try {
      msg = JSON.parse(line);
    } catch (e) {
      return;
    }
    if (msg.id !== undefined && msg.result !== undefined) {
      const pending = this._pending.get(msg.id);
      if (pending) {
        this._pending.delete(msg.id);
        pending.resolve(msg.result);
      }
    } else if (msg.id !== undefined && msg.error !== undefined) {
      const pending = this._pending.get(msg.id);
      if (pending) {
        this._pending.delete(msg.id);
        pending.reject(msg.error);
      }
    } else if (msg.method) {
      const handler = this._handlers.get(msg.method);
      if (handler) {
        Promise.resolve(handler(msg.params || {}))
          .then((result) => {
            if (msg.id !== undefined) {
              this.send({ jsonrpc: '2.0', id: msg.id, result });
            }
          })
          .catch((err) => {
            if (msg.id !== undefined) {
              this.send({
                jsonrpc: '2.0',
                id: msg.id,
                error: { code: -32603, message: String(err.message || err) }
              });
            }
          });
      }
    }
  }
};

RPC.init();

const ExtensionHost = {
  _extension: null,
  _extensionPath: null,
  _extensionApi: null,
  _disposables: [],

  async activate(extensionPath) {
    this._extensionPath = extensionPath;

    const proposedCheck = this._scanForProposedAPIs(extensionPath);
    if (proposedCheck.hasProposed) {
      RPC.notification('extension.proposedApiDetected', {
        extensionPath,
        proposedModules: proposedCheck.modules
      });
      throw new Error('该 Extension 使用 proposed API，不支持');
    }

    const vscode = vscodeShim.create(RPC, baseTypes);
    this._extensionApi = vscode;

    const module = require(extensionPath);
    this._extension = module;

    const context = {
      subscriptions: this._disposables,
      extensionPath: extensionPath,
      extensionUri: baseTypes.Uri.file(extensionPath),
      globalState: this._createMemento('global'),
      workspaceState: this._createMemento('workspace'),
      asAbsolutePath: (relativePath) => {
        const path = require('path');
        return path.join(extensionPath, relativePath);
      }
    };

    if (typeof module.activate === 'function') {
      const result = await module.activate(context);
      RPC.notification('extension.activated', { extensionPath });
      return result;
    }
    RPC.notification('extension.activated', { extensionPath });
    return undefined;
  },

  async deactivate() {
    if (this._extension && typeof this._extension.deactivate === 'function') {
      await this._extension.deactivate();
    }
    for (const d of this._disposables) {
      try { d.dispose(); } catch (e) { }
    }
    this._disposables = [];
    this._extension = null;
    this._extensionApi = null;
    RPC.notification('extension.deactivated', {});
  },

  _scanForProposedAPIs(extensionPath) {
    const fs = require('fs');
    const path = require('path');
    const proposedModules = [];

    const scanFile = (filePath) => {
      try {
        const content = fs.readFileSync(filePath, 'utf8');
        const proposedRegex = /require\s*\(\s*['"]vscode\.proposed\.[^'"]+['"]\s*\)/g;
        const importRegex = /import\s+.*from\s+['"]vscode\.proposed\.[^'"]+['"]/g;
        const matches = [];
        let m;
        while ((m = proposedRegex.exec(content)) !== null) matches.push(m[0]);
        while ((m = importRegex.exec(content)) !== null) matches.push(m[0]);
        return matches;
      } catch (e) {
        return [];
      }
    };

    const scanDir = (dir) => {
      try {
        const entries = fs.readdirSync(dir, { withFileTypes: true });
        for (const entry of entries) {
          const fullPath = path.join(dir, entry.name);
          if (entry.isDirectory() && !entry.name.startsWith('.') && entry.name !== 'node_modules') {
            scanDir(fullPath);
          } else if (entry.isFile() && (entry.name.endsWith('.js') || entry.name.endsWith('.ts'))) {
            proposedModules.push(...scanFile(fullPath));
          }
        }
      } catch (e) { }
    };

    scanDir(extensionPath);
    return {
      hasProposed: proposedModules.length > 0,
      modules: proposedModules
    };
  },

  _createMemento(scope) {
    const store = new Map();
    return {
      get: (key, defaultValue) => store.has(key) ? store.get(key) : defaultValue,
      update: async (key, value) => { store.set(key, value); },
      keys: () => Array.from(store.keys())
    };
  }
};

RPC.registerHandler('extension.activate', (params) => {
  return ExtensionHost.activate(params.extensionPath);
});

RPC.registerHandler('extension.deactivate', () => {
  return ExtensionHost.deactivate();
});

RPC.registerHandler('extension.ping', () => {
  return { pong: true, timestamp: Date.now() };
});

RPC.notification('extensionHost.ready', { pid: process.pid });

module.exports = { ExtensionHost, RPC };