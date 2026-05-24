# Ballerina Crypto Library

## Overview

This module provides cryptographic operations for Ballerina programs. The full jBallerina `crypto` module covers hashing, HMAC, password hashing, symmetric encryption (AES), asymmetric encryption and signing (RSA, ECDSA), key derivation (HKDF), and post-quantum primitives (ML-KEM, ML-DSA, HPKE, PGP). The Go Native Interpreter supports the core cryptographic subset.

## Key Functionalities

- **Hashing**: MD5, SHA-1, SHA-256, SHA-384, SHA-512, Keccak-256 with optional salt prepend; CRC32B checksum.
- **HMAC**: HMAC-MD5, HMAC-SHA1, HMAC-SHA256, HMAC-SHA384, HMAC-SHA512.
- **Password hashing**: BCrypt, Argon2id, PBKDF2 with hash/verify pairs.
- **AES encryption**: AES-CBC, AES-ECB, AES-GCM (128/256-bit keys; GCM tag size configurable in bits, default 128).
- **RSA**: Encrypt/decrypt (PKCS1 and OAEP padding), sign/verify (MD5, SHA1, SHA256, SHA384, SHA512, PSS-SHA256).
- **ECDSA**: Sign/verify with SHA-256 and SHA-384 (DER-encoded signatures).
- **Key loading**: RSA and EC private keys from PEM files or raw bytes; RSA and EC public keys from X.509 certificates (PEM files or raw bytes); PKCS12 keystores/truststores.
- **HKDF**: HKDF-SHA256 key derivation with optional salt and info.
- **Utilities**: Constant-time comparison of hash values (`HashValue = byte[]|string`).

## Examples

```ballerina
import ballerina/crypto;
import ballerina/io;

public function main() returns error? {
    // "Hello Ballerina"
    byte[] data = [72, 101, 108, 108, 111, 32, 66, 97, 108, 108, 101, 114, 105, 110, 97];

    // Hash
    io:println(crypto:hashSha256(data).length()); // 32

    // HMAC
    byte[] key = [115, 101, 99, 114, 101, 116, 107, 101, 121, 48, 49, 50, 51, 52, 53, 54];
    io:println((check crypto:hmacSha256(data, key)).length()); // 32

    // AES-GCM round-trip
    byte[] aesKey = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];
    byte[] iv = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
    byte[] enc = check crypto:encryptAesGcm(data, aesKey, iv);
    byte[] dec = check crypto:decryptAesGcm(enc, aesKey, iv);
    io:println(crypto:equalConstantTime(dec, data)); // true

    // RSA sign and verify
    crypto:PrivateKey privKey = check crypto:decodeRsaPrivateKeyFromKeyFile("private.pem");
    crypto:PublicKey pubKey = check crypto:decodeRsaPublicKeyFromCertFile("cert.pem");
    byte[] sig = check crypto:signRsaSha256(data, privKey);
    io:println(check crypto:verifyRsaSha256Signature(data, sig, pubKey)); // true

    // HKDF
    byte[] ikm = [105, 110, 112, 117, 116];
    byte[] derived = check crypto:hkdfSha256(ikm, 32);
    io:println(derived.length()); // 32
}
```

## Go Native Interpreter Support Status

This library is currently being migrated to Go to support the Ballerina Native Interpreter. The table below outlines the current support level for various features of this library in the Go implementation.

Support Levels:

- **Supported**: Fully implemented and tested in the Go version.
- **Partially Supported**: Implemented but lacking some edge cases, options, or sub-features. (See comments).
- **Not Yet Supported**: Planned for migration, but not yet implemented.
- **Cannot Support**: Cannot be implemented in the Go version due to technical limitations or architectural differences. (See comments).

