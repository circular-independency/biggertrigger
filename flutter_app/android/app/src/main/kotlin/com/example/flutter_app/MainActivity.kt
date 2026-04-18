package com.example.flutter_app

import com.example.triggerroyale.VisionFlutterPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        VisionFlutterPlugin.registerWith(flutterEngine)
    }
}
