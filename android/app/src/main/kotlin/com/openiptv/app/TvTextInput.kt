package com.openiptv.app

import android.app.Activity
import android.content.Context
import android.text.Editable
import android.text.InputFilter
import android.text.InputType
import android.text.TextWatcher
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import android.widget.FrameLayout
import io.flutter.embedding.android.FlutterView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

// Typing on a TV goes through a real Android EditText. Google TV's keyboard
// (Gboard) won't take the remote's D-pad while a Flutter text field owns the
// input connection — every press falls through to the app behind it, which
// closed the keyboard on the first move (flutter/flutter#125541, #147772).
// A native EditText gets the keyboard working exactly as in any TV app.
//
// The EditText is invisible (1×1, transparent) and only carries the input:
// Dart opens it from a field's outline, and each change is mirrored into the
// Flutter TextField that the user actually sees. Closing it (Back, the
// keyboard's action key, or moving off with the D-pad once the keyboard is
// gone) gives Android focus back to the FlutterView.
//
// Channel `openiptv/tv_input`:
//   Dart -> native  open {text, type, obscure, suggestions, action, maxLength}, close
//   native -> Dart  changed {text}, action, closed {reason: back|up|down|action}
class TvTextInput(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "openiptv/tv_input")
    private var field: EditText? = null
    private var open = false
    private var mirroring = false

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "open" -> {
                open(
                    text = call.argument<String>("text") ?: "",
                    type = call.argument<String>("type") ?: "text",
                    obscure = call.argument<Boolean>("obscure") ?: false,
                    suggestions = call.argument<Boolean>("suggestions") ?: true,
                    action = call.argument<String>("action") ?: "done",
                    maxLength = call.argument<Int>("maxLength"),
                )
                result.success(null)
            }
            "close" -> {
                finish(null)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun open(
        text: String,
        type: String,
        obscure: Boolean,
        suggestions: Boolean,
        action: String,
        maxLength: Int?,
    ) {
        val et = field ?: create().also { field = it }
        et.filters = if (maxLength != null && maxLength > 0) {
            arrayOf(InputFilter.LengthFilter(maxLength))
        } else {
            arrayOf()
        }
        var inputType = when (type) {
            "number" -> InputType.TYPE_CLASS_NUMBER
            "url" -> InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_URI
            "email" -> InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS
            else -> InputType.TYPE_CLASS_TEXT
        }
        if (obscure) {
            inputType = if (type == "number") {
                inputType or InputType.TYPE_NUMBER_VARIATION_PASSWORD
            } else {
                InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
            }
        } else if (!suggestions && inputType and InputType.TYPE_MASK_CLASS == InputType.TYPE_CLASS_TEXT) {
            inputType = inputType or InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS
        }
        et.inputType = inputType
        et.imeOptions = when (action) {
            "search" -> EditorInfo.IME_ACTION_SEARCH
            "next" -> EditorInfo.IME_ACTION_NEXT
            "go" -> EditorInfo.IME_ACTION_GO
            else -> EditorInfo.IME_ACTION_DONE
        } or EditorInfo.IME_FLAG_NO_FULLSCREEN or EditorInfo.IME_FLAG_NO_EXTRACT_UI
        // Gboard on TV: Up from the keyboard's top row comes back to the app
        // (handled in onKeyDown below) instead of doing nothing.
        et.privateImeOptions = "escapeNorth"

        mirroring = true
        et.setText(text)
        et.setSelection(text.length)
        mirroring = false

        open = true
        et.requestFocus()
        imm().restartInput(et)
        et.post { if (open) imm().showSoftInput(et, InputMethodManager.SHOW_IMPLICIT) }
    }

    private fun create(): EditText {
        val et = object : EditText(activity) {
            // Before the keyboard sees it: Back closes the keyboard *and*
            // hands the remote back, in one press — and never reaches the
            // app's own Back handling.
            override fun onKeyPreIme(keyCode: Int, event: KeyEvent): Boolean {
                if (open && keyCode == KeyEvent.KEYCODE_BACK) {
                    if (event.action == KeyEvent.ACTION_UP) finish("back")
                    return true
                }
                return super.onKeyPreIme(keyCode, event)
            }

            // Only reached when the keyboard passes a key on (it's closed, or
            // Up escaped its top row): Up/Down leave the field.
            override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
                if (open) {
                    when (keyCode) {
                        KeyEvent.KEYCODE_DPAD_UP -> { finish("up"); return true }
                        KeyEvent.KEYCODE_DPAD_DOWN -> { finish("down"); return true }
                    }
                }
                return super.onKeyDown(keyCode, event)
            }
        }
        et.alpha = 0f
        et.isFocusable = true
        et.isFocusableInTouchMode = true
        et.setSingleLine(true)
        et.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            override fun afterTextChanged(s: Editable?) {
                if (!mirroring && open) {
                    channel.invokeMethod("changed", mapOf("text" to (s?.toString() ?: "")))
                }
            }
        })
        et.setOnEditorActionListener { _, _, _ ->
            if (open) {
                channel.invokeMethod("action", null)
                finish("action")
            }
            true
        }
        et.setOnFocusChangeListener { _, hasFocus ->
            // Focus taken some other way (a dialog, the activity pausing).
            if (!hasFocus && open) finish("blur")
        }
        content().addView(et, FrameLayout.LayoutParams(1, 1))
        return et
    }

    private fun finish(reason: String?) {
        val et = field ?: return
        if (!open) return
        open = false
        imm().hideSoftInputFromWindow(et.windowToken, 0)
        et.clearFocus()
        flutterView()?.requestFocus()
        if (reason != null) channel.invokeMethod("closed", mapOf("reason" to reason))
    }

    private fun content(): ViewGroup = activity.findViewById(android.R.id.content)

    private fun flutterView(): View? {
        val root = content()
        for (i in 0 until root.childCount) {
            val child = root.getChildAt(i)
            if (child is FlutterView) return child
        }
        return null
    }

    private fun imm() =
        activity.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
}
