//
//  Argon2SwiftTests.swift
//  Argon2Swift
//
//  Created by Tejas Mehta on 1/18/21.
//

import Foundation
import XCTest
import Argon2Swift

class Argon2SwiftTests: XCTestCase {
    /// All Argon2i Tests
    func testArgon2i() {
        XCTAssertEqual(hashTest(version: .V13, iterations: 2, memory: 16, parallelism: 1, password: "password", salt: "somesalt", hexHash: "03df1d13e10203bcc663405e31ab1687939730c9152459bca28fd10c23e38f50", encodedHash: "$argon2i$v=19$m=16,t=2,p=1$c29tZXNhbHQ$A98dE+ECA7zGY0BeMasWh5OXMMkVJFm8oo/RDCPjj1A",type: .i), Argon2SwiftErrorCode.ARGON2_OK, "Argon2i: v = ${0x13}, t = 2, m = 16, p = 1")
        
        XCTAssertEqual(hashTest(version: .V13, iterations: 2, memory: 18, parallelism: 1, password: "password", salt: "somesalt", hexHash: "3b1b4ad0a66b3f00b4cd04225e4e6da950ee152bf0d29aabcb123c2f1a90567a", encodedHash: "$argon2i$v=19$m=18,t=2,p=1$c29tZXNhbHQ$OxtK0KZrPwC0zQQiXk5tqVDuFSvw0pqryxI8LxqQVno",type: .i), Argon2SwiftErrorCode.ARGON2_OK, "Argon2i: v = ${0x13}, t = 2, m = 18, p = 1")
        
        XCTAssertEqual(hashTest(version: .V13, iterations: 2, memory: 8, parallelism: 1, password: "password", salt: "somesalt", hexHash: "48cc13c16c5a2d254a278e2c44420ba0fb2d0f070661e35d6486604a7a2ff1a9", encodedHash: "$argon2i$v=19$m=8,t=2,p=1$c29tZXNhbHQ$SMwTwWxaLSVKJ44sREILoPstDwcGYeNdZIZgSnov8ak",type: .i), Argon2SwiftErrorCode.ARGON2_OK, "Argon2i: v = ${0x13}, t = 2, m = 8, p = 1")
        
        XCTAssertEqual(hashTest(version: .V13, iterations: 2, memory: 16, parallelism: 2, password: "password", salt: "somesalt", hexHash: "7fbb85db7e9636115f2fd0f29ea4214baaada18b39fffed7875eeb9fa9b308c5", encodedHash: "$argon2i$v=19$m=16,t=2,p=2$c29tZXNhbHQ$f7uF236WNhFfL9DynqQhS6qtoYs5//7Xh17rn6mzCMU",type: .i), Argon2SwiftErrorCode.ARGON2_OK, "Argon2i: v = ${0x13}, t = 2, m = 16, p = 2")
    }
    
    /// All Argon2d tests
    func testArgon2d() {
        XCTAssertEqual(hashTest(version: .V13, iterations: 2, memory: 16, parallelism: 1, password: "password", salt: "somesalt", hexHash: "e742c05880c44c4df5fe79937be77897a6e41ca758affc42301f1e4040e35bd2", encodedHash: "$argon2d$v=19$m=16,t=2,p=1$c29tZXNhbHQ$50LAWIDETE31/nmTe+d4l6bkHKdYr/xCMB8eQEDjW9I",type: .d), Argon2SwiftErrorCode.ARGON2_OK, "Argon2d: v = ${0x13}, t = 2, m = 16, p = 1")
        
        XCTAssertEqual(hashTest(version: .V13, iterations: 2, memory: 18, parallelism: 1, password: "password", salt: "somesalt", hexHash: "d24d7d614122db6458d66b4f35dc45b1cca59f9b71945db207e78062601d2dd5", encodedHash: "$argon2d$v=19$m=18,t=2,p=1$c29tZXNhbHQ$0k19YUEi22RY1mtPNdxFscyln5txlF2yB+eAYmAdLdU",type: .d), Argon2SwiftErrorCode.ARGON2_OK, "Argon2d: v = ${0x13}, t = 2, m = 18, p = 1")
        
        XCTAssertEqual(hashTest(version: .V13, iterations: 2, memory: 8, parallelism: 1, password: "password", salt: "somesalt", hexHash: "7d124315b3ba588668393b2e2d6867bd9f211a4eebd240d0023e540a783a69f0", encodedHash: "$argon2d$v=19$m=8,t=2,p=1$c29tZXNhbHQ$fRJDFbO6WIZoOTsuLWhnvZ8hGk7r0kDQAj5UCng6afA",type: .d), Argon2SwiftErrorCode.ARGON2_OK, "Argon2d: v = ${0x13}, t = 2, m = 8, p = 1")
        
        XCTAssertEqual(hashTest(version: .V13, iterations: 2, memory: 16, parallelism: 2, password: "password", salt: "somesalt", hexHash: "59f20a66a4c31bf0438a2f494867c32120409a91380f0687aefee984ba86bda8", encodedHash: "$argon2d$v=19$m=16,t=2,p=2$c29tZXNhbHQ$WfIKZqTDG/BDii9JSGfDISBAmpE4DwaHrv7phLqGvag",type: .d), Argon2SwiftErrorCode.ARGON2_OK, "Argon2d: v = ${0x13}, t = 2, m = 16, p = 2")
    }
    
