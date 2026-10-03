'use strict';

function createWindowCommandsShim(rpc, base) {
  const Disposable = base.Disposable;

  const window = {
    showInformationMessage: async (message, ...items) => {
      return rpc.request('window.showInformationMessage', { message, items });
    },
    showErrorMessage: async (message, ...items) => {
      return rpc.request('window.showErrorMessage', { message, items });
    },
    showWarningMessage: async (message, ...items) => {
      return rpc.request('window.showWarningMessage', { message, items });
    },
    showInputBox: async (options) => {
      return rpc.request('window.showInputBox', { options: options || {} });
    },
    showQuickPick: async (items, options) => {
      return rpc.request('window.showQuickPick', { items, options: options || {} });
    },
    createOutputChannel: (name) => {
      return {
        name: name,
        append: (value) => rpc.notification('outputChannel.append', { name, value }),
        appendLine: (value) => rpc.notification('outputChannel.appendLine', { name, value }),
        clear: () => rpc.notification('outputChannel.clear', { name }),
        show: (preserveFocus) => rpc.notification('outputChannel.show', { name, preserveFocus }),
        hide: () => rpc.notification('outputChannel.hide', { name }),
        dispose: () => rpc.notification('outputChannel.dispose', { name })
      };
    },
    createTerminal: async (options) => {
      return rpc.request('window.createTerminal', { options: options || {} });
    },
    activeTextEditor: null,
    showTextDocument: async (document, column, preserveFocus) => {
      return rpc.request('window.showTextDocument', {
        document: document && document.uri ? document.uri.toString() : document,
        column,
        preserveFocus
      });
    },
    onDidChangeActiveTextEditor: (callback) => {
      const handlerId = 'window.onDidChangeActiveTextEditor';
      rpc.registerHandler(handlerId, (params) => callback(params));
      return new Disposable(() => rpc.notification('unsubscribe', { handler: handlerId }));
    }
  };

  const commands = {
    executeCommand: async (command, ...args) => {
      return rpc.request('commands.executeCommand', { command, args });
    },
    registerCommand: (command, callback, thisArg) => {
      const handlerId = 'commands.' + command;
      rpc.registerHandler(handlerId, (params) => {
        return callback.apply(thisArg, params.args || []);
      });
      rpc.notification('commands.registerCommand', { command });
      return new Disposable(() => {
        rpc.notification('commands.unregisterCommand', { command });
      });
    }
  };

  return { window, commands };
}

module.exports = { create: createWindowCommandsShim };