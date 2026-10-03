'use strict';

function createWorkspaceFsShim(rpc, base) {
  const Uri = base.Uri;
  const Disposable = base.Disposable;

  const fs = {
    readFile: async (uri) => {
      const result = await rpc.request('fs.readFile', { uri: uri.toString() });
      return Buffer.from(result.data, 'base64');
    },
    writeFile: async (uri, content) => {
      const data = Buffer.isBuffer(content) ? content.toString('base64') : Buffer.from(content).toString('base64');
      return rpc.request('fs.writeFile', { uri: uri.toString(), data });
    },
    readdir: async (uri) => {
      const result = await rpc.request('fs.readdir', { uri: uri.toString() });
      return result.entries.map(e => ({
        type: e.type,
        name: e.name,
        uri: Uri.parse(e.uri)
      }));
    },
    delete: async (uri, options) => {
      return rpc.request('fs.delete', { uri: uri.toString(), options: options || {} });
    },
    rename: async (source, target, options) => {
      return rpc.request('fs.rename', {
        source: source.toString(),
        target: target.toString(),
        options: options || {}
      });
    },
    copy: async (source, target, options) => {
      return rpc.request('fs.copy', {
        source: source.toString(),
        target: target.toString(),
        options: options || {}
      });
    },
    stat: async (uri) => {
      return rpc.request('fs.stat', { uri: uri.toString() });
    },
    createDirectory: async (uri) => {
      return rpc.request('fs.createDirectory', { uri: uri.toString() });
    },
    isReadonly: async (uri) => {
      const stat = await rpc.request('fs.stat', { uri: uri.toString() });
      return stat.readonly === true;
    }
  };

  const workspace = {
    fs: fs,

    workspaceFolders: null,

    getWorkspaceFolder: (uri) => {
      if (!workspace.workspaceFolders) return undefined;
      for (const folder of workspace.workspaceFolders) {
        if (uri.toString().startsWith(folder.uri.toString())) {
          return folder;
        }
      }
      return undefined;
    },

    getConfiguration: (section, scope) => {
      return {
        get: async (key, defaultValue) => {
          return rpc.request('workspace.getConfiguration', {
            section, key, scope: scope ? scope.toString() : undefined
          }).then(v => (v === undefined ? defaultValue : v));
        },
        has: async (key) => {
          return rpc.request('workspace.hasConfiguration', { section, key });
        },
        inspect: async (key) => {
          return rpc.request('workspace.inspectConfiguration', { section, key });
        },
        update: async (key, value, target) => {
          return rpc.request('workspace.updateConfiguration', { section, key, value, target });
        }
      };
    },

    onDidChangeConfiguration: (callback) => {
      const handlerId = 'workspace.onDidChangeConfiguration';
      rpc.registerHandler(handlerId, (params) => callback(params));
      return new Disposable(() => rpc.notification('unsubscribe', { handler: handlerId }));
    },

    findFiles: async (include, exclude, maxResults) => {
      const result = await rpc.request('workspace.findFiles', {
        include: include.toString(),
        exclude: exclude ? exclude.toString() : undefined,
        maxResults
      });
      return result.uris.map(u => Uri.parse(u));
    },

    openTextDocument: async (uriOrContent) => {
      if (typeof uriOrContent === 'string') {
        return rpc.request('workspace.openTextDocument', { content: uriOrContent });
      }
      if (uriOrContent && uriOrContent.scheme) {
        return rpc.request('workspace.openTextDocument', { uri: uriOrContent.toString() });
      }
      return rpc.request('workspace.openTextDocument', { options: uriOrContent });
    },

    saveAll: async () => {
      return rpc.request('workspace.saveAll', {});
    },

    onDidChangeTextDocument: (callback) => {
      const handlerId = 'workspace.onDidChangeTextDocument';
      rpc.registerHandler(handlerId, (params) => callback(params));
      return new Disposable(() => rpc.notification('unsubscribe', { handler: handlerId }));
    },

    onDidCloseTextDocument: (callback) => {
      const handlerId = 'workspace.onDidCloseTextDocument';
      rpc.registerHandler(handlerId, (params) => callback(params));
      return new Disposable(() => rpc.notification('unsubscribe', { handler: handlerId }));
    },

    onDidSaveTextDocument: (callback) => {
      const handlerId = 'workspace.onDidSaveTextDocument';
      rpc.registerHandler(handlerId, (params) => callback(params));
      return new Disposable(() => rpc.notification('unsubscribe', { handler: handlerId }));
    },

    asRelativePath: (uriOrFsPath, includeWorkspaceFolder) => {
      const path = require('path');
      const fsPath = uriOrFsPath.fsPath || uriOrFsPath;
      if (!workspace.workspaceFolders || workspace.workspaceFolders.length === 0) return fsPath;
      for (const folder of workspace.workspaceFolders) {
        const folderPath = folder.uri.fsPath;
        if (fsPath.startsWith(folderPath)) {
          const relative = path.relative(folderPath, fsPath);
          if (includeWorkspaceFolder && workspace.workspaceFolders.length > 1) {
            return path.join(folder.name, relative);
          }
          return relative;
        }
      }
      return fsPath;
    },

    rootPath: null
  };

  rpc.registerHandler('workspace.setWorkspaceFolders', (params) => {
    workspace.workspaceFolders = (params.folders || []).map(f => ({
      uri: Uri.parse(f.uri),
      name: f.name,
      index: f.index
    }));
    if (workspace.workspaceFolders.length > 0) {
      workspace.rootPath = workspace.workspaceFolders[0].uri.fsPath;
    } else {
      workspace.rootPath = undefined;
    }
  });

  return workspace;
}

module.exports = { create: createWorkspaceFsShim };