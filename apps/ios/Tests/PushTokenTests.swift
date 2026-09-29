import Foundation
import Testing
@testable import ServoMap

struct PushTokenTests {
    @Test func hexIsLowercaseTwoDigitsPerByte() {
        #expect(PushToken.hex(Data([0x00, 0x0f, 0xab, 0xff])) == "000fabff")
    }

    @Test func emptyTokenIsEmptyString() {
        #expect(PushToken.hex(Data()) == "")
    }

    @Test func thirtyTwoByteTokenIsSixtyFourCharacters() {
        let token = Data((0..<32).map { UInt8($0) })
        let hex = PushToken.hex(token)
        #expect(hex.count == 64)
        #expect(hex.hasPrefix("00010203"))
    }
}
