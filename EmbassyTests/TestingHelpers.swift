//
//  TestingHelpers.swift
//  Embassy
//
//  Created by Fang-Pen Lin on 5/20/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import Foundation
import XCTest

@testable import Embassy

let isLittleEndian = Int(OSHostByteOrder()) == OSLittleEndian
let htons  = isLittleEndian ? _OSSwapInt16 : { $0 }
let ntohs  = isLittleEndian ? _OSSwapInt16 : { $0 }

/// Find an available localhost TCP port from 1024-65535 and return it.
/// Ref: https://github.com/pytest-dev/pytest-asyncio/blob/412c63776b32229ed8320e6c7ea920d7498cd695/pytest_asyncio/plugin.py#L103-L107
func getUnusedTCPPort() throws -> Int {
    var interfaceAddress: in_addr = in_addr()
    guard "127.0.0.1".withCString({ inet_pton(AF_INET, $0, &interfaceAddress) >= 0 }) else {
        throw OSError.lastIOError()
    }

    let fileDescriptor = socket(AF_INET, SOCK_STREAM, 0)
    guard fileDescriptor >= 0 else {
        throw OSError.lastIOError()
    }
    defer {
        close(fileDescriptor)
    }

    var address = sockaddr_in(
        sin_len: UInt8(MemoryLayout<sockaddr_in>.stride),
        sin_family: UInt8(AF_INET),
        sin_port: htons(UInt16(0)),
        sin_addr: interfaceAddress,
        sin_zero: (0, 0, 0, 0, 0, 0, 0, 0)
    )
    let addressSize = socklen_t(MemoryLayout<sockaddr_in>.size)
    // given port 0, and bind, it will find us an available port
    guard withUnsafePointer(to: &address, { pointer in
        return pointer.withMemoryRebound(to: sockaddr.self, capacity: Int(addressSize)) { pointer in
            return Darwin.bind(fileDescriptor, pointer, addressSize) >= 0
        }
    }) else {
        throw OSError.lastIOError()
    }

    var socketAddress = sockaddr_in()
    var socketAddressSize = socklen_t(MemoryLayout<sockaddr_in>.size)
    guard withUnsafeMutablePointer(to: &socketAddress, { pointer in
        return pointer.withMemoryRebound(to: sockaddr.self, capacity: Int(socketAddressSize)) { pointer in
            return getsockname(fileDescriptor, pointer, &socketAddressSize) >= 0
        }
    }) else {
        throw OSError.lastIOError()
    }
    return Int(ntohs(socketAddress.sin_port))
}

func makeRandomString(_ length: Int) -> String {
    let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    var result: [String] = []
    for _ in 0..<length {
        let randomIndex = Int(arc4random_uniform(UInt32(letters.characters.count)))
        let char = letters.substring(with: letters.characters.index(letters.startIndex, offsetBy: randomIndex) ..< letters.characters.index(letters.startIndex, offsetBy: randomIndex + 1))
        result.append(char)
    }
    return result.joined(separator: "")
}

extension XCTestCase {
    @discardableResult
    func assertExecutingTime<T>(_ time: TimeInterval, accuracy: TimeInterval, file: StaticString = #file, line: UInt = #line, closure: (Void) -> T) -> T {
        let begin = Date()
        let result = closure()
        let elapsed = Date().timeIntervalSince(begin)
        XCTAssertEqualWithAccuracy(elapsed, time, accuracy: accuracy, "Wrong executing time", file: file, line: line)
        return result
    }
}