    /// All Argon2id tests
    func testArgon2id() {
        XCTAssertEqual(hashTest(version: .V13, iterations: 2, memory: 16, parallelism: 1, password: "password", salt: "somesalt", hexHash: "058202c0723cd88c24408ccac1cbf828dee63bcf3843a150ea364a1e0b4e1ff8", encodedHash: "$argon2id$v=19$m=16,t=2,p=1$c29tZXNhbHQ$BYICwHI82IwkQIzKwcv4KN7mO884Q6FQ6jZKHgtOH/g",type: .id), Argon2SwiftErrorCode.ARGON2_OK, "Argon2id: v = ${0x13}, t = 2, m = 16, p = 1")
        
        XCTAssertEqual(hashTest(version: .V13, iterations: 2, memory: 18, parallelism: 1, password: "password", salt: "somesalt", hexHash: "0e6408c954c4980f6313756ea01ee7ddebb362efbb20d49d08a6859787024e3f", encodedHash: "$argon2id$v=19$m=18,t=2,p=1$c29tZXNhbHQ$DmQIyVTEmA9jE3VuoB7n3euzYu+7INSdCKaFl4cCTj8",type: .id), Argon2SwiftErrorCode.ARGON2_OK, "Argon2id: v = ${0x13}, t = 2, m = 18, p = 1")
        
        XCTAssertEqual(hashTest(version: .V13, iterations: 2, memory: 8, parallelism: 1, password: "password", salt: "somesalt", hexHash: "fdb4ddb6d5887131b66f0b2a3740c077dd05b755845861f6b5a1dde8b1071646", encodedHash: "$argon2id$v=19$m=8,t=2,p=1$c29tZXNhbHQ$/bTdttWIcTG2bwsqN0DAd90Ft1WEWGH2taHd6LEHFkY",type: .id), Argon2SwiftErrorCode.ARGON2_OK, "Argon2id: v = ${0x13}, t = 2, m = 8, p = 1")
        
        XCTAssertEqual(hashTest(version: .V13, iterations: 2, memory: 16, parallelism: 2, password: "password", salt: "somesalt", hexHash: "747d7631b182faf749d7efc31aec31df4ecfe3b57c792f53800ac2c9978b4888", encodedHash: "$argon2id$v=19$m=16,t=2,p=2$c29tZXNhbHQ$dH12MbGC+vdJ1+/DGuwx307P47V8eS9TgArCyZeLSIg",type: .id), Argon2SwiftErrorCode.ARGON2_OK, "Argon2id: v = ${0x13}, t = 2, m = 16, p = 2")
    }
    
    /**
     A method to test the hashes utilizing the `Argon2Swift` class and comparing it against results from other hashers
     
     - Parameters:
        - version: The version of argon2 to test with
        - iterations: The number of iterations to pass to the hashing operation
        - memory: The maximum memory the operation can consume
        - parallelism: The factor of parallelism used in the operation
        - password: The `String` password to hash (utf-8 encoded)
        - salt: The `String` salt to pass to the operation (utf-8 encoded)
        - hexHash: The expected hexadecimal hash the operation will yield
        - encodedHash: The expected encoded hash the operation will yield
     */
    func hashTest(version: Argon2Version, iterations: Int, memory: Int, parallelism: Int, password: String, salt: String, hexHash: String, encodedHash: String, type: Argon2Type) -> Argon2SwiftErrorCode {
        let s = Salt(bytes: Data(salt.utf8))
        var resultString : Argon2SwiftResult
        var resultBytes : Argon2SwiftResult
        // Perform the hash
        do {
            resultString = try Argon2Swift.hashPasswordString(password: password, salt: s, iterations: iterations, memory: memory, parallelism: parallelism, type: type, version: version)
            resultBytes = try Argon2Swift.hashPasswordBytes(password: Data(password.utf8), salt: s, iterations: iterations, memory: memory, parallelism: parallelism, type: type, version: version)
        } catch {
            // Return error
            return (error as? Argon2SwiftException)?.errorCode ?? Argon2SwiftErrorCode.ARGON2_UNKNOWN_ERROR
        }
        
        // Check for equality between both hashes
        if resultString.encodedString() != resultBytes.encodedString() {
            return Argon2SwiftErrorCode.ARGON2_UNKNOWN_ERROR
        }
        
        // Check if the hex strings match
        if resultBytes.hexString() != hexHash || resultString.hexString() != hexHash {
            return Argon2SwiftErrorCode.ARGON2_UNKNOWN_ERROR
        }
        
        // Check if verification of both methods match
        do {
            let verificationString = try Argon2Swift.verifyHashString(password: password, hash: encodedHash, type: type)
            let verificationBytes = try Argon2Swift.verifyHashBytes(password: Data(password.utf8), hash: Data(encodedHash.utf8), type: type)
            if !verificationString || !verificationBytes {
                return Argon2SwiftErrorCode.ARGON2_UNKNOWN_ERROR
            }
        } catch {
            return (error as? Argon2SwiftException)?.errorCode ?? Argon2SwiftErrorCode.ARGON2_UNKNOWN_ERROR
        }
        // Check if they verify against each other
        do {
            let verificationByteHash = try Argon2Swift.verifyHashString(password: password, hash: resultBytes.encodedString(), type: type)
            let verificationStringHash = try Argon2Swift.verifyHashString(password: password, hash: resultString.encodedString(), type: type)
            if !verificationByteHash || !verificationStringHash {
                return Argon2SwiftErrorCode.ARGON2_UNKNOWN_ERROR
            }
        } catch {
            return (error as? Argon2SwiftException)?.errorCode ?? Argon2SwiftErrorCode.ARGON2_UNKNOWN_ERROR
        }
        
        // All verified
        return Argon2SwiftErrorCode.ARGON2_OK
    }
}
