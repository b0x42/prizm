## Argon2Swift
![Argon2Swift](https://github.com/tmthecoder/Argon2Swift/workflows/Argon2Swift/badge.svg)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Swift bindings for the reference C implementation of [Argon2], the winner of the [Password Hash Competition].

[Argon2]: https://github.com/P-H-C/phc-winner-argon2

[Password Hash Competition]: https://password-hashing.net

## Installation (Cocoapods)

Argon2Swift can be installed via Cocoapods by adding the following to your `Podfile`:

```
pod Argon2Swift
```

## Installation (SPM)

Argon2Swift can be installed via SPM (Swift Package Mangeer) by adding the following to your depencencies:

```swift
.package(url: "https://github.com/tmthecoder/Argon2Swift.git", .branch("main"))
```

## Usage

High-level hashing and verification (for direct hashing & verification of byte arrays, check the example)

```swift
import Argon2Swift

// Create a password and a salt
let password = "password"
let s = Salt.newSalt()
//Hash with pre-set params (iterations: 32, memory: 256, parallelism: 2, length: 32, type: Argon2Type.i, version: Argon2Version.V13)
let result = try! Argon2Swift.hashPasswordString(password: password, salt: s)

//Raw hash values available as int list, base 64 string, and hex string
let hashData = result.hashData()
let base64Hash = result.base64String()
let hexHash = result.hexString()

//Encoded hash values available as int list and encoded string
let encodedData = result.encodedData()
let encodedString = result.encodedString()

//Verify password (returns true/false), uses default type (Argon2Type.i)
let verified = try! Argon2Swift.verifyHashString(password: password, hash: stringEncoded);
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker].

[issue tracker]: https://github.com/tmthecoder/Argon2Swift/issues

## Licensing

- Argon2Swift is Licensed under the [MIT License]
- The C implementation of [Argon2] is licensed under a dual [Apache and CC0 License]

[MIT License]: https://github.com/tmthecoder/Argon2Swift/blob/main/LICENSE

[Argon2]: https://github.com/P-H-C/phc-winner-argon2

[Apache and CC0 License]: https://github.com/P-H-C/phc-winner-argon2/blob/master/LICENSE
