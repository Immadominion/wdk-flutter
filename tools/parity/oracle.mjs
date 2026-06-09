import { createRequire } from 'module'
import { writeFileSync } from 'fs'
const require = createRequire(import.meta.url)
const { c } = require('hyperschema/runtime')
const { getEncoding } = require('./sm-messages.js')

const SM = '@tetherto/wdk-secret-manager'
const cases = [
  [`${SM}/command-workletStart-request`, { enableDebugLogs: 0 }],
  [`${SM}/command-workletStart-request`, { enableDebugLogs: 1 }],
  [`${SM}/command-workletStart-request`, { enableDebugLogs: 5 }],
  [`${SM}/command-workletStart-response`, { status: 'started' }],
  [`${SM}/command-workletStart-response`, {}],
  [`${SM}/command-workletStop-request`, {}],
  [`${SM}/command-workletStop-request`, { payload: 'stop' }],
  [`${SM}/command-generateAndEncrypt-request`, { passkey: 'pk', salt: 'abcd' }],
  [`${SM}/command-generateAndEncrypt-request`, { passkey: 'p', salt: 's', seedPhrase: 'word word' }],
  [`${SM}/command-generateAndEncrypt-request`, { passkey: 'p', salt: 's', seedPhrase: 'x', derivedKey: 'dk' }],
  [`${SM}/command-generateAndEncrypt-request`, {}],
  [`${SM}/command-generateAndEncrypt-response`, { encryptedEntropy: 'deadbeef', encryptedSeed: 'cafe' }],
  [`${SM}/command-decrypt-request`, { passkey: 'p', salt: 's', encryptedData: '00ff' }],
  [`${SM}/command-decrypt-request`, { passkey: 'p', salt: 's', encryptedData: 'aa', derivedKey: 'k' }],
  [`${SM}/command-decrypt-response`, { result: '00112233aabb' }],
  [`${SM}/command-log-request`, { type: 2, data: 'oops' }],
  // edge cases: multi-byte varint length (300-char string) + unicode
  [`${SM}/command-decrypt-response`, { result: 'a'.repeat(300) }],
  [`${SM}/command-log-request`, { type: 1, data: 'héllo 🌍' }],
]

const out = cases.map(([enc, value]) => {
  const buf = Buffer.from(c.encode(getEncoding(enc), value))
  const decoded = c.decode(getEncoding(enc), buf)
  return { enc, value, hex: buf.toString('hex'), decoded }
})
const dest = '/Users/mac/Documents/codes/opensauce/wdk/wdk-starter-flutter/tools/parity/secret_manager_vectors.json'
writeFileSync(dest, JSON.stringify(out, null, 2))
console.log(`wrote ${out.length} vectors -> ${dest}`)
for (const v of out.slice(0, 6)) console.log(' ', v.enc.split('/').pop().padEnd(34), v.hex)
