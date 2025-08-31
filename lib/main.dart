import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'src/bindings.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: GodotWidget(),
      ),
    );
  }
}

// Generate ffigen bindings from libgodot binary
LibGodotBindings getGodotBindings() {
  final exeDir = File(Platform.resolvedExecutable).parent;
  final libPath = '${exeDir.path}/../Frameworks/libgodot.dylib'; // macOS only (iOS maybe?)
  final dylib = DynamicLibrary.open(libPath);
  final godot = LibGodotBindings(dylib);

  return godot;
}

// This code is called at some point during the instance initialization process
// Not sure how to implement, so here is the skeleton for now
void _onLevelInit(Pointer<Void> userdata, int level) {
}

void _onLevelDeinit(Pointer<Void> userdata, int level) {
}

// native C typedef of a LevelInit/Deinit function 
typedef _LevelInitNative = Void Function(Pointer<Void> userdata, UnsignedInt level);


// This is an implementation of ffigen's GDExtensionInitializationFunctionFunction
// We use int instead of GDExtensionBool
int onInit(
  GDExtensionInterfaceGetProcAddress getProcAddress,
  GDExtensionClassLibraryPtr library,
  Pointer<GDExtensionInitialization> rInitialization,
) {
  // Initializing GDExtensionInitialization field variables, do not know what any of these are for yet
  final init = rInitialization.ref;

  init.minimum_initialization_levelAsInt = 0; 

  // pointers to native function definitions for libgodot to call later
  init.initialize   = Pointer.fromFunction<_LevelInitNative>(_onLevelInit); 
  init.deinitialize = Pointer.fromFunction<_LevelInitNative>(_onLevelDeinit);

  init.userdata = nullptr;

  return 1;
}

// Creates the Godot instance 
class GodotWrapper {
  // Futures that return to notify the rest of the program that the instance has been created
  final Completer<void> _ready = Completer<void>();
  Future<void> onReady() => _ready.future;

  late final LibGodotBindings bindings;
  Pointer<Void>? godotInstance;

  // These args are necessary for creating the instance because nullptr errors (I don't know their significance)
  late Pointer<Pointer<Char>> _argv;
  late Pointer<Utf8> _arg0;

  void _prepareArgv() {
    _arg0 = "flutter_godot".toNativeUtf8();
    _argv = calloc<Pointer<Char>>(1);
    _argv[0] = _arg0.cast<Char>();
  }

  GodotWrapper() {
    // This is required because otherwise creating the instance conflicts with Flutter's build()
    // There is likely a better way to accomplish this but I don't fully understand Flutter's build cycle
    WidgetsBinding.instance.addPostFrameCallback((_) { 
      final initFuncPtr =
      Pointer.fromFunction<GDExtensionInitializationFunctionFunction>(onInit, 0);
      bindings = getGodotBindings();

      _prepareArgv();
      final instance = bindings.libgodot_create_godot_instance(
        0,
        _argv,
        initFuncPtr,
      );

      // Need to cover this error case
      if (instance == nullptr) {
        return;
      }

      _ready.complete();

      godotInstance = instance;
    });
  }
}

// Eventually this should display a Godot window
class GodotWidget extends StatefulWidget {
  const GodotWidget({super.key});

  @override
  State<StatefulWidget> createState() => _GodotWidgetState();
}

class _GodotWidgetState extends State<GodotWidget> {
  final godot = GodotWrapper();
  bool init = false;

  @override
  void initState() {
    super.initState();
    Future<void> future = godot.onReady();
    future.then((_) {
      setState(() => init = true);
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Text(init ? "Initialized successfully" : "Initializing...");
  }
}
