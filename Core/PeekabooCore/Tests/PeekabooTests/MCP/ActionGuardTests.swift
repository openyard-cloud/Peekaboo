import Foundation
import Testing
@testable import PeekabooAgentRuntime

struct ActionGuardTests {
    let guard_ = ActionGuard()

    @Test(arguments: ["Submit for Review", "Upload", "Distribute App", "Release", "Delete Build", "Roll out", "Sign In"])
    func `consequential labels need the exact label as confirm`(label: String) {
        let refusal = self.guard_.checkClick(label: label, app: "Safari", isCoordinate: false, confirm: nil)
        #expect(refusal?.contains("confirm: \"\(label)\"") == true)
        #expect(self.guard_.checkClick(label: label, app: "Safari", isCoordinate: false, confirm: "something else") != nil)
        #expect(self.guard_.checkClick(label: label, app: "Safari", isCoordinate: false, confirm: label.uppercased()) == nil)
    }

    @Test(arguments: ["Next", "Cancel", "Archive", "Validate App", "Show in Finder", "Resubmission notes"])
    func `ordinary labels pass`(label: String) {
        #expect(self.guard_.checkClick(label: label, app: "Xcode", isCoordinate: false, confirm: nil) == nil)
    }

    @Test
    func `coordinate clicks need confirm only in sensitive apps`() {
        #expect(self.guard_.checkClick(label: nil, app: "Xcode", isCoordinate: true, confirm: nil) != nil)
        #expect(self.guard_.checkClick(label: nil, app: "xcode", isCoordinate: true, confirm: "Distribute App") == nil)
        #expect(self.guard_.checkClick(label: nil, app: "Finder", isCoordinate: true, confirm: nil) == nil)
    }

    @Test
    func `password fields are refused`() {
        #expect(self.guard_.checkTextEntry(role: "AXSecureTextField", roleDescription: nil) != nil)
        #expect(self.guard_.checkTextEntry(role: "AXTextField", roleDescription: "secure text field") != nil)
        #expect(self.guard_.checkTextEntry(role: "AXTextField", roleDescription: "text field") == nil)
    }

    @Test
    func `config can change the words and turn the guard off`() throws {
        let custom = ActionGuard(config: .init(enabled: nil, confirmLabels: ["ship"], sensitiveApps: [], blockSecureFields: false))
        #expect(custom.checkClick(label: "Ship it", app: nil, isCoordinate: false, confirm: nil) != nil)
        #expect(custom.checkClick(label: "Submit", app: nil, isCoordinate: false, confirm: nil) == nil)
        #expect(custom.checkTextEntry(role: "AXSecureTextField", roleDescription: nil) == nil)

        let off = ActionGuard(config: .init(enabled: false, confirmLabels: nil, sensitiveApps: nil, blockSecureFields: nil))
        #expect(off.checkClick(label: "Submit", app: nil, isCoordinate: false, confirm: nil) == nil)
    }

    @Test
    func `a broken config file keeps the defaults`() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("guard-\(UUID().uuidString).json")
        try Data("{ not json".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        #expect(ActionGuard.load(environment: ["PEEKABOO_GUARD_CONFIG": file.path]) == ActionGuard())
    }
}
