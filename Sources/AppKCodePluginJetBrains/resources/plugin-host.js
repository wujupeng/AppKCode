'use strict';

const readline = require('readline');
const path = require('path');
const fs = require('fs');

const { OpenAPIShim } = require('./openapi-shim.js');
const { PluginClassLoader, InternalAPIScanner } = require('./classloader-isolation.js');

const PLUGIN_HOST_VERSION = '1.0.0';
const JSONRPC_VERSION = '2.0';

let nextRequestId = 1;
const pendingRequests = new Map();
let shim = null;
let initialized = false;

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
  terminal: false
});

function sendMessage(msg) {
  process.stdout.write(JSON.stringify(msg) + '\n');
}

function sendRequest(method, params) {
  return new Promise((resolve, reject) => {
    const id = nextRequestId++;
    pendingRequests.set(id, { resolve, reject });
    sendMessage({ jsonrpc: JSONRPC_VERSION, id, method, params });
  });
}

function sendNotification(method, params) {
  sendMessage({ jsonrpc: JSONRPC_VERSION, method, params });
}

function sendResponse(id, result) {
  sendMessage({ jsonrpc: JSONRPC_VERSION, id, result });
}

function sendError(id, code, message) {
  sendMessage({ jsonrpc: JSONRPC_VERSION, id, error: { code, message } });
}

async function handleMessage(msg) {
  if (msg.id !== undefined && msg.method) {
    try {
      const result = await handleRequest(msg.method, msg.params || {});
      sendResponse(msg.id, result);
    } catch (err) {
      sendError(msg.id, -32603, err.message || 'Internal error');
    }
  } else if (msg.id !== undefined && (msg.result !== undefined || msg.error)) {
    const pending = pendingRequests.get(msg.id);
    if (pending) {
      pendingRequests.delete(msg.id);
      if (msg.error) {
        pending.reject(new Error(msg.error.message));
      } else {
        pending.resolve(msg.result);
      }
    }
  } else if (msg.method) {
    handleNotification(msg.method, msg.params || {});
  }
}

async function handleRequest(method, params) {
  switch (method) {
    case 'initialize':
      if (initialized) {
        throw new Error('Plugin host already initialized');
      }
      shim = new OpenAPIShim(sendRequest, sendNotification);
      initialized = true;
      return { version: PLUGIN_HOST_VERSION, capabilities: ['openapi-shim', 'classloader-isolation'] };

    case 'loadPlugin': {
      if (!initialized) {
        throw new Error('Plugin host not initialized');
      }
      const { pluginPath, pluginId } = params;
      const scanner = new InternalAPIScanner();
      const internalRefs = scanner.scanJAR(pluginPath);
      if (internalRefs.length > 0) {
        sendNotification('plugin.loadRejected', {
          pluginId,
          reason: 'Internal API references detected',
          references: internalRefs
        });
        return { loaded: false, reason: 'internal-api-detected', references: internalRefs };
      }
      const classLoader = new PluginClassLoader(pluginPath, pluginId);
      const loaded = classLoader.load();
      if (loaded) {
        sendNotification('plugin.loaded', { pluginId, classLoaderId: classLoader.id });
      }
      return { loaded, pluginId, classLoaderId: classLoader.id };
    }

    case 'activate': {
      const { pluginId, entryPoint } = params;
      if (!shim) {
        throw new Error('Shim not initialized');
      }
      const result = await shim.activatePlugin(pluginId, entryPoint);
      return result;
    }

    case 'deactivate': {
      const { pluginId } = params;
      if (!shim) {
        throw new Error('Shim not initialized');
      }
      const result = await shim.deactivatePlugin(pluginId);
      return result;
    }

    case 'capability.invoke': {
      const { capabilityID, input, sessionID } = params;
      if (!shim) {
        throw new Error('Shim not initialized');
      }
      const result = await shim.invokeCapability(capabilityID, input, sessionID);
      return result;
    }

    case 'project.getBaseDir':
    case 'project.getProjectDir':
    case 'editor.getText':
    case 'editor.getCaretModel':
    case 'editor.getSelectionModel':
    case 'vfs.getPath':
    case 'vfs.getContents':
    case 'vfs.exists':
    case 'fileEditor.openFile':
    case 'fileEditor.closeFile':
    case 'fileEditor.getSelectedFiles':
    case 'action.registerAction':
    case 'action.actionPerformed':
    case 'application.invokeLater':
    case 'application.isDisposed':
    case 'runManager.getRunConfigurations':
    case 'runManager.createConfiguration':
    case 'psi.getChildren':
    case 'psi.getText':
    case 'psi.getContainingFile':
      if (!shim) {
        throw new Error('Shim not initialized');
      }
      return await shim.forwardToMain(method, params);

    case 'ui.showInfoMessage':
    case 'ui.showInputDialog':
    case 'ui.showChooseDialog':
    case 'ui.showOkCancelDialog':
      return await sendRequest(method, params);

    case 'shutdown':
      if (shim) {
        await shim.deactivateAll();
      }
      sendNotification('host.shutdown', { graceful: true });
      return { shutdown: true };

    default:
      throw new Error(`Method not found: ${method}`);
  }
}

function handleNotification(method, params) {
  switch (method) {
    case 'onDidChangeTextDocument':
      if (shim) {
        shim.handleTextDocumentChange(params);
      }
      break;
    case 'onDidChangeConfiguration':
      if (shim) {
        shim.handleConfigurationChange(params);
      }
      break;
    default:
      break;
  }
}

rl.on('line', (line) => {
  if (!line.trim()) return;
  try {
    const msg = JSON.parse(line);
    handleMessage(msg).catch((err) => {
      if (msg && msg.id !== undefined) {
        sendError(msg.id, -32603, err.message || 'Internal error');
      }
    });
  } catch (err) {
    sendMessage({ jsonrpc: JSONRPC_VERSION, error: { code: -32700, message: 'Parse error' } });
  }
});

rl.on('close', () => {
  if (shim) {
    shim.deactivateAll().catch(() => {});
  }
  process.exit(0);
});

process.on('uncaughtException', (err) => {
  sendNotification('host.crashed', { error: err.message, stack: err.stack });
  process.exit(1);
});

sendMessage({ jsonrpc: JSONRPC_VERSION, method: 'host.ready', params: { version: PLUGIN_HOST_VERSION } });