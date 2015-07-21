library w_module.src.lifecycle_module;

import 'dart:async';

/// Intended to be extended by most base module classes in order to provide a unified
/// lifecycle API.
abstract class LifecycleModule {

  /// Name of the module for identification within exceptions and while debugging.
  String get name => 'Module';

  /// List of child components so that lifecycle can iterate over them as needed
  List<LifecycleModule> _childModules = [];

  // Broadcast streams for load / unload lifecycle events
  StreamController<LifecycleModule> _willLoadController;
  Stream<LifecycleModule> get willLoad => _willLoadController.stream;

  StreamController<LifecycleModule> _didLoadController;
  Stream<LifecycleModule> get didLoad => _didLoadController.stream;

  StreamController<LifecycleModule> _willUnloadController;
  Stream<LifecycleModule> get willUnload => _willUnloadController.stream;

  StreamController<LifecycleModule> _didUnloadController;
  Stream<LifecycleModule> get didUnload => _didUnloadController.stream;

  // constructor necessary to init load / unload state stream
  LifecycleModule() {
    _willLoadController = new StreamController<LifecycleModule>.broadcast();
    _didLoadController = new StreamController<LifecycleModule>.broadcast();
    _willUnloadController = new StreamController<LifecycleModule>.broadcast();
    _didUnloadController = new StreamController<LifecycleModule>.broadcast();
  }

  //--------------------------------------------------------
  // Public methods that can be used directly to trigger
  // module lifecycle / check current lifecycle state
  //--------------------------------------------------------

  /// Public method to trigger the loading of a Module.
  /// Calls the onLoad() method, which can be implemented on a Module.
  /// Executes the willLoad and didLoad event streams.
  Future load() async {
    _willLoadController.add(this);
    await onLoad();
    _didLoadController.add(this);
  }

  /// Public method to async load a child module and register it
  /// for lifecycle management
  Future loadModule(LifecycleModule newModule) async {
    newModule.willUnload.listen((_) {
      _childModules.remove(newModule);
    });
    newModule.didLoad.listen((_) {
      _childModules.add(newModule);
    });
    await newModule.load();
  }

  /// Public method to query the unloadable state of the Module.
  /// Calls the onShouldUnload() method, which can be implemented on a Module.
  /// onShouldUnload is also called on all registered child modules
  ShouldUnloadResult shouldUnload() {

    // collect results from all child modules and self
    List<ShouldUnloadResult> shouldUnloads = [];
    _childModules.forEach((child) {
      shouldUnloads.add(child.shouldUnload());
    });
    shouldUnloads.add(onShouldUnload());

    // aggregate into 1 combined result
    ShouldUnloadResult finalResult = new ShouldUnloadResult();
    shouldUnloads.forEach((res) {
      if (!res.shouldUnload) {
        finalResult.shouldUnload = false;
        finalResult.messages.addAll(res.messages);
      }
    });
    return finalResult;
  }

  /// Public method to trigger the Module unload cycle.
  /// Calls shouldUnload(), and, if that completes successfully,
  /// continues to call onUnload() on the module and all registered child modules.
  /// If unloading is rejected, this method will complete with an error.
  Future unload() async {
    ShouldUnloadResult canUnload = shouldUnload();
    if (canUnload.shouldUnload) {
      _willUnloadController.add(this);
      Iterable<Future> unloadChildren = _childModules.map((c) => c.unload());
      await Future.wait(unloadChildren);
      _childModules.clear();
      await onUnload();
      _didUnloadController.add(this);
    } else {
      //  reject with shouldUnload messages
      throw new ModuleUnloadCanceledException(canUnload.messagesAsString());
    }
  }

  //--------------------------------------------------------
  // Methods that can be optionally implemented by subclasses
  // to execute code during certain phases of the module
  // lifecycle
  //--------------------------------------------------------

  /// Initial data queries & interactions with the server should be triggered here.
  /// Completes a future with no payload indicating that the module has finished loading.
  Future onLoad() async {}

  /// Returns a ShouldUnloadResult.
  /// [ShouldUnloadResult.shouldUnload == true] indicates that the module is safe to unload.
  /// [ShouldUnloadResult.shouldUnload == false] indicates that the module should not be unloaded.
  /// In this case, ShouldUnloadResult.messages contains a list of string messages indicating
  /// why unload was rejected.
  ShouldUnloadResult onShouldUnload() {
    return new ShouldUnloadResult();
  }

  /// Called on unload if shouldUnload completes with true.
  /// Use this for cleanup.
  /// Completes a future with no payload indicating that the module has finished unloading.
  Future onUnload() async {}
}

class ModuleUnloadCanceledException implements Exception {
  String message;

  ModuleUnloadCanceledException(this.message);
}

class ShouldUnloadResult {
  bool shouldUnload;
  List<String> messages;

  ShouldUnloadResult([this.shouldUnload = true, String message]) {
    messages = [];
    if (message != null) {
      messages.add(message);
    }
  }

  bool call() => shouldUnload;

  String messagesAsString() {
    return messages.join('\n');
  }
}