'use strict';

const UNSUPPORTED_OPERATION = 'UnsupportedOperationException: PsiElement is read-only';

class OpenAPIShim {
  constructor(sendRequest, sendNotification) {
    this.sendRequest = sendRequest;
    this.sendNotification = sendNotification;
    this.activePlugins = new Map();
    this.disposables = new Map();
    this.nextHandleId = 1;
  }

  async activatePlugin(pluginId, entryPoint) {
    try {
      const pluginModule = require(entryPoint);
      const context = this._createPluginContext(pluginId);
      const result = await pluginModule.activate(context);
      this.activePlugins.set(pluginId, { module: pluginModule, context, activated: true });
      this.sendNotification('plugin.activated', { pluginId, result });
      return { activated: true, pluginId };
    } catch (err) {
      this.sendNotification('plugin.activationFailed', { pluginId, error: err.message });
      return { activated: false, pluginId, error: err.message };
    }
  }

  async deactivatePlugin(pluginId) {
    const plugin = this.activePlugins.get(pluginId);
    if (!plugin) {
      return { deactivated: false, reason: 'not-active' };
    }
    try {
      if (plugin.module.deactivate) {
        await plugin.module.deactivate(plugin.context);
      }
      const disposables = this.disposables.get(pluginId) || [];
      disposables.forEach(d => { try { d.dispose(); } catch (_) {} });
      this.disposables.delete(pluginId);
      this.activePlugins.delete(pluginId);
      this.sendNotification('plugin.deactivated', { pluginId });
      return { deactivated: true, pluginId };
    } catch (err) {
      return { deactivated: false, pluginId, error: err.message };
    }
  }

  async deactivateAll() {
    const ids = Array.from(this.activePlugins.keys());
    for (const id of ids) {
      await this.deactivatePlugin(id);
    }
  }

  async invokeCapability(capabilityID, input, sessionID) {
    return await this.sendRequest('capability.invoke', { capabilityID, input, sessionID });
  }

  async forwardToMain(method, params) {
    return await this.sendRequest(method, params);
  }

  handleTextDocumentChange(params) {
    for (const [_, plugin] of this.activePlugins) {
      if (plugin.context._onDidChangeTextDocument) {
        plugin.context._onDidChangeTextDocument(params);
      }
    }
  }

  handleConfigurationChange(params) {
    for (const [_, plugin] of this.activePlugins) {
      if (plugin.context._onDidChangeConfiguration) {
        plugin.context._onDidChangeConfiguration(params);
      }
    }
  }

  _createPluginContext(pluginId) {
    const self = this;
    return {
      pluginId,

      Project: {
        getBaseDir: () => self.sendRequest('project.getBaseDir', {}),
        getProjectDir: () => self.sendRequest('project.getProjectDir', {})
      },

      Editor: {
        getText: () => self.sendRequest('editor.getText', {}),
        getCaretModel: () => self.sendRequest('editor.getCaretModel', {}),
        getSelectionModel: () => self.sendRequest('editor.getSelectionModel', {})
      },

      VirtualFile: {
        getPath: (file) => self.sendRequest('vfs.getPath', { file }),
        getContents: (file) => self.sendRequest('vfs.getContents', { file }),
        exists: (file) => self.sendRequest('vfs.exists', { file })
      },

      FileEditorManager: {
        openFile: (file) => self.sendRequest('fileEditor.openFile', { file }),
        closeFile: (file) => self.sendRequest('fileEditor.closeFile', { file }),
        getSelectedFiles: () => self.sendRequest('fileEditor.getSelectedFiles', {})
      },

      AnAction: {
        registerAction: (actionId, handler) => {
          self.sendRequest('action.registerAction', { actionId });
          self._registerDisposable(pluginId, { dispose: () => self.sendNotification('action.unregisterAction', { actionId }) });
        },
        actionPerformed: (actionId, event) => self.sendRequest('action.actionPerformed', { actionId, event })
      },

      Application: {
        invokeLater: (callback) => self.sendRequest('application.invokeLater', {}),
        isDisposed: () => self.sendRequest('application.isDisposed', {})
      },

      Messages: {
        showInfoMessage: (title, message) => self.sendRequest('ui.showInfoMessage', { title, message }),
        showInputDialog: (title, message, initialValue) => self.sendRequest('ui.showInputDialog', { title, message, initialValue }),
        showChooseDialog: (title, message, values) => self.sendRequest('ui.showChooseDialog', { title, message, values }),
        showOkCancelDialog: (title, message) => self.sendRequest('ui.showOkCancelDialog', { title, message })
      },

      RunManager: {
        getRunConfigurations: () => self.sendRequest('runManager.getRunConfigurations', {}),
        createConfiguration: (name, type) => self.sendRequest('runManager.createConfiguration', { name, type })
      },

      PsiElement: {
        getChildren: (element) => self.sendRequest('psi.getChildren', { element }),
        getText: (element) => self.sendRequest('psi.getText', { element }),
        getContainingFile: (element) => self.sendRequest('psi.getContainingFile', { element }),
        add: () => { throw new Error(UNSUPPORTED_OPERATION); },
        replace: () => { throw new Error(UNSUPPORTED_OPERATION); },
        delete: () => { throw new Error(UNSUPPORTED_OPERATION); }
      },

      Disposable: {
        create: (disposeFn) => {
          const disposable = { dispose: disposeFn };
          self._registerDisposable(pluginId, disposable);
          return disposable;
        }
      },

      _onDidChangeTextDocument: null,
      _onDidChangeConfiguration: null,

      onDidChangeTextDocument: (callback) => {
        const ctx = self.activePlugins.get(pluginId)?.context;
        if (ctx) ctx._onDidChangeTextDocument = callback;
      },
      onDidChangeConfiguration: (callback) => {
        const ctx = self.activePlugins.get(pluginId)?.context;
        if (ctx) ctx._onDidChangeConfiguration = callback;
      }
    };
  }

  _registerDisposable(pluginId, disposable) {
    if (!this.disposables.has(pluginId)) {
      this.disposables.set(pluginId, []);
    }
    this.disposables.get(pluginId).push(disposable);
  }
}

module.exports = { OpenAPIShim, UNSUPPORTED_OPERATION };