import { createRequire } from 'module'
import { writeFileSync } from 'fs'
const require = createRequire(import.meta.url)
const c = require('compact-encoding')
const b4a = require('b4a')
const m = require('bare-rpc/messages')
const { type: T } = require('bare-rpc/constants')
const { c: hc } = require('hyperschema/runtime')
const { getEncoding } = require('./wdk-core-messages.js')

// The manager worklet protocol is `@wdk-core` (pear-wrk-wdk@1.0.0-beta.4).
const N = '@wdk-core'
const hex = (u) => Buffer.from(u).toString('hex')
const body = (enc, v) => Buffer.from(hc.encode(getEncoding(enc), v))

// ---- message-body vectors --------------------------------------------------
const cases = [
  // log (send-only) + lifecycle
  [`${N}/log-request`, { type: 2, data: 'boom' }],
  [`${N}/log-request`, {}],
  [`${N}/workletStart-request`, { enableDebugLogs: 0, seedPhrase: 'abandon ability', config: '{"a":1}' }],
  [`${N}/workletStart-request`, { enableDebugLogs: 1, config: '{}' }],
  [`${N}/workletStart-response`, { status: 'started' }],
  [`${N}/workletStart-response`, {}],
  [`${N}/dispose-request`, {}],
  // addresses (no-flags requests, flagged responses)
  [`${N}/getAddress-request`, { network: 'bitcoin', accountIndex: 0 }],
  [`${N}/getAddress-request`, { network: 'ethereum', accountIndex: 3 }],
  [`${N}/getAddress-response`, { address: 'bc1qxyz' }],
  [`${N}/getAddress-response`, {}],
  [`${N}/getAddressBalance-request`, { network: 'bitcoin', accountIndex: 0 }],
  [`${N}/getAddressBalance-response`, { balance: '123456' }],
  [`${N}/getAbstractedAddress-request`, { network: 'ethereum', accountIndex: 0 }],
  [`${N}/getAbstractedAddress-response`, { address: '0xabc123' }],
  [`${N}/getAbstractedAddressBalance-request`, { network: 'ethereum', accountIndex: 1 }],
  [`${N}/getAbstractedAddressBalance-response`, { balance: '999' }],
  [`${N}/getAbstractedAddressTokenBalance-request`, { network: 'ethereum', accountIndex: 0, tokenAddress: '0xdAC17F958D2ee523a2206206994597C13D831ec7' }],
  [`${N}/getAbstractedAddressTokenBalance-response`, { balance: '42' }],
  // bitcoin quote/send (framed options)
  [`${N}/quoteSendTransaction-request`, { network: 'bitcoin', accountIndex: 0, options: { to: 'bc1qrecipient', value: '1000' } }],
  [`${N}/quoteSendTransaction-response`, { fee: '250' }],
  [`${N}/sendTransaction-request`, { network: 'bitcoin', accountIndex: 0, options: { to: 'bc1qrecipient', value: '5000' } }],
  [`${N}/sendTransaction-response`, { fee: '250', hash: '0xdeadbeef' }],
  [`${N}/sendTransaction-response`, { hash: '0xonlyhash' }],
  // abstracted transfer (framed options + config-flag-after-options + nested framed config)
  [`${N}/abstractedAccountTransfer-request`, { network: 'ethereum', accountIndex: 0, options: { token: '0xToken', recipient: '0xRecipient', amount: '1000000' }, config: { paymasterToken: { address: '0xPaymaster' } } }],
  [`${N}/abstractedAccountTransfer-request`, { network: 'ethereum', accountIndex: 2, options: { token: '0xToken', recipient: '0xRecipient', amount: '5' } }],
  [`${N}/abstractedAccountTransfer-response`, { hash: '0xhash', fee: '9' }],
  [`${N}/abstractedAccountQuoteTransfer-request`, { network: 'polygon', accountIndex: 1, options: { token: '0xT', recipient: '0xR', amount: '250000' }, config: { paymasterToken: { address: '0xP' } } }],
  [`${N}/abstractedAccountQuoteTransfer-response`, { fee: '7' }],
  // approve + abstracted send (options is a plain JSON string here)
  [`${N}/getApproveTransaction-request`, { token: '0xToken', recipient: '0xRecipient', amount: '1000000' }],
  [`${N}/getApproveTransaction-response`, { to: '0xto', value: '0', data: '0xcalldata' }],
  [`${N}/abstractedSendTransaction-request`, { network: 'ethereum', accountIndex: 0, options: '{"to":"0x1","data":"0x2"}', config: { paymasterToken: { address: '0xP' } } }],
  [`${N}/abstractedSendTransaction-request`, { network: 'arbitrum', accountIndex: 0, options: '{"to":"0x1"}' }],
  [`${N}/abstractedSendTransaction-response`, { hash: '0xh', fee: '3' }],
  [`${N}/getTransactionReceipt-request`, { network: 'ethereum', accountIndex: 0, hash: '0xabc' }],
  [`${N}/getTransactionReceipt-response`, { receipt: '{"status":1}' }],
  // edge cases: multi-byte varint length (300-char) + unicode
  [`${N}/getAddress-response`, { address: 'a'.repeat(300) }],
  [`${N}/getApproveTransaction-response`, { to: 'héllo 🌍', value: 'x', data: 'y' }],
]

