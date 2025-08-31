import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_libgodot/godot/interface.dart';
import '../src/bindings.dart';

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

  // Helper method to create a Godot StringName
  Pointer<Void>? createStringName(String text) {
    if (interface.stringNameNewWithUtf8Chars == null) {
      print('StringName creation function not available');
      return null;
    }

    print("StringName creation function available");
    
    // Allocate memory for a StringName (typically 8 bytes on 64-bit)
    final stringName = calloc<Uint64>(16);
    final textUtf8 = text.toNativeUtf8();
    
    try {
      interface.stringNameNewWithUtf8Chars!(
        stringName.cast<Void>(),
        textUtf8.cast<Char>(),
      );
      
      return stringName.cast<Void>();
    } catch (e) {
      print('Error creating StringName: $e');
      calloc.free(stringName);
      return null;
    } finally {
      calloc.free(textUtf8);
    }
  }

  // Helper method to destroy a StringName
  void destroyStringName(Pointer<Void> stringName) {
    if (interface.stringNameDestroy != null) {
      interface.stringNameDestroy!(stringName);
    }
    calloc.free(stringName);
  }

  // Simplified method to call basic methods on the Godot instance
  // For now, just test if we can get method binds without crashing
  Future<bool> testMethodExists(String className, String methodName) async {
    await onReady();
    
    if (godotInstance == nullptr || interface.classdbGetMethodBind == null) {
      return false;
    }
    print("Class name: $className");
    print("Method name: $methodName");
    
    // Not sure what the purpose of this is, and it errors right now
    // Create StringNames for the class and method
    final classNameSN = createStringName(className);
    final methodNameSN = createStringName(methodName);
    
    if (classNameSN == null || methodNameSN == null) {
      print('Failed to create StringNames');
      if (classNameSN != null) destroyStringName(classNameSN);
      if (methodNameSN != null) destroyStringName(methodNameSN);
      return false;
    }
    
    bool found = false;
    
    try {
      final methodBind = interface.classdbGetMethodBind!(
        classNameSN.cast<Char>() as GDExtensionStringNamePtr,
        methodNameSN.cast<Char>() as GDExtensionStringNamePtr,
        0,
      );
      
      found = methodBind != nullptr;
      print('Method $className::$methodName ${found ? 'found' : 'not found'}');
      
    } catch (e) {
      print('Error checking method $className::$methodName: $e');
    } finally {
      destroyStringName(classNameSN);
      destroyStringName(methodNameSN);
    }
    
    return found;
  }
  
  // Test what type of object the Godot instance is
  Future<void> inspectInstance() async {
    await onReady();
    
    if (godotInstance == nullptr) {
      print('Godot instance is null');
      return;
    }
    
    print('=== Inspecting Godot Instance ===');
    
    // Test various class/method combinations to understand the instance
    final instanceNames = ['GodotInstance', 'start'];

    await testMethodExists(instanceNames[0], instanceNames[1]);
    
    print('=== Inspection Complete ===');
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

  // Method to call methods directly on the Godot instance object
  Future<void> callInstanceMethod(String methodName, [List<dynamic>? args]) async {
    await onReady();
    
    if (godotInstance == nullptr || interface.objectMethodBindCall == null || interface.classdbGetMethodBind == null) {
      throw Exception('Godot instance or interface not ready');
    }
    
    final methodNamePtr = methodName.toNativeUtf8();

    final className = 'GodotInstance';
    GDExtensionMethodBindPtr? methodBind;
    String? foundClassName;

    // Allocate space for two StringName objects
    final classNameSN = calloc<Uint8>(16); // safer: actual struct size
    final methodNameSN = calloc<Uint8>(16);

    try {
      final classNameUtf8 = className.toNativeUtf8();
      final methodNameUtf8 = methodName.toNativeUtf8();

      try {
        interface.stringNameNewWithUtf8Chars!(
          classNameSN.cast<Void>(),
          classNameUtf8.cast<Char>(),
        );

        interface.stringNameNewWithUtf8Chars!(
          methodNameSN.cast<Void>(),
          methodNameUtf8.cast<Char>(),
        );
      } finally {
        calloc.free(classNameUtf8);
        calloc.free(methodNameUtf8);
      }
      
      final classNamePtr = className.toNativeUtf8();
      try {
        final bind = interface.classdbGetMethodBind!(
          classNameSN.cast<Void>(),
          methodNameSN.cast<Void>(),
          0,
        );
        
        if (bind != nullptr) {
          methodBind = bind;
          foundClassName = className;
          print("Found class name: $className");
        }
      } finally {
        calloc.free(classNamePtr);
      }
      
      if (methodBind == nullptr) {
        throw Exception('Method $methodName not found in any expected class');
      }
      
      print('Found method $methodName in class $foundClassName');
      
      // Prepare arguments - for now, assume no arguments
      final argCount = args?.length ?? 0;
      
      // Prepare return value space (Godot variants are typically 24 bytes)
      final returnValue = calloc<Uint8>(24);
      final callError = calloc<GDExtensionCallError>();
      
      try {
        // Call the method on the instance
        interface.objectMethodBindCall!(
          methodBind!,
          godotInstance!, // This is our Godot instance
          nullptr, // No arguments for now
          argCount,
          returnValue.cast<Void>(),
          callError,
        );
        
        // Check for call errors
        final error = callError.ref;
        if (error.error != 0) { // Assuming 0 means no error
          print('Call error: ${error.error}');
        } else {
          print('Successfully called $methodName on Godot instance');
        }
        
      } finally {
        calloc.free(returnValue);
        calloc.free(callError);
      }
      
    } finally {
      calloc.free(methodNamePtr);
    }
  }

  // Specific methods for Godot instance control
  Future<void> startGodot() async {
    try {
      await callInstanceMethod('start');
    } catch (e) {
      print('Error starting Godot: $e');
      // Try alternative method names
      try {
        await callInstanceMethod('_ready');
      } catch (e2) {
        print('Error with _ready: $e2');
      }
    }
  }
}