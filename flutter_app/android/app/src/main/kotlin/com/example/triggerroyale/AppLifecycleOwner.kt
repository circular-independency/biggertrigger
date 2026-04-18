package com.example.triggerroyale

import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry

/**
 * Simple lifecycle owner kept permanently in the RESUMED state.
 *
 * This is used for CameraX when the plugin is initialized from an application context and there is
 * no attached Android activity lifecycle available.
 */
object AppLifecycleOwner : LifecycleOwner {
    private val lifecycleRegistry = LifecycleRegistry(this).apply {
        currentState = Lifecycle.State.CREATED
        currentState = Lifecycle.State.STARTED
        currentState = Lifecycle.State.RESUMED
    }

    override val lifecycle: Lifecycle
        get() = lifecycleRegistry
}
