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

  /// Fixed 4-byte little-endian uint (compact-encoding `uint32`), used by
  /// bare-rpc for the leading frame length.
  void uint32(int n) => _le(n, 4);

  /// Boolean encoded as a single `uint` (0/1).
  void boolean(bool b) => uint(b ? 1 : 0);

  /// Length-prefixed byte buffer (`uint` length + raw bytes), i.e. `c.buffer`.
  void buffer(Uint8List b) {
    uint(b.length);
    _b.add(b);
  }

  /// `c.frame(enc)`: a length-prefixed sub-message. [build] writes the inner
  /// message into a fresh encoder; we then emit `uint(innerLen) + innerBytes`.
  /// WDK's manager schema wraps every nested object (`options`, `config`,
  /// `paymasterToken`) in a frame.
  void frame(void Function(CompactEncoder inner) build) {
    final CompactEncoder inner = CompactEncoder();
    build(inner);
    buffer(inner.takeBytes());
  }

  /// Signed zig-zag varint (compact-encoding `int`).
  void intZigzag(int n) => uint(n < 0 ? (-n * 2 - 1) : n * 2);

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

  /// Fixed 4-byte little-endian uint.
  int uint32() => _le(4);

  /// Boolean (non-zero `uint`).
  bool boolean() => uint() != 0;

  /// Reads [n] raw bytes.
  Uint8List bytes(int n) {
    final Uint8List out = _bytes.sublist(_offset, _offset + n);
    _offset += n;
    return out;
  }

  /// Length-prefixed byte buffer (`c.buffer`).
  Uint8List readBuffer() => bytes(uint());

  /// `c.frame` reader: reads the length-prefixed sub-message and hands a
  /// decoder positioned over exactly those bytes to [read].
  T readFrame<T>(T Function(CompactDecoder inner) read) =>
      read(CompactDecoder(readBuffer()));

  /// Signed zig-zag varint (compact-encoding `int`).
  int intZigzag() {
    final int u = uint();
    return (u & 1) != 0 ? -((u + 1) >> 1) : (u >> 1);
  }

  int _le(int byteCount) {
    int n = 0;
    for (int i = 0; i < byteCount; i++) {
      n |= _bytes[_offset++] << (8 * i);
    }
    return n;
  }
}
