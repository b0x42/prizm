// Copyright 2020 Tejas Mehta <tmthecoder@gmail.com>
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


import Foundation

/// A wrapper class containing the result of a hash operation performed with Argon2, allowing for ease conversion of the byte array as well as raw access
public class Argon2SwiftResult {
    
    /// The byte array of solely the hashed result
    let hashBytes: [UInt8]
    /// The byte array of the encoded result, containing the hash, version, salt, and Argon2 params
    let encodedBytes: [UInt8]
    
    /**
     Initializes a new `Argon2SwiftResult` object with a given encoded byte array and hash byte array
     
     - Parameters:
        - hashBytes: The byte array of the hashed password
        - encodedBytes: The byte array of the encoded result
     
     - Returns: An `Argon2SwiftResult` object containing the result of the hashing operation performed
     */
    public init(hashBytes: [Int8], encodedBytes: [Int8]) {
        // Convert to UInt8 arrays and set
        self.hashBytes = hashBytes.map { UInt8(bitPattern: $0) }
        self.encodedBytes = encodedBytes.map{ UInt8(bitPattern: $0) }
    }
    
    /**
     A method to return the hash as a `Data` object
     
     - Returns: The computed hash as a `Data` object
     */
    public func hashData() -> Data {
        return Data(hashBytes);
    }
    
    /**
     A method to return the encoded hash as a `Data` object
     
     - Returns: The encoded hash from the computation as a `Data` object
     */
    public func encodedData() -> Data {
        return Data(encodedBytes);
    }
    
    /**
     A method to return the hash as a base64-encoded `String`
     
     - Returns: The hash encoded to base64
     */
    public func base64String() -> String {
        return Data(hashBytes).base64EncodedString()
    }
    
    /**
     A method to return the hash as a hex-encoded  `String`
     
     - Returns: The hash encoded to hex
     */
    public func hexString() -> String {
        return hashBytes.map{ String(format: "%02hhx", $0) }.joined()
    }
    
    /**
     A method to return the encoded computation in its string form
     
     - Returns: The encoded computation with all information as a readable `String`
     */
    public func encodedString() -> String {
        return String(data: Data(encodedBytes), encoding: .utf8)!
    }
}
