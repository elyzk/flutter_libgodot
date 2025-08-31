import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
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

// Store the interface functions globally after initialization
GDExtensionInterfaceGetProcAddress? _getProcAddressPtr;
GDExtensionClassLibraryPtr? _library;

// Dart function typedef for the getProcAddress function
typedef GetProcAddressDart = Pointer<Void> Function(Pointer<Char> name);

// Convert the function pointer to a callable Dart function
GDExtensionInterfaceGetProcAddressFunction? _getProcAddressFunc;

// Helper to get interface function pointers (must convert pointer to function afterwards)
GDExtensionInterfaceFunctionPtr? getInterfacePtr(String name) {
  if (_getProcAddressFunc == null) return null;
  
  final namePtr = name.toNativeUtf8();
  final funcPtr = _getProcAddressFunc!(namePtr.cast<Char>());
  calloc.free(namePtr);
  
  return funcPtr == nullptr ? null : funcPtr;
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
  _getProcAddressPtr = getProcAddress;
  _getProcAddressFunc = getProcAddress.asFunction<GDExtensionInterfaceGetProcAddressFunction>();
  _library = library;
  // Initializing GDExtensionInitialization field variables, do not know what any of these are for yet
  final init = rInitialization.ref;

  init.minimum_initialization_levelAsInt = 0; 

  // pointers to native function definitions for libgodot to call later
  init.initialize   = Pointer.fromFunction<_LevelInitNative>(_onLevelInit); 
  init.deinitialize = Pointer.fromFunction<_LevelInitNative>(_onLevelDeinit);

  init.userdata = nullptr;

  return 1;
}

typedef DartGDExtensionInterfaceObjectGetInstanceBindingFunction = GDExtensionInterfaceObjectGetInstanceBindingFunction;

// Wrapper class for Godot interface functions
class GodotInterface {
  // Common interface functions you'll need
  late final DartGDExtensionInterfaceVariantCallFunction? variantCall;
  late final DartGDExtensionInterfaceObjectMethodBindCallFunction? objectMethodBindCall;
  late final DartGDExtensionInterfaceClassdbGetMethodBindFunction? classdbGetMethodBind;
  late final DartGDExtensionInterfaceObjectGetInstanceBindingFunction? objectGetInstanceBinding;
  
  bool initialize() {
    if (_getProcAddressPtr == null) return false;
    
    // Get the interface functions and convert them to callable Dart functions
    final variantCallPtr = getInterfacePtr('variant_call');
    if (variantCallPtr != null) {
      variantCall = variantCallPtr.cast<NativeFunction<GDExtensionInterfaceVariantCallFunction>>().asFunction<DartGDExtensionInterfaceVariantCallFunction>();
    }
    
    final methodBindCallPtr = getInterfacePtr('object_method_bind_call');
    if (methodBindCallPtr != null) {
      objectMethodBindCall = methodBindCallPtr.cast<NativeFunction<GDExtensionInterfaceObjectMethodBindCallFunction>>().asFunction<DartGDExtensionInterfaceObjectMethodBindCallFunction>();
    }
    
    final getMethodBindPtr = getInterfacePtr('classdb_get_method_bind');
    if (getMethodBindPtr != null) {
      classdbGetMethodBind = getMethodBindPtr.cast<NativeFunction<GDExtensionInterfaceClassdbGetMethodBindFunction>>().asFunction<DartGDExtensionInterfaceClassdbGetMethodBindFunction>();
    }
    
    final getInstanceBindingPtr = getInterfacePtr('object_get_instance_binding');
    if (getInstanceBindingPtr != null) {
      objectGetInstanceBinding = getInstanceBindingPtr.cast<NativeFunction<GDExtensionInterfaceObjectGetInstanceBindingFunction>>().asFunction<DartGDExtensionInterfaceObjectGetInstanceBindingFunction>();
    }
    return variantCall != null && 
           objectMethodBindCall != null && 
           classdbGetMethodBind != null &&
           objectGetInstanceBinding != null;
  }
}

// Creates the Godot instance 
class GodotWrapper {
  // Futures that return to notify the rest of the program that the instance has been created
  final Completer<void> _ready = Completer<void>();
  Future<void> onReady() => _ready.future;

  late final LibGodotBindings bindings;
  GDExtensionObjectPtr? godotInstance;

  // These args are necessary for creating the instance because nullptr errors (I don't know their significance)
  late Pointer<Pointer<Char>> _argv;
  late Pointer<Utf8> _arg0;

  void _prepareArgv() {
    _arg0 = "flutter_godot".toNativeUtf8();
    _argv = calloc<Pointer<Char>>(1);
    _argv[0] = _arg0.cast<Char>();
  }

  final interface = GodotInterface();

  GodotWrapper() {
    // This is required because otherwise creating the instance conflicts with Flutter's build()
    // There is likely a better way to accomplish this but I don't fully understand Flutter's build cycle
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeGodot();
    });
  }

  Future<void> _initializeGodot() async {
    try {
      final initFuncPtr = Pointer.fromFunction<GDExtensionInitializationFunctionFunction>(onInit, 0);
      bindings = getGodotBindings();
      _prepareArgv();
      
      final instance = bindings.libgodot_create_godot_instance(
        1, // argc
        _argv,
        initFuncPtr,
      );
      
      if (instance == nullptr) {
        throw Exception('Failed to create Godot instance');
      }
      
      godotInstance = instance;
      
      // Initialize the interface after the instance is created
      if (!interface.initialize()) {
        throw Exception('Failed to initialize Godot interface');
      }
      
      _ready.complete();
    } catch (e) {
      _ready.completeError(e);
    }
  }

  // Method to call Godot functions
  Future<void> callGodotMethod(String className, String methodName, [List<dynamic>? args]) async {
    await onReady();
    
    if (godotInstance == nullptr || interface.classdbGetMethodBind == null) {
      throw Exception('Godot instance or interface not ready');
    }
    
    // Get method bind
    final classNamePtr = className.toNativeUtf8();
    final methodNamePtr = methodName.toNativeUtf8();
    
    final methodBind = interface.classdbGetMethodBind!(
      classNamePtr.cast<Char>() as GDExtensionConstStringNamePtr,
      methodNamePtr.cast<Char>() as GDExtensionConstStringNamePtr,
      0, // hash - can be 0 for most cases
    );
    
    calloc.free(classNamePtr);
    calloc.free(methodNamePtr);
    
    if (methodBind == nullptr) {
      throw Exception('Method $className::$methodName not found');
    }
    
    // Prepare arguments (this is simplified - you'll need proper variant conversion)
    final argCount = args?.length ?? 0;
    Pointer<Pointer<Void>>? argsPtr;
    
    if (argCount > 0) {
      argsPtr = calloc<Pointer<Void>>(argCount);
      // Convert Dart values to Godot variants (implementation needed)
      // This is complex and depends on the argument types
    }
    
    // Call the method
    Pointer<Void> returnValue = calloc<Uint8>(16) as Pointer<Void>; // Size for a variant
    
    if (interface.objectMethodBindCall != null) {
      interface.objectMethodBindCall!(
        methodBind,
        godotInstance!,
        argsPtr?.cast<Pointer<Pointer<Void>>>() as Pointer<GDExtensionConstVariantPtr>,
        argCount,
        returnValue,
        nullptr, // error pointer
      );
    }
    
    // Clean up
    if (argsPtr != nullptr) {
      calloc.free(argsPtr!);
    }
    calloc.free(returnValue);
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
