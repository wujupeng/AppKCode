'use strict';

const path = require('path');
const fs = require('fs');
const { execSync } = require('child_process');

const INTERNAL_API_PATTERNS = [
  'com.intellij.psi.impl.',
  'com.intellij.openapi.application.impl.',
  'com.intellij.util.messages.impl.'
];

class PluginClassLoader {
  constructor(pluginPath, pluginId) {
    this.pluginPath = pluginPath;
    this.pluginId = pluginId;
    this.id = `cl-${pluginId}-${Date.now()}`;
    this.loadedClasses = new Map();
    this.parentLast = true;
  }

  load() {
    try {
      if (!fs.existsSync(this.pluginPath)) {
        return false;
      }
      this._loadClasses();
      return true;
    } catch (err) {
      return false;
    }
  }

  _loadClasses() {
    const classFile = path.join(this.pluginPath, 'classes.json');
    if (fs.existsSync(classFile)) {
      const classes = JSON.parse(fs.readFileSync(classFile, 'utf8'));
      for (const [name, definition] of Object.entries(classes)) {
        this.loadedClasses.set(name, definition);
      }
    }
  }

  loadClass(className) {
    if (this.loadedClasses.has(className)) {
      return this.loadedClasses.get(className);
    }
    if (this.parentLast) {
      return null;
    }
    return null;
  }

  unload() {
    this.loadedClasses.clear();
  }
}

class InternalAPIScanner {
  constructor() {
    this.patterns = INTERNAL_API_PATTERNS;
  }

  scanJAR(jarPath) {
    const references = [];

    try {
      if (!fs.existsSync(jarPath)) {
        return references;
      }

      let output = '';
      try {
        output = execSync(`strings "${jarPath}"`, {
          encoding: 'utf8',
          timeout: 5000,
          maxBuffer: 10 * 1024 * 1024
        });
      } catch (_) {
        const data = fs.readFileSync(jarPath);
        output = data.toString('latin1');
      }

      const lines = output.split('\n');
      for (const line of lines) {
        for (const pattern of this.patterns) {
          if (line.includes(pattern)) {
            references.push(line.trim());
            break;
          }
        }
      }
    } catch (_) {
    }

    return references;
  }

  scanClassNames(classNames) {
    const references = [];
    for (const className of classNames) {
      for (const pattern of this.patterns) {
        if (className.startsWith(pattern) || className.includes(pattern)) {
          references.push(className);
          break;
        }
      }
    }
    return references;
  }

  isInternalAPI(className) {
    for (const pattern of this.patterns) {
      if (className.startsWith(pattern) || className.includes(pattern)) {
        return true;
      }
    }
    return false;
  }
}

class ClassLoaderRegistry {
  constructor() {
    this.classLoaders = new Map();
  }

  createClassLoader(pluginPath, pluginId) {
    const cl = new PluginClassLoader(pluginPath, pluginId);
    this.classLoaders.set(pluginId, cl);
    return cl;
  }

  getClassLoader(pluginId) {
    return this.classLoaders.get(pluginId);
  }

  unloadClassLoader(pluginId) {
    const cl = this.classLoaders.get(pluginId);
    if (cl) {
      cl.unload();
      this.classLoaders.delete(pluginId);
    }
  }

  unloadAll() {
    for (const [pluginId, cl] of this.classLoaders) {
      cl.unload();
    }
    this.classLoaders.clear();
  }

  isIsolated(pluginIdA, pluginIdB) {
    const clA = this.classLoaders.get(pluginIdA);
    const clB = this.classLoaders.get(pluginIdB);
    if (!clA || !clB) {
      return true;
    }
    return clA.id !== clB.id;
  }
}

module.exports = {
  PluginClassLoader,
  InternalAPIScanner,
  ClassLoaderRegistry,
  INTERNAL_API_PATTERNS
};