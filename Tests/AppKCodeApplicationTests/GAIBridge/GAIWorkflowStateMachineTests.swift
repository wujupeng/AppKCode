import XCTest
@testable import AppKCodeShared
@testable import AppKCodeDomain
@testable import AppKCodeApplication

// MARK: - GAIWorkflowPhase State Machine Tests (M11-P1-TASK-004)

final class GAIWorkflowStateMachineTests: XCTestCase {

    // MARK: - Phase Transition Tests

    func testPhaseNext_specReturnsDesign() {
        XCTAssertEqual(GAIWorkflowPhase.spec.next(), .design)
    }

    func testPhaseNext_designReturnsTask() {
        XCTAssertEqual(GAIWorkflowPhase.design.next(), .task)
    }

    func testPhaseNext_taskReturnsImplementation() {
        XCTAssertEqual(GAIWorkflowPhase.task.next(), .implementation)
    }

    func testPhaseNext_implementationReturnsTest() {
        XCTAssertEqual(GAIWorkflowPhase.implementation.next(), .test)
    }

    func testPhaseNext_testReturnsEvidence() {
        XCTAssertEqual(GAIWorkflowPhase.test.next(), .evidence)
    }

    func testPhaseNext_evidenceReturnsReview() {
        XCTAssertEqual(GAIWorkflowPhase.evidence.next(), .review)
    }

    func testPhaseNext_reviewReturnsGate() {
        XCTAssertEqual(GAIWorkflowPhase.review.next(), .gate)
    }

    func testPhaseNext_gateReturnsNil() {
        XCTAssertNil(GAIWorkflowPhase.gate.next())
    }

    // MARK: - Phase isHighRisk Tests

    func testPhaseIsHighRisk_implementationIsTrue() {
        XCTAssertTrue(GAIWorkflowPhase.implementation.isHighRisk)
    }

    func testPhaseIsHighRisk_specIsFalse() {
        XCTAssertFalse(GAIWorkflowPhase.spec.isHighRisk)
    }

    func testPhaseIsHighRisk_designIsFalse() {
        XCTAssertFalse(GAIWorkflowPhase.design.isHighRisk)
    }

    func testPhaseIsHighRisk_taskIsFalse() {
        XCTAssertFalse(GAIWorkflowPhase.task.isHighRisk)
    }

    func testPhaseIsHighRisk_testIsFalse() {
        XCTAssertFalse(GAIWorkflowPhase.test.isHighRisk)
    }

    func testPhaseIsHighRisk_evidenceIsFalse() {
        XCTAssertFalse(GAIWorkflowPhase.evidence.isHighRisk)
    }

    func testPhaseIsHighRisk_reviewIsFalse() {
        XCTAssertFalse(GAIWorkflowPhase.review.isHighRisk)
    }

    func testPhaseIsHighRisk_gateIsFalse() {
        XCTAssertFalse(GAIWorkflowPhase.gate.isHighRisk)
    }

    // MARK: - Status isTerminal Tests

    func testStatusIsTerminal_pendingIsFalse() {
        XCTAssertFalse(GAIWorkflowStatus.pending.isTerminal)
    }

    func testStatusIsTerminal_inProgressIsFalse() {
        XCTAssertFalse(GAIWorkflowStatus.inProgress.isTerminal)
    }

    func testStatusIsTerminal_awaitingApprovalIsFalse() {
        XCTAssertFalse(GAIWorkflowStatus.awaitingApproval.isTerminal)
    }

    func testStatusIsTerminal_completedIsTrue() {
        XCTAssertTrue(GAIWorkflowStatus.completed.isTerminal)
    }

    func testStatusIsTerminal_rejectedIsTrue() {
        XCTAssertTrue(GAIWorkflowStatus.rejected.isTerminal)
    }

    func testStatusIsTerminal_cancelledIsTrue() {
        XCTAssertTrue(GAIWorkflowStatus.cancelled.isTerminal)
    }

    // MARK: - Full Workflow Transition Sequence Tests

    func testFullWorkflowPhaseSequence() {
        let phases: [GAIWorkflowPhase] = [
            .spec, .design, .task, .implementation, .test, .evidence, .review, .gate
        ]

        for i in 0..<(phases.count - 1) {
            XCTAssertEqual(phases[i].next(), phases[i + 1],
                           "Phase \(phases[i].rawValue) should transition to \(phases[i + 1].rawValue)")
        }

        XCTAssertNil(phases.last!.next(), "Gate phase should have no next phase")
    }

    func testCaseIterablePhasesCount() {
        let allPhases = GAIWorkflowPhase.allCases
        XCTAssertEqual(allPhases.count, 8)
    }

    func testCaseIterableStatusesCount() {
        let allStatuses = GAIWorkflowStatus.allCases
        XCTAssertEqual(allStatuses.count, 6)
    }

    // MARK: - GAIWorkflowTaskID Tests

    func testTaskID_isHashableAndEquatable() {
        let id1 = GAIWorkflowTaskID()
        let id2 = GAIWorkflowTaskID()
        let id3 = id1

        XCTAssertNotEqual(id1, id2)
        XCTAssertEqual(id1, id3)

        let dict: [GAIWorkflowTaskID: String] = [id1: "task1"]
        XCTAssertEqual(dict[id1], "task1")
        XCTAssertNil(dict[id2])
    }

    // MARK: - GAIWorkflowEvidence Tests

    func testEvidence_constructionAndEquality() {
        let evidence1 = GAIWorkflowEvidence(
            phase: .spec,
            evidenceType: "test",
            payload: "payload1"
        )

        let evidence2 = GAIWorkflowEvidence(
            phase: .spec,
            evidenceType: "test",
            payload: "payload1",
            timestamp: evidence1.timestamp
        )

        XCTAssertEqual(evidence1, evidence2)
        XCTAssertEqual(evidence1.phase, .spec)
        XCTAssertEqual(evidence1.evidenceType, "test")
        XCTAssertEqual(evidence1.payload, "payload1")
    }

    // MARK: - GateResult Tests

    func testGateResult_passVerdict() {
        let result = GateResult(verdict: .pass_, summary: "All checks passed")
        XCTAssertEqual(result.verdict, .pass_)
        XCTAssertEqual(result.summary, "All checks passed")
    }

    func testGateResult_failVerdict() {
        let result = GateResult(verdict: .fail, summary: "Checks failed")
        XCTAssertEqual(result.verdict, .fail)
        XCTAssertEqual(result.summary, "Checks failed")
    }

    func testGateResult_verdictRawValues() {
        XCTAssertEqual(GateResult.Verdict.pass_.rawValue, "pass_")
        XCTAssertEqual(GateResult.Verdict.fail.rawValue, "fail")
    }

    // MARK: - GAIWorkflowState Tests

    func testState_constructionWithDefaults() {
        let sessionID = AgentSessionID()
        let taskID = GAIWorkflowTaskID()
        let state = GAIWorkflowState(
            sessionID: sessionID,
            taskID: taskID,
            currentPhase: .spec
        )

        XCTAssertEqual(state.sessionID, sessionID)
        XCTAssertEqual(state.taskID, taskID)
        XCTAssertEqual(state.currentPhase, .spec)
        XCTAssertEqual(state.status, .pending)
        XCTAssertEqual(state.stepsTaken, 0)
        XCTAssertTrue(state.evidenceChain.isEmpty)
        XCTAssertNil(state.gateResult)
    }

    func testState_constructionWithAllParameters() {
        let sessionID = AgentSessionID()
        let taskID = GAIWorkflowTaskID()
        let evidence = GAIWorkflowEvidence(phase: .spec, evidenceType: "test", payload: "payload")
        let gateResult = GateResult(verdict: .pass_, summary: "passed")

        let state = GAIWorkflowState(
            sessionID: sessionID,
            taskID: taskID,
            currentPhase: .implementation,
            status: .awaitingApproval,
            evidenceChain: [evidence],
            gateResult: gateResult,
            stepsTaken: 3
        )

        XCTAssertEqual(state.sessionID, sessionID)
        XCTAssertEqual(state.taskID, taskID)
        XCTAssertEqual(state.currentPhase, .implementation)
        XCTAssertEqual(state.status, .awaitingApproval)
        XCTAssertEqual(state.stepsTaken, 3)
        XCTAssertEqual(state.evidenceChain.count, 1)
        XCTAssertEqual(state.gateResult?.verdict, .pass_)
    }

    // MARK: - GAIWorkflowTask Tests

    func testTask_constructionWithDefaults() {
        let task = GAIWorkflowTask(
            phase: .spec,
            userRequest: "request",
            contextRequest: "context",
            maxSteps: 5
        )

        XCTAssertEqual(task.phase, .spec)
        XCTAssertEqual(task.userRequest, "request")
        XCTAssertEqual(task.contextRequest, "context")
        XCTAssertEqual(task.maxSteps, 5)
    }

    func testTask_constructionWithExplicitID() {
        let taskID = GAIWorkflowTaskID()
        let task = GAIWorkflowTask(
            id: taskID,
            phase: .design,
            userRequest: "request",
            contextRequest: "context",
            maxSteps: 10
        )

        XCTAssertEqual(task.id, taskID)
        XCTAssertEqual(task.phase, .design)
    }

    // MARK: - H28-1 Verification: State Machine Completeness

    func testH28_1_stateMachineCoversAllPhases() {
        let allPhases = GAIWorkflowPhase.allCases
        let reachablePhases: Set<GAIWorkflowPhase> = [.spec]

        var current: Set<GAIWorkflowPhase> = reachablePhases
        var allReachable = reachablePhases

        while !current.isEmpty {
            var nextSet: Set<GAIWorkflowPhase> = []
            for phase in current {
                if let next = phase.next() {
                    nextSet.insert(next)
                }
            }
            allReachable = allReachable.union(nextSet)
            current = nextSet
        }

        XCTAssertEqual(allReachable.count, allPhases.count,
                       "All phases should be reachable from .spec via next()")
    }

    func testH28_1_stateMachineHasSingleTerminalPhase() {
        let terminalPhases = GAIWorkflowPhase.allCases.filter { $0.next() == nil }
        XCTAssertEqual(terminalPhases.count, 1)
        XCTAssertEqual(terminalPhases.first, .gate)
    }

    func testH28_1_stateMachineHasSingleHighRiskPhase() {
        let highRiskPhases = GAIWorkflowPhase.allCases.filter { $0.isHighRisk }
        XCTAssertEqual(highRiskPhases.count, 1)
        XCTAssertEqual(highRiskPhases.first, .implementation)
    }

    func testH28_1_stateMachineTerminalStatusesAreTerminal() {
        let terminalStatuses: [GAIWorkflowStatus] = [.completed, .rejected, .cancelled]
        for status in terminalStatuses {
            XCTAssertTrue(status.isTerminal, "\(status.rawValue) should be terminal")
        }
    }

    func testH28_1_stateMachineNonTerminalStatusesAreNotTerminal() {
        let nonTerminalStatuses: [GAIWorkflowStatus] = [.pending, .inProgress, .awaitingApproval]
        for status in nonTerminalStatuses {
            XCTAssertFalse(status.isTerminal, "\(status.rawValue) should not be terminal")
        }
    }
}