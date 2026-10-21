/* Incremental SHA-256, using 64-byte blocks. The browser's digest() API
 * requires a whole ArrayBuffer; this keeps large skin ZIPs out of JS memory.
 * Checked against Web Crypto / Node crypto for boundary and chunked inputs. */
class Hash256 {
  constructor() {
    this.h = new Uint32Array([0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
      0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]);
    this.buffer = new Uint8Array(64); this.words = new Uint32Array(64);
    this.used = 0; this.bytes = 0;
  }
  update(input) {
    this.bytes += input.length;
    let offset = 0;
    while (offset < input.length) {
      const count = Math.min(64 - this.used, input.length - offset);
      this.buffer.set(input.subarray(offset, offset + count), this.used);
      this.used += count; offset += count;
      if (this.used === 64) { this.block(); this.used = 0; }
    }
  }
  block() {
    const r = (x, n) => (x >>> n) | (x << (32 - n));
    const w = this.words, view = new DataView(this.buffer.buffer);
    for (let i = 0; i < 16; i++) w[i] = view.getUint32(i * 4);
    for (let i = 16; i < 64; i++) {
      const a = w[i - 15], b = w[i - 2];
      w[i] = w[i - 16] + (r(a, 7) ^ r(a, 18) ^ (a >>> 3)) + w[i - 7] + (r(b, 17) ^ r(b, 19) ^ (b >>> 10));
    }
    let [a, b, c, d, e, f, g, h] = this.h;
    for (let i = 0; i < 64; i++) {
      const t1 = (h + (r(e, 6) ^ r(e, 11) ^ r(e, 25)) + ((e & f) ^ (~e & g)) + Hash256.K[i] + w[i]) >>> 0;
      const t2 = ((r(a, 2) ^ r(a, 13) ^ r(a, 22)) + ((a & b) ^ (a & c) ^ (b & c))) >>> 0;
      h = g; g = f; f = e; e = (d + t1) >>> 0; d = c; c = b; b = a; a = (t1 + t2) >>> 0;
    }
    [a, b, c, d, e, f, g, h].forEach((value, i) => { this.h[i] += value; });
  }
  hex() {
    const size = this.used < 56 ? 64 - this.used : 128 - this.used;
    const tail = new Uint8Array(size), view = new DataView(tail.buffer);
    tail[0] = 0x80;
    view.setUint32(size - 8, Math.floor(this.bytes / 0x20000000));
    view.setUint32(size - 4, (this.bytes * 8) >>> 0);
    this.update(tail);
    return [...this.h].map(word => word.toString(16).padStart(8, '0')).join('');
  }
}
Hash256.K = new Uint32Array([
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
]);
