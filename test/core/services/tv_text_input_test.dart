import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/services/tv_text_input.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('openiptv/tv_input');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });
  tearDown(() async {
    await TvTextInput.close();
    messenger.setMockMethodCallHandler(channel, null);
  });

  // Native -> Dart, as TvTextInput.kt sends it.
  Future<void> fromNative(String method, [Object? args]) =>
      messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(MethodCall(method, args)),
        (_) {},
      );

  test('opens the native box with the field\'s text and settings', () async {
    final controller = TextEditingController(text: 'news');
    await TvTextInput.open(
      controller: controller,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.next,
      obscureText: false,
    );
    expect(calls.single.method, 'open');
    expect(calls.single.arguments, {
      'text': 'news',
      'type': 'url',
      'obscure': false,
      'suggestions': true,
      'action': 'next',
      'maxLength': null,
    });
  });

  test('passwords never get suggestions; number and search map through',
      () async {
    await TvTextInput.open(
      controller: TextEditingController(),
      keyboardType: TextInputType.number,
      obscureText: true,
      textInputAction: TextInputAction.search,
      maxLength: 8,
    );
    final args = calls.single.arguments as Map;
    expect(args['maxLength'], 8);
    expect(args['type'], 'number');
    expect(args['obscure'], true);
    expect(args['suggestions'], false);
    expect(args['action'], 'search');
  });

  test('typing is mirrored into the controller and onChanged', () async {
    final controller = TextEditingController();
    final changes = <String>[];
    await TvTextInput.open(controller: controller, onChanged: changes.add);

    await fromNative('changed', {'text': 'ki'});
    await fromNative('changed', {'text': 'kid'});

    expect(controller.text, 'kid');
    expect(controller.selection, const TextSelection.collapsed(offset: 3));
    expect(changes, ['ki', 'kid']);
  });

  test('the keyboard action and closing reach the field once', () async {
    var actions = 0;
    final closes = <TvTextInputClose>[];
    await TvTextInput.open(
      controller: TextEditingController(),
      onAction: () => actions++,
      onClosed: closes.add,
    );

    await fromNative('action');
    await fromNative('closed', {'reason': 'action'});
    expect(actions, 1);
    expect(closes, [TvTextInputClose.action]);
    expect(TvTextInput.isOpen, isFalse);

    // Nothing is open any more: late messages are ignored.
    await fromNative('changed', {'text': 'x'});
    await fromNative('closed', {'reason': 'back'});
    expect(closes, [TvTextInputClose.action]);
  });

  test('opening another field closes the first one', () async {
    final first = <TvTextInputClose>[];
    final firstController = TextEditingController();
    await TvTextInput.open(controller: firstController, onClosed: first.add);
    final second = TextEditingController();
    await TvTextInput.open(controller: second);

    expect(first, [TvTextInputClose.blur]);
    await fromNative('changed', {'text': 'abc'});
    expect(second.text, 'abc');
    expect(firstController.text, isEmpty);
  });

  test('back / up / down reasons are reported', () async {
    for (final reason in ['back', 'up', 'down']) {
      final closes = <TvTextInputClose>[];
      await TvTextInput.open(
          controller: TextEditingController(), onClosed: closes.add);
      await fromNative('closed', {'reason': reason});
      expect(closes.single.name, reason);
    }
  });
}
