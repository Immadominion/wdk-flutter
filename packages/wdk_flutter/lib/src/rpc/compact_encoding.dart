import 'dart:convert';
import 'dart:typed_data';

/// A minimal Dart port of Holepunch's `compact-encoding` — the binary codec
/// underneath WDK's HRPC. Only the primitives the WDK message schemas use
/// (`uint` varint, `string`) are implemented. Byte-for-byte compatible with the
/// JS encoder (verified by `tools/parity/oracle.mjs` vectors).
///
/// uint varint format (little-endian):
///   n < 0xfd            → 1 byte
///   n <= 0xffff         → 0xfd + uint16
///   n <= 0xffffffff     → 0xfe + uint32
///   else                → 0xff + uint64
class CompactEncoder {
  final BytesBuilder _b = BytesBuilder();

  void uint(int n) {
    if (n < 0xfd) {
      _b.addByte(n);
    } else if (n <= 0xffff) {
      _b.addByte(0xfd);
      _le(n, 2);
    } else if (n <= 0xffffffff) {
      _b.addByte(0xfe);
      _le(n, 4);
    } else {
      _b.addByte(0xff);
      _le(n, 8);
    }
  }

  void string(String s) {
    final List<int> bytes = utf8.encode(s);
    uint(bytes.length);
    _b.add(bytes);
  }

  void _le(int n, int byteCount) {
    for (int i = 0; i < byteCount; i++) {
      _b.addByte((n >> (8 * i)) & 0xff);
    }
  }

  Uint8List takeBytes() => _b.toBytes();
}

/// Reader counterpart to [CompactEncoder].
class CompactDecoder {
  CompactDecoder(this._bytes);
  final Uint8List _bytes;
  int _offset = 0;

  bool get hasMore => _offset < _bytes.length;

  int uint() {
    final int first = _bytes[_offset++];
    if (first < 0xfd) return first;
    if (first == 0xfd) return _le(2);
    if (first == 0xfe) return _le(4);
    return _le(8);
  }

  String string() {
    final int len = uint();
    final String s = utf8.decode(_bytes.sublist(_offset, _offset + len));
    _offset += len;
    return s;
  }

  int _le(int byteCount) {
    int n = 0;
    for (int i = 0; i < byteCount; i++) {
      n |= _bytes[_offset++] << (8 * i);
    }
    return n;
  }
}