const out = cases.map(([enc, value]) => {
  const buf = body(enc, value)
  const decoded = hc.decode(getEncoding(enc), buf)
  return { enc, value, hex: hex(buf), decoded }
})
const dest = '/Users/mac/Documents/codes/opensauce/wdk/wdk-starter-flutter/tools/parity/wdk_manager_vectors.json'
writeFileSync(dest, JSON.stringify(out, null, 2))
console.log(`wrote ${out.length} body vectors -> ${dest}`)

// ---- full bare-rpc frame vectors (manager command ids ride the same envelope)
const frame = (message) => {
  const header = c.encode(m.header, message)
  const data = message.data || b4a.alloc(0)
  return hex(b4a.concat([header, data]))
}
const frames = []
// command ids per @wdk-core hrpc.json
const reqs = [
  ['workletStart', 1, `${N}/workletStart-request`, { enableDebugLogs: 0, seedPhrase: 'abandon ability', config: '{}' }, 1],
  ['getAddress', 2, `${N}/getAddress-request`, { network: 'bitcoin', accountIndex: 0 }, 2],
  ['sendTransaction', 5, `${N}/sendTransaction-request`, { network: 'bitcoin', accountIndex: 0, options: { to: 'bc1q', value: '5000' } }, 3],
  ['abstractedAccountTransfer', 9, `${N}/abstractedAccountTransfer-request`, { network: 'ethereum', accountIndex: 0, options: { token: '0xT', recipient: '0xR', amount: '1000000' }, config: { paymasterToken: { address: '0xP' } } }, 4],
  ['dispose', 14, `${N}/dispose-request`, {}, 5],
]
for (const [method, command, enc, value, id] of reqs) {
  const data = body(enc, value)
  frames.push({
    kind: 'request', method, command, id, bodyHex: hex(data),
    frameHex: frame({ type: T.REQUEST, id, command, stream: 0, data }),
  })
}
// a success response (getAddress-response) for id 2
{
  const data = body(`${N}/getAddress-response`, { address: 'bc1qxyz' })
  frames.push({
    kind: 'response', method: 'getAddress', id: 2, bodyHex: hex(data),
    frameHex: frame({ type: T.RESPONSE, id: 2, stream: 0, error: null, data }),
  })
}
// an error response: worklet throws Error('code:5,msg:Insufficient balance')
{
  const err = Object.assign(new Error('code:5,msg:Insufficient balance'), { code: '5', errno: 0 })
  frames.push({
    kind: 'error', id: 3, error: { message: err.message, code: '5', errno: 0 },
    frameHex: frame({ type: T.RESPONSE, id: 3, stream: 0, error: err, data: null }),
  })
}
const fdst = '/Users/mac/Documents/codes/opensauce/wdk/wdk-starter-flutter/tools/parity/wdk_manager_frame_vectors.json'
writeFileSync(fdst, JSON.stringify(frames, null, 2))
console.log(`wrote ${frames.length} frame vectors -> ${fdst}`)
for (const v of frames) console.log(' ', v.kind.padEnd(9), 'cmd', v.command ?? '-', 'id', v.id, v.frameHex)
