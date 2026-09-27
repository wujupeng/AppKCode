import XCTest
@testable import AppKCodeDomain
import AppKCodeShared

final class AIBoundaryTests: XCTestCase {

    func testH9_AllowedCapabilities() {
        let validator = AIBoundaryValidator()
        for capability in AICapability.allCases {
            let decision = validator.validate(capability: capability)
            XCTAssertTrue(decision.allowed.contains(capability))
            XCTAssertTrue(decision.prohibited.isEmpty)
        }
    }

    func testH9_ProhibitedActions() {
        let validator = AIBoundaryValidator()
        for action in AIProhibitedAction.allCases {
            let decision = validator.validate(action: action)
            XCTAssertTrue(decision.prohibited.contains(action))
            XCTAssertTrue(decision.allowed.isEmpty)
            XCTAssertTrue(decision.reason.contains("prohibited"))
        }
    }

    func testH9_GeneratePatchCandidateAllowed() {
        let validator = AIBoundaryValidator()
        let decision = validator.validate(capability: .generatePatchCandidate)
        XCTAssertTrue(decision.allowed.contains(.generatePatchCandidate))
    }

    func testH9_WriteFileProhibited() {
        let validator = AIBoundaryValidator()
        let decision = validator.validate(action: .writeFile)
        XCTAssertTrue(decision.prohibited.contains(.writeFile))
        XCTAssertTrue(decision.reason.contains("Agent Runtime"))
    }

    func testH9_CheckResponseDetectsProhibitedActions() {
        let validator = AIBoundaryValidator()
        let responseWithWrite = "I will write file to disk"
        let detected = validator.checkResponse(responseWithWrite)
        XCTAssertTrue(detected.contains(.writeFile))

        let responseWithCommit = "Please git commit now"
        let detectedCommit = validator.checkResponse(responseWithCommit)
        XCTAssertTrue(detectedCommit.contains(.gitCommit))

        let responseWithPush = "git push origin main"
        let detectedPush = validator.checkResponse(responseWithPush)
        XCTAssertTrue(detectedPush.contains(.gitPush))

        let responseWithExec = "execute command: rm -rf /"
        let detectedExec = validator.checkResponse(responseWithExec)
        XCTAssertTrue(detectedExec.contains(.executeCommand))
    }

    func testH9_CheckResponseClean() {
        let validator = AIBoundaryValidator()
        let cleanResponse = "This function calculates the sum of two numbers."
        let detected = validator.checkResponse(cleanResponse)
        XCTAssertTrue(detected.isEmpty)
    }

    func testH9_CapabilitiesAndProhibitedMutuallyExclusive() {
        let capabilities = Set(AICapability.allCases.map { $0.rawValue })
        let prohibited = Set(AIProhibitedAction.allCases.map { $0.rawValue })
        XCTAssertTrue(capabilities.isDisjoint(with: prohibited))
    }

    func testH9_IsAllowedAndIsProhibited() {
        let validator = AIBoundaryValidator()
        XCTAssertTrue(validator.isAllowed(.readContext))
        XCTAssertTrue(validator.isAllowed(.suggestCode))
        XCTAssertTrue(validator.isProhibited(.writeFile))
        XCTAssertTrue(validator.isProhibited(.gitPush))
    }
}