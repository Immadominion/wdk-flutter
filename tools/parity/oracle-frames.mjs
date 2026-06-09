import { createRequire } from 'module'
import { writeFileSync } from 'fs'
const require = createRequire(import.meta.url)
const c = require('compact-encoding')
const b4a = require('b4a')
const m = require('bare-rpc/messages')
const { type: T } = require('bare-rpc/constants')
const { getEncoding } = require('./sm-messages.js')

const SM = '@tetherto/wdk-secret-manager'
const hex = (u) => Buffer.from(u).toString('hex')
// Full wire frame = header (incl. uint32 len + dataLen) ++ raw data bytes
const frame = (message) => {
  const header = c.encode(m.header, message)
  const data = message.data || b4a.alloc(0)
  return hex(b4a.concat([header, data]))
}
const body = (enc, v) => Buffer.from(c.encode(getEncoding(enc), v))

const vectors = []
// requests: command ids per secret-manager hrpc.json (workletStart=0, stop=1, genEnc=2, decrypt=3)
const reqs = [
  ['commandWorkletStart', 0, `${SM}/command-workletStart-request`, { enableDebugLogs: 0 }, 1],
  ['commandWorkletStart', 0, `${SM}/command-workletStart-request`, { enableDebugLogs: 1 }, 2],
  ['commandGenerateAndEncrypt', 2, `${SM}/command-generateAndEncrypt-request`, { passkey: 'pk', salt: 'abcd' }, 3],
  ['commandDecrypt', 3, `${SM}/command-decrypt-request`, { passkey: 'p', salt: 's', encryptedData: '00ff' }, 7],
  ['commandWorkletStop', 1, `${SM}/command-workletStop-request`, {}, 9],
]
for (const [method, command, enc, value, id] of reqs) {
  const data = body(enc, value)
  vectors.push({
    kind: 'request', method, command, id, bodyHex: hex(data),
    frameHex: frame({ type: T.REQUEST, id, command, stream: 0, data }),
  })
}
// a success response (workletStart-response {status:'started'}) for id 1
{
  const data = body(`${SM}/command-workletStart-response`, { status: 'started' })
  vectors.push({
    kind: 'response', id: 1, bodyHex: hex(data),
    frameHex: frame({ type: T.RESPONSE, id: 1, stream: 0, error: null, data }),
  })
}
// an error response: worklet throws Error('code:13,msg:cancelled') with code/errno
{
  const err = Object.assign(new Error('code:13,msg:cancelled'), { code: '13', errno: 0 })
  vectors.push({
    kind: 'error', id: 2, error: { message: err.message, code: '13', errno: 0 },
    frameHex: frame({ type: T.RESPONSE, id: 2, stream: 0, error: err, data: null }),
  })
}
const dst = '/Users/mac/Documents/codes/opensauce/wdk/wdk-starter-flutter/tools/parity/hrpc_frame_vectors.json'
writeFileSync(dst, JSON.stringify(vectors, null, 2))
console.log(`wrote ${vectors.length} frame vectors`)
for (const v of vectors) console.log(' ', v.kind.padEnd(9), 'id', v.id, v.frameHex)
