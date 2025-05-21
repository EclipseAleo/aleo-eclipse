export function addressToField(address: string): string {
  const alphabet = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';
  const sep = address.lastIndexOf('1');
  if (sep === -1) throw new Error('Invalid bech32 address');
  const words: number[] = [];
  for (let i = sep + 1; i < address.length; i++) {
    const c = address[i];
    const val = alphabet.indexOf(c);
    if (val === -1) throw new Error('Invalid character in address');
    words.push(val);
  }
  // drop checksum (last 6 words)
  const dataWords = words.slice(0, -6);
  // convert from 5-bit groups to bytes
  let bits = 0;
  let value = 0;
  const bytes: number[] = [];
  for (const w of dataWords) {
    value = (value << 5) | w;
    bits += 5;
    if (bits >= 8) {
      bits -= 8;
      bytes.push((value >> bits) & 0xff);
    }
  }
  if (bits > 0) {
    bytes.push((value << (8 - bits)) & 0xff);
  }
  // trim to 32 bytes if an extra zero byte is present
  if (bytes.length > 32 && bytes[bytes.length - 1] === 0) {
    bytes.pop();
  }
  const hex = Buffer.from(bytes).toString('hex');
  const field = BigInt('0x' + hex).toString() + 'field';
  return field;
}

if (require.main === module) {
  const addr = process.argv[2];
  if (!addr) {
    console.error('Usage: node addressToField.js <aleo-address>');
    process.exit(1);
  }
  console.log(addressToField(addr));
}
