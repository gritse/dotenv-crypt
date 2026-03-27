## dotenv-crypt

Swift CLI tool that encrypts individual values in `.env` files using AES-256-GCM. Encryption key stored in macOS Keychain. Touch ID required for all operations that access secrets.

### Install

```sh
swift build -c release
cp .build/release/dotenv-crypt ~/.local/bin/
```

### Quick start

```sh
dotenv-crypt init              # generate encryption key, store in Keychain (once)
dotenv-crypt encrypt DB_PASS   # encrypt a value in .env in-place
dotenv-crypt reveal DB_PASS    # print decrypted value to stdout
dotenv-crypt list              # show all keys, mark [encrypted]/[plaintext]
```

Encrypted values look like this in your `.env`:

```
DB_PASS=enc:v1:BASE64DATA...
```

### Running with decrypted env

```sh
dotenv-crypt exec -- ./my-app                    # inject all decrypted vars and exec
dotenv-crypt docker compose up -d                 # auto-decrypt .env for docker compose
```

The `docker` wrapper detects `compose` subcommands, decrypts any `enc:v1:` values in the relevant `.env`, and passes everything through to docker. Non-compose commands pass through unchanged without Touch ID.

Add to `~/.zshenv` for transparent usage:

```sh
docker() { dotenv-crypt docker "$@"; }
```

### Keychain management

```sh
dotenv-crypt secret -s SERVICE [-a ACCOUNT]       # read any Keychain item
dotenv-crypt add-secret -s SERVICE -a ACCOUNT     # generate random secret, store in Keychain
dotenv-crypt move-key -s SVC... --from K --to K   # move items between keychains
dotenv-crypt tag -s SVC... [-k KIND]              # set Kind shown in Keychain Access
```

### Keychain selection

All commands accept `--keychain <path>`. Falls back to `DOTENV_CRYPT_KEYCHAIN` env var, then the default system keychain.

### Encryption details

- AES-256-GCM via CryptoKit
- Format: `enc:v1:<base64(12-byte nonce + ciphertext + 16-byte tag)>`
- Random nonce per encryption — same plaintext produces different ciphertext
- Key stored as generic password in macOS Keychain
- Touch ID gate via `LAContext` (not Keychain ACL)

### Requirements

- macOS with Touch ID (or Apple Watch unlock)
- Swift 5.9+
- `swift-argument-parser` 1.5+
