import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/models/programme.dart';
import 'package:open_iptv/core/parsers/xmltv_parser.dart';

String stamp(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  final u = t.toUtc();
  return '${u.year}${two(u.month)}${two(u.day)}${two(u.hour)}${two(u.minute)}${two(u.second)} +0000';
}

void main() {
  final now = DateTime.now();
  String prog(String attrs, String title, {String extra = ''}) {
    final s = now.add(const Duration(hours: 1));
    return '<programme start="${stamp(s)}" stop="${stamp(s.add(const Duration(hours: 1)))}" $attrs>'
        '<title lang="en">$title</title>$extra</programme>\n';
  }

  final xml = StringBuffer('<?xml version="1.0"?><tv>')
    ..write('<channel id="A"><display-name>A</display-name></channel>')
    ..write(prog('channel="A"', 'a one', extra: '<desc>mentions &lt;programme channel="B"&gt; text</desc>'))
    ..write(prog('channel="B"', 'b one'))
    ..write(prog("channel='A'", 'a single-quoted'))
    ..write(prog('channel="R&amp;D"', 'amp id'))
    ..write('<programme channel="A" start="${stamp(now.add(const Duration(hours: 3)))}" stop="${stamp(now.add(const Duration(hours: 4)))}"><title>a attrs reordered</title></programme>\n')
    ..write(prog('channel="C"', 'c one'))
    ..write(prog('channel="A"', 'a after'))
    ..write('</tv>');
  final text = xml.toString();

  Future<List<Programme>> run(Stream<String> s, Set<String>? only) =>
      XmltvParser.parse(s, onlyChannels: only).toList();

  Stream<String> chunked(int size) async* {
    for (var i = 0; i < text.length; i += size) {
      yield text.substring(i, (i + size).clamp(0, text.length));
    }
  }

  test('keeps exactly the wanted channels, however the tag is written',
      () async {
    final got = await run(Stream.value(text), {'A', 'R&D'});
    expect(got.map((p) => p.title), [
      'a one',
      'a single-quoted',
      'amp id',
      'a attrs reordered',
      'a after',
    ]);
    expect(got.map((p) => p.channelId).toSet(), {'A', 'R&D'});
  });

  test('a description that mentions a programme tag is not mistaken for one',
      () async {
    final got = await run(Stream.value(text), {'B'});
    expect(got.map((p) => p.title), ['b one']);
  });

  test('gives the same answer for every chunk size, even one character',
      () async {
    final whole = await run(Stream.value(text), {'A', 'C', 'R&D'});
    for (final size in [1, 2, 3, 7, 16, 64, 255, 1000]) {
      final got = await run(chunked(size), {'A', 'C', 'R&D'});
      expect(got.map((p) => '${p.channelId}/${p.title}'),
          whole.map((p) => '${p.channelId}/${p.title}'),
          reason: 'chunk size $size');
    }
  });

  test('agrees with the full parser followed by a filter', () async {
    final all = await run(Stream.value(text), null);
    final want = {'A', 'B'};
    final filtered = await run(Stream.value(text), want);
    expect(filtered.map((p) => p.title),
        all.where((p) => want.contains(p.channelId)).map((p) => p.title));
  });

  test('nothing wanted, or nothing found, is simply empty', () async {
    expect(await run(Stream.value(text), {'nope'}), isEmpty);
    expect(await run(Stream.value(text), <String>{}), isEmpty);
    expect(await run(Stream.value('<tv></tv>'), {'A'}), isEmpty);
  });

  test('many batches in a long feed', () async {
    final b = StringBuffer('<tv>');
    for (var i = 0; i < 4000; i++) {
      b.write(prog('channel="X${i % 3}"', 'show $i',
          extra: '<desc>${'long description ' * 20}</desc>'));
    }
    b.write('</tv>');
    final got = await run(Stream.value(b.toString()), {'X1'});
    // i % 3 == 1 for i in 0..3999: 1333 of them.
    expect(got.length, 1333);
  });

  test('the channel list rides along with a full parse', () async {
    final seen = <String, String>{};
    final got = await XmltvParser.parse(
      Stream.value(
          '<tv><channel id="X"><display-name>First</display-name><display-name>Second</display-name></channel>'
          '<channel id="Y"></channel>${prog('channel="X"', 'x show')}</tv>'),
      onChannel: (id, name) => seen[id] = name,
    ).toList();
    expect(seen, {'X': 'First', 'Y': ''});
    expect(got.single.title, 'x show');
  });
}