| Feature/API | Support Status | Comments / Limitations |
|---|---|---|
| `hashMd5`, `hashSha1`, `hashSha256`, `hashSha384`, `hashSha512` | Supported | Optional `salt byte[]` parameter supported; salt is prepended before hashing. |
| `hashKeccak256` | Supported | Uses legacy Keccak-256 (pre-standardisation), not SHA3-256, matching jBallerina. |
| `crc32b` | Supported | Returns 8-character uppercase hex string. |
| `hmacMd5`, `hmacSha1`, `hmacSha256`, `hmacSha384`, `hmacSha512` | Supported | |
| `hashBcrypt` / `verifyBcrypt` | Supported | `workFactor` parameter supported. |
| `hashArgon2` / `verifyArgon2` | Supported | Argon2id with configurable iterations, memory, parallelism. Format: `$argon2id$v=19$m=<mem>,t=<iter>,p=<par>$<b64salt>$<b64hash>`. |
| `hashPbkdf2` / `verifyPbkdf2` | Supported | SHA1, SHA256, SHA512 algorithms; configurable iteration count. Format: `$pbkdf2-{SHA1\|SHA256\|SHA512}$i=<iter>$<b64salt>$<b64hash>`. |
| `encryptAesCbc` / `decryptAesCbc` | Supported | PKCS7 padding applied regardless of `padding` parameter. |
| `encryptAesEcb` / `decryptAesEcb` | Supported | PKCS7 padding applied. |
| `encryptAesGcm` / `decryptAesGcm` | Supported | `tagSize` parameter is in **bits** (default 128); valid sizes: 32, 64, 96, 104, 112, 120, 128. |
| `encryptRsaEcb` / `decryptRsaEcb` | Supported | PKCS1 and OAEP (MD5, SHA1, SHA256, SHA384, SHA512) padding supported. |
| `signRsaMd5`, `signRsaSha1`, `signRsaSha256`, `signRsaSha384`, `signRsaSha512` | Supported | PKCS1v15 signature. |
| `signRsaSsaPss256` | Supported | PSS with SHA-256; uses `PSSSaltLengthEqualsHash` to match jBallerina. |
| `verifyRsaMd5Signature`, …, `verifyRsaSha512Signature` | Supported | PKCS1v15 verification. |
| `verifyRsaSsaPss256Signature` | Supported | |
| `signSha256withEcdsa` / `signSha384withEcdsa` | Supported | DER-encoded ECDSA signature matching jBallerina's `ASN.1` format. |
| `verifySha256withEcdsaSignature` / `verifySha384withEcdsaSignature` | Supported | |
| `decodeRsaPrivateKeyFromKeyStore` / `decodeEcPrivateKeyFromKeyStore` | Supported | PKCS12 keystore format. |
| `decodeRsaPrivateKeyFromKeyFile` / `decodeEcPrivateKeyFromKeyFile` | Supported | PEM format (PKCS8, PKCS1, EC); encrypted keys supported. |
| `decodeRsaPrivateKeyFromContent` | Supported | PEM bytes. |
| `decodeRsaPublicKeyFromTrustStore` / `decodeEcPublicKeyFromTrustStore` | Supported | PKCS12 truststore format. |
| `decodeRsaPublicKeyFromCertFile` / `decodeEcPublicKeyFromCertFile` | Supported | PEM or DER X.509 certificate. |
| `decodeRsaPublicKeyFromContent` | Supported | PEM bytes. |
| `buildRsaPublicKey` | Supported | From hex-encoded modulus and exponent. |
| `hkdfSha256` | Supported | Optional `salt` and `info` parameters. |
| `equalConstantTime` | Supported | `HashValue = byte[]\|string`; constant-time comparison. |
| ML-KEM-768 (`encapsulate`, `decapsulate`) | Not Yet Supported | Post-quantum KEM not yet implemented. |
| ML-DSA-65 (`signMlDsa65`, `verifyMlDsa65Signature`) | Not Yet Supported | Post-quantum DSA not yet implemented. |
| HPKE (`hybridEncrypt`, `hybridDecrypt`) | Not Yet Supported | Hybrid public-key encryption not yet implemented. |
| PGP (`pgpEncrypt`, `pgpDecrypt`, `pgpSign`, `pgpVerify`) | Not Yet Supported | PGP operations not yet implemented. |
| `decodeEcPublicKeyFromContent` | Not Yet Supported | EC public key from PEM bytes not yet implemented. |

### Notable Behavioural Changes

| Feature | jBallerina behaviour | Go-native behaviour |
|---|---|---|
| `Certificate.notBefore` / `notAfter` | `time:Utc` (ballerina/time type) | `time:Utc` — matches jBallerina exactly. |
| Hash salt order | `digest.update(salt)` then `digest.digest(input)` in Java | Salt bytes are **prepended** (written before the input data) matching Java's behaviour. |
| AES padding | `padding` parameter selects PKCS5 or NONE | PKCS7 padding is always applied for CBC and ECB modes regardless of the `padding` parameter value. |
| ECDSA signature format | DER-encoded ASN.1 (via `Signature.getInstance("SHA256withECDSA")`) | DER-encoded via `ecdsa.SignASN1` — identical wire format. |
| RSA-PSS salt length | Java default: salt length equals hash length | `rsa.PSSSaltLengthEqualsHash` — identical to jBallerina default. |
| `crypto:Error` type | Distinct subtypes (`KeyNotFoundError`, `CipherError`, etc.) | Plain `error` alias — `distinct` error subtypes not yet supported. |
