// Generate local signing material without exposing passwords in command arguments.
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const android = path.resolve(__dirname, '../linkso_client/android');
const store = path.join(android, 'keystore/linkso-release.jks');
const properties = path.join(android, 'key.properties');
if (fs.existsSync(store) || fs.existsSync(properties)) {
  throw new Error('Signing material already exists; refusing to overwrite it. Back it up and use the existing key.');
}

const keytool = process.argv[2] || (process.env.JAVA_HOME
  ? path.join(process.env.JAVA_HOME, 'bin', process.platform === 'win32' ? 'keytool.exe' : 'keytool')
  : 'keytool');
const password = crypto.randomBytes(32).toString('hex');
fs.mkdirSync(path.dirname(store), { recursive: true, mode: 0o700 });
const result = spawnSync(keytool, [
  '-genkeypair', '-noprompt', '-storetype', 'JKS', '-keystore', store,
  '-alias', 'linkso', '-keyalg', 'RSA', '-keysize', '4096', '-validity', '10000',
  '-dname', 'CN=LinkSo, O=LinkSo',
  '-storepass:env', 'LINKSO_GENERATED_KEY_PASSWORD',
  '-keypass:env', 'LINKSO_GENERATED_KEY_PASSWORD',
], { env: { ...process.env, LINKSO_GENERATED_KEY_PASSWORD: password }, encoding: 'utf8' });
if (result.error || result.status !== 0) {
  throw result.error || new Error(result.stderr || 'keytool failed');
}
fs.chmodSync(store, 0o600);
fs.writeFileSync(properties, [
  'storeFile=keystore/linkso-release.jks', 'keyAlias=linkso',
  `storePassword=${password}`, `keyPassword=${password}`, '',
].join('\n'), { flag: 'wx', mode: 0o600 });
console.log('Created android/keystore/linkso-release.jks and android/key.properties (both ignored by Git).');
console.log('Back up both files securely: the same signing key is required for future Android updates.');
