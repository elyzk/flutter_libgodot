import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'src/bindings.dart';

typedef GDExtensionInitializationNative = Uint8 Function(
  GDExtensionInterfaceGetProcAddress,
  GDExtensionClassLibraryPtr,
  Pointer<GDExtensionInitialization>,
);

  // -------- typedefs for the init/deinit callbacks --------
// (Adjust the Int32/Uint8 to match your ffigen output if it generated enums)
typedef _LevelInitNative = Void Function(Pointer<Void> userdata, UnsignedInt level);
typedef _LevelInitDart   = void Function(Pointer<Void> userdata, u_int32_t level);

// int onInit(
//   GDExtensionInterfaceGetProcAddress getProc,
//   GDExtensionClassLibraryPtr lib,
//   Pointer<GDExtensionInitialization> init,
// ) {
//   print("Godot initializing");
//   return 1; // true
// }

LibGodotBindings getGodotBindings() {
  final exeDir = File(Platform.resolvedExecutable).parent;
  final libPath = '${exeDir.path}/../Frameworks/libgodot.dylib';
  final dylib = DynamicLibrary.open(libPath);
  final godot = LibGodotBindings(dylib);

  return godot;
}

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
// Called by Godot during init / deinit at specific levels
void _onLevelInit(Pointer<Void> userdata, int level) {
}

void _onLevelDeinit(Pointer<Void> userdata, int level) {
}

// GDExtensionInitializationFunction

int onInit(
  GDExtensionInterfaceGetProcAddress getProcAddress,
  GDExtensionClassLibraryPtr library,
  Pointer<GDExtensionInitialization> rInitialization,
) {
  // // Initialize all of the GDExtensionInitialization variables
  final init = rInitialization.ref;

  init.minimum_initialization_levelAsInt = 0; 
  init.initialize   = Pointer.fromFunction<_LevelInitNative>(_onLevelInit);
  init.deinitialize = Pointer.fromFunction<_LevelInitNative>(_onLevelDeinit);
  init.userdata = nullptr;

  return 1; // true
}

class GodotWrapper {
  final Completer<void> _ready = Completer<void>();
  Future<void> onReady() => _ready.future;

  late final LibGodotBindings bindings;
  Pointer<Void>? godotInstance;

  // keep these globals until shutdown; don’t free early
  late Pointer<Pointer<Char>> _argv;
  late Pointer<Utf8> _arg0;

  void _prepareArgv() {
    _arg0 = "flutter_godot".toNativeUtf8();
    _argv = calloc<Pointer<Char>>(1);
    _argv[0] = _arg0.cast<Char>();
  }

  GodotWrapper() {
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

    if (instance == nullptr) {
      return;
    }

    _ready.complete();
    print("Instance created");

    godotInstance = instance;
  });
}
}

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
    return Text(init ? "Godot ready!" : "Initializing Godot...");
  }
}
