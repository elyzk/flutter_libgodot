import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_libgodot/godot/interface.dart';
import 'package:flutter_libgodot/godot/wrapper.dart';
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

      // Then try to start/control the instance
      Future.delayed(Duration(milliseconds: 500), () {
        godot.startGodot();
      });
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Text(init ? "Initialized successfully" : "Initializing...");
  }
}
