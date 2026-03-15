// Copyright 2020 Tejas Mehta <tmthecoder@gmail.com>
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


import Foundation
import Security

/// A class to wrap around Salts in argon2. allowing cryptographically secure generation of salts as well as utilization of premade salts
public class Salt {
    
    /// The byte-array that the salt class wraps around
    let bytes: Data
    
    /**
     Initializes a new `Salt` object with the provided byte array
      
     - Parameter bytes: The byte array to pass to the Salt object
     - Returns: A Salt object containing the byte array
     */
    public init(bytes: Data) {
        self.bytes = bytes
    }
    
    /**
     Initialized a new `Salt` object with a cryptographically secure random byte array
     
     - Parameter length: An optional parameter to set the length the salt should be (set to 16 bytes by default)
     - Returns: A `Salt` object containing a random byte array of the specified length
     */
    public static func newSalt(length: Int = 16) -> Salt {
        // Set a byte array
        var bytes = [UInt8](repeating: 0, count: length)
        // Set random generated numbers to the byte array
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        // Ensure the copy was a success
        if status != errSecSuccess {
            fatalError("SecRandomCopyBytes failed with error code: \(status)")
        }
        // Return the salt
        return Salt(bytes: Data(bytes))
    }
}
