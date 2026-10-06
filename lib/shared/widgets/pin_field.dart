import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';
import 'package:open_iptv/ui/platform_helper.dart';

/// PINs are 4–8 digits everywhere (profile PINs, the admin PIN).
const kPinMinLength = 4;
const kPinMaxLength = 8;

/// PIN entry using the system number keyboard — never an app-drawn keypad.
/// Autofocuses so the keyboard opens straight away; digits are masked.
///
/// A TextField swallows the D-pad's up/down for its own caret handling, so
/// on a TV remote Down would never leave it; this field hands Down to the
/// directional focus system to reach the buttons below.
class PinField extends StatefulWidget {
  const PinField({
    super.key,
    required this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = true,
    this.errorText,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final String? errorText;

  @override
  State<PinField> createState() => _PinFieldState();
}

class _PinFieldState extends State<PinField> {
  FocusNode? _ownNode;
  FocusNode get _node => widget.focusNode ?? (_ownNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _node.onKeyEvent = (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.arrowDown &&
          node.focusInDirection(TraversalDirection.down)) {
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
  }

  @override
  void dispose() {
    _ownNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tv = PlatformHelper.isTV(context);
    // TV: the outline is the stop and typing goes through the native
    // keyboard bridge (see TvTextFieldGate) — Google TV's keyboard can't be
    // driven by the remote in a Flutter field. Autofocus opens it at once.
    return TvTextFieldGate(
      focusNode: _node,
      borderRadius: BorderRadius.circular(16),
      openOnShow: widget.autofocus,
      builder: (context, fieldNode) => TextField(
        controller: widget.controller,
        focusNode: fieldNode,
        autofocus: widget.autofocus && !tv,
        obscureText: true,
        obscuringCharacter: '●',
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(kPinMaxLength),
        ],
        textAlign: TextAlign.center,
        style: theme.textTheme.headlineSmall!.copyWith(letterSpacing: 10),
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        decoration: InputDecoration(
          errorText: widget.errorText,
          counterText: '',
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                BorderSide(color: theme.colorScheme.primary, width: 2),
          ),
        ),
      ),
    );
  }
}

/// Asks for a PIN in a dialog with the system number keyboard. Returns the
/// digits entered, or null if cancelled.
Future<String?> showPinEntryDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Unlock',
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PinDialog(
        title: title, message: message, confirmLabel: confirmLabel),
  );
}

class _PinDialog extends StatefulWidget {
  const _PinDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
  });

  final String title;
  final String? message;
  final String confirmLabel;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _valid => _controller.text.length >= kPinMinLength;

  void _submit() {
    if (_valid) Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        // Scrolls when the TV keyboard leaves little room; the PIN box sits
        // high enough to stay in view.
        child: SingleChildScrollView(
          child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_rounded,
                    size: 28, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 16),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium!
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              if (widget.message != null) ...[
                const SizedBox(height: 6),
                Text(
                  widget.message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall!
                      .copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 20),
              PinField(
                controller: _controller,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TvActivatable(
                    onTap: () => Navigator.of(context).pop(),
                    builder: (onTap) => TextButton(
                        onPressed: onTap, child: const Text('Cancel')),
                  ),
                  const SizedBox(width: 8),
                  TvActivatable(
                    onTap: _valid ? _submit : null,
                    builder: (onTap) => FilledButton(
                      style:
                          FilledButton.styleFrom(shape: const StadiumBorder()),
                      onPressed: onTap,
                      child: Text(widget.confirmLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
