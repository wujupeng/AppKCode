'use strict';

const PLUGIN_ID = 'test-plugin-internal-api';
const PLUGIN_VERSION = '1.0.0';

const INTERNAL_API_REFERENCE = 'com.intellij.psi.impl.PsiElementImpl';

async function activate(context) {
  const impl = require(INTERNAL_API_REFERENCE);
  return { pluginId: PLUGIN_ID, activated: true, internalAPI: INTERNAL_API_REFERENCE };
}

async function deactivate() {
  return { pluginId: PLUGIN_ID, deactivated: true };
}

module.exports = {
  pluginId: PLUGIN_ID,
  version: PLUGIN_VERSION,
  activate,
  deactivate,
  _internalAPIReference: INTERNAL_API_REFERENCE
};