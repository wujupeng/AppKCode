'use strict';

const TEST_PLUGIN_ID = 'com.appkcode.test-plugin';
const TEST_PLUGIN_VERSION = '1.0.0';

let pluginContext = null;
let activated = false;

async function activate(context) {
  pluginContext = context;
  activated = true;

  const baseDir = await context.Project.getBaseDir();
  const text = await context.Editor.getText();

  return {
    pluginId: TEST_PLUGIN_ID,
    version: TEST_PLUGIN_VERSION,
    baseDir,
    editorTextLength: text ? String(text).length : 0,
    activated: true
  };
}

async function deactivate(context) {
  activated = false;
  pluginContext = null;
  return { pluginId: TEST_PLUGIN_ID, deactivated: true };
}

module.exports = {
  pluginId: TEST_PLUGIN_ID,
  version: TEST_PLUGIN_VERSION,
  activate,
  deactivate
};