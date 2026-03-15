// Copyright 2020 Tejas Mehta <tmthecoder@gmail.com>
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


import Foundation
import Argon2

/// Main class to handle all Argon2 hashing and verification
/// ### Usage Example ###
///
///  - Hash the password: "Password12"
///
///    ````
///    let hashResult = try! Argon2Swift.hashPasswordString(password: "Password12", salt: Salt.newSalt())
///    let hashData = hashResult.hashData()
///    let base64Hash = hashResult.base64String()
///    let hexHash = hashResult.hexString()
///    let encodedData = hashResult.encodedData()
///    let encodedString = hashResult.encodedString()
///    ````
public class Argon2Swift {
        
    /**
     Hashes a given `String` password with Argon2 utilizing the given salt as well as optionally the specific parameters of the hashing operation itself
     
     - Parameters:
        - password: The `String` password to hash (utf-8 encoded)
        - salt: The `Salt ` to use with Argon2 as the salt in the hashing operation
        - iterations: The amount of iterations that the algorithm should perform (optional parameter, defaults to 32)
        - memory: The amount of memory the hashing operation can use at a maximum (optional parameter, defaults to 256)
        - parallelism: The factor of parallelism when comouting the hash (optional parameter, defaults to 2)
        - length: The length of the final hash (optional parameter, defaults to 32)
        - type: The specific type of Argon2 to use, either`i`, `d`, or `id` (optional parameter, defaults to `.i`)
        - version: The version of Argon2 to use in the hashing computation, either `V10` or `V13` (optional parameter, defaults to `.V13`)
     
     - Throws: `Argon2SwiftException` if the hashing fails in any manner
     
     - Returns: An `Argon2SwiftResult` containing the hash, encoding, and convenience methods to access the hash and encoded results in various forms
     */
    public static func hashPasswordString(password: String, salt: Salt, iterations: Int = 32, memory: Int = 256, parallelism: Int = 2, length: Int = 32, type: Argon2Type = .i, version: Argon2Version = .V13) throws -> Argon2SwiftResult {
        // Perform the hash with the hashPasswordBytes method with the converted password
        return try hashPasswordBytes(password: Data(password.utf8), salt: salt, iterations: iterations, memory: memory, parallelism: parallelism, length: length, type: type, version: version)
    }
    
    /**
     Hashes a given `Data` password with Argon2 utilizing the given salt as well as optionally the specific parameters of the hashing operation itself
     
     - Parameters:
        - password: The `Data` password to hash
        - salt: The `Salt ` to use with Argon2 as the salt in the hashing operation
        - iterations: The amount of iterations that the algorithm should perform (optional parameter, defaults to 32)
        - memory: The amount of memory the hashing operation can use at a maximum (optional parameter, defaults to 256)
        - parallelism: The factor of parallelism when comouting the hash (optional parameter, defaults to 2)
        - length: The length of the final hash (optional parameter, defaults to 32)
        - type: The specific type of Argon2 to use, either`i`, `d`, or `id` (optional parameter, defaults to `.i`)
        - version: The version of Argon2 to use in the hashing computation, either `V10` or `V13` (optional parameter, defaults to `.V13`)
     
     - Throws: `Argon2SwiftException` if the hashing fails in any manner
     
     - Returns: An `Argon2SwiftResult` containing the hash, encoding, and convenience methods to access the hash and encoded results in various forms
     */
    public static func hashPasswordBytes(password: Data, salt: Salt, iterations: Int = 32, memory: Int = 256, parallelism: Int = 2, length: Int = 32, type: Argon2Type = .i, version: Argon2Version = .V13) throws -> Argon2SwiftResult {
        
        // get length of encoded result
        let encodedLen = argon2_encodedlen(UInt32(iterations), UInt32(memory), UInt32(parallelism), UInt32(salt.bytes.count), UInt32(length), getArgon2Type(type: type))
        // Allocate a pointer for the hash and the encoded hash
        let hash = setPtr(length: length)
        let encoded = setPtr(length: encodedLen)

        // Perform the actual hash operation
        let errorCode = argon2_hash(UInt32(iterations), UInt32(memory), UInt32(parallelism), [UInt8](password), password.count, [UInt8](salt.bytes), salt.bytes.count, hash, length, encoded, encodedLen, getArgon2Type(type: type), UInt32(version.rawValue))
        
        // Check if there were any errors
        if errorCode != Argon2SwiftErrorCode.ARGON2_OK.rawValue {
            let errorMsg = String(cString: argon2_error_message(errorCode))
            throw Argon2SwiftException(errorMsg, errorCode: Argon2SwiftErrorCode(rawValue: errorCode) ?? Argon2SwiftErrorCode.ARGON2_UNKNOWN_ERROR)
        }
        
        // Create copy arrays for the hash and encoded results
        let hashArray = Array(UnsafeBufferPointer(start: hash, count: length))
        let encodedArray = Array(UnsafeBufferPointer(start: encoded, count: encodedLen))
        
        // Create an instance of Argon2SwiftResult with the arrays
        let result = Argon2SwiftResult(hashBytes: hashArray, encodedBytes: encodedArray)
        
        // Free the previously created pointers
        freePtr(pointer: hash, length: length)
        freePtr(pointer: encoded, length: encodedLen)
        
        // Return the result from above
        return result
    }
    
    /**
     Verifies a `String` password with the given encoded `String`, returning `true` on successful verifications and `false` on incorrect ones.
     
     - Parameters:
        - password: The `String` password to verify and check (utf-8 encoded)
        - encoded: The `String` encoded Argon2 value to check the password against (utf-8 encoded)
        - type: The specific type of Argon2 to use, either `i`, `d`, or `id` (optional parameter, defaults to `.i`)
     
     - Throws: `Argon2SwiftException` if the verification fails in any manner
     
     - Returns: A `Bool` signifying whether the password is equivalent to the hash or not
     */
    public static func verifyHashString(password: String, hash: String, type: Argon2Type = .i) throws -> Bool {
        return try verifyHashBytes(password: Data(password.utf8), hash: Data(hash.utf8), type: type)
    }
    
    /**
     Verifies a `Data` password with the given encoded `Data`, returning `true` on successful verifications and `false` on incorrect ones.
     
     - Parameters:
        - password: The `Data` password to verify and check
        - encoded: The `Data` encoded Argon2 value to check the password against
        - type: The specific type of Argon2 to use, either `i`, `d`, or `id` (optional parameter, defaults to `.i`)
     
     - Throws: `Argon2SwiftException` if the verification fails in any manner
     
     - Returns: A `Bool` signifying whether the password is equivalent to the hash or not
     */
    public static func verifyHashBytes(password: Data, hash: Data, type: Argon2Type = .i) throws -> Bool {
        // Convert encoded to a c string
        let encodedStr = String(data: hash, encoding: .utf8)?.cString(using: .utf8)
        // Get the verified result
        let result = argon2_verify(encodedStr, [UInt8](password), password.count, getArgon2Type(type: type))
        if result != Argon2SwiftErrorCode.ARGON2_OK.rawValue && result != Argon2SwiftErrorCode.ARGON2_VERIFY_MISMATCH.rawValue {
            let errorMsg = String(cString: argon2_error_message(result))
            throw Argon2SwiftException(errorMsg, errorCode: Argon2SwiftErrorCode(rawValue: result) ?? Argon2SwiftErrorCode.ARGON2_UNKNOWN_ERROR)
        }
        // Return if it's verified or not
        return result == 0
    }

    /**
     A method to map the `Argon2Type` Swift enum to the `Argon2_type` C struct in the reference library
     
     - Parameter type: The `Argon2Type` to get the equivalent `Argon2_type` for
     
     - Returns: An `Argon2_type` object to use in the C argon2 methods
     */
    static func getArgon2Type(type: Argon2Type) -> Argon2_type {
        // Check what type was supplied and return the corresponding Argon2_type object
        var argonType = Argon2_i
        if (type == .d) {
            argonType = Argon2_d
        }
        if (type == .id) {
            argonType = Argon2_id
        }
        return argonType
    }
    
    /**
     A method to set an `[Int8]` mutable pointer that the C methods will modify with results
     
     - Parameter length: The length of the pointer to allocate
     
     - Returns: An allocated `UnsafeMutablePointer<Int8>` with the given length
     */
    static func setPtr(length: Int) -> UnsafeMutablePointer<Int8> {
        // Create and allocate a pointer with the given length
        return UnsafeMutablePointer<Int8>.allocate(capacity: length)
    }
    
    /**
     A method to deinitialize and deallocate an `Int8` mutable pointer that has been already allocated
     
     - Parameters:
        - pointer: The  `UnsafeMutablePointer<Int8>` to deinitialize and free
        - length: The length of the given pointer
     */
    static func freePtr(pointer: UnsafeMutablePointer<Int8>, length: Int) {
        // Deinitialize and deallocate a pointer of the given length
        pointer.deinitialize(count: length)
        pointer.deallocate()
    }
    
}
