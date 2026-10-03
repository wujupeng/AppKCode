'use strict';

function createLanguagesExtensionsShim(rpc, base) {
  const Disposable = base.Disposable;

  const languages = {
    registerCompletionItemProvider: (selector, provider, ...triggerCharacters) => {
      const providerId = 'languages.completion.' + Date.now() + '.' + Math.random().toString(36).substr(2);
      rpc._registerProviderHandler(providerId, provider);
      rpc.notification('languages.registerCompletionItemProvider', {
        selector, providerId, triggerCharacters
      });
      return new Disposable(() => rpc.notification('languages.unregisterProvider', { providerId }));
    },
    registerHoverProvider: (selector, provider) => {
      const providerId = 'languages.hover.' + Date.now() + '.' + Math.random().toString(36).substr(2);
      rpc._registerProviderHandler(providerId, provider);
      rpc.notification('languages.registerHoverProvider', { selector, providerId });
      return new Disposable(() => rpc.notification('languages.unregisterProvider', { providerId }));
    },
    registerDefinitionProvider: (selector, provider) => {
      const providerId = 'languages.definition.' + Date.now() + '.' + Math.random().toString(36).substr(2);
      rpc._registerProviderHandler(providerId, provider);
      rpc.notification('languages.registerDefinitionProvider', { selector, providerId });
      return new Disposable(() => rpc.notification('languages.unregisterProvider', { providerId }));
    },
    registerCodeActionsProvider: (selector, provider) => {
      const providerId = 'languages.codeActions.' + Date.now() + '.' + Math.random().toString(36).substr(2);
      rpc._registerProviderHandler(providerId, provider);
      rpc.notification('languages.registerCodeActionsProvider', { selector, providerId });
      return new Disposable(() => rpc.notification('languages.unregisterProvider', { providerId }));
    },
    createDiagnosticCollection: (name) => {
      const collectionId = 'diagnostics.' + (name || Date.now());
      return {
        name: name || '',
        set: (uri, diagnostics) => rpc.notification('diagnostics.set', { collectionId, uri: uri.toString(), diagnostics }),
        delete: (uri) => rpc.notification('diagnostics.delete', { collectionId, uri: uri.toString() }),
        clear: () => rpc.notification('diagnostics.clear', { collectionId }),
        dispose: () => rpc.notification('diagnostics.dispose', { collectionId })
      };
    }
  };

  const extensions = {
    getExtension: (extensionId) => {
      return rpc.request('extensions.getExtension', { extensionId });
    },
    onDidChangeExtensions: (callback) => {
      const handlerId = 'extensions.onDidChangeExtensions';
      rpc.registerHandler(handlerId, () => callback());
      return new Disposable(() => rpc.notification('unsubscribe', { handler: handlerId }));
    }
  };

  const env = {
    openExternal: async (uri) => {
      return rpc.request('env.openExternal', { uri: uri.toString() });
    },
    clipboard: {
      readText: async () => rpc.request('env.clipboard.readText', {}),
      writeText: async (value) => rpc.request('env.clipboard.writeText', { value })
    }
  };

  const tasks = {
    executeTask: async (task) => {
      return rpc.request('tasks.executeTask', { task });
    },
    registerTaskProvider: (type, provider) => {
      const providerId = 'tasks.provider.' + Date.now() + '.' + Math.random().toString(36).substr(2);
      rpc._registerProviderHandler(providerId, provider);
      rpc.notification('tasks.registerTaskProvider', { type, providerId });
      return new Disposable(() => rpc.notification('tasks.unregisterProvider', { providerId }));
    }
  };

  return { languages, extensions, env, tasks };
}

module.exports = { create: createLanguagesExtensionsShim };