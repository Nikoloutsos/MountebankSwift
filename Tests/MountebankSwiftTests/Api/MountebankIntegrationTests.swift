import XCTest
@testable import MountebankSwift

final class MountebankIntegrationTests: XCTestCase {

    private var sut: Mountebank!

    override func setUp() async throws {
        sut = Mountebank(host: .localhost, port: 2525)

        do {
            try await sut.testConnection()
        } catch {
            XCTFail("Mountebank needs to be running to run the tests. Start with `mb start`")
        }
    }

    override func tearDown() async throws {
        _ = try await sut.deleteAllImposters()

        sut = nil
    }

    func testGettingLogs() async throws {
        let logsResponse = try await sut.getLogs()

        XCTAssertGreaterThan(logsResponse.logs.count, 0)
    }

    func testGettingConfig() async throws {
        let config = try await sut.getConfig()

        XCTAssertGreaterThan(config.version.count, 0)
    }

    func testUpdatingStub() async throws {
        let port = try await postDefaultImposter()
        let updatedImposterResult = try await sut.postImposterStub(addStub: AddStub.injectBody, port: port)

        XCTAssertEqual(updatedImposterResult.stubs.count, 2)
        XCTAssertEqual(updatedImposterResult.stubs.first, Stub.httpResponse200)
        XCTAssertEqual(updatedImposterResult.stubs.last, Stub.injectBody)
    }

    func testUpdatingImposter() async throws {
        let port = try await postDefaultImposter()
        let updatedImposterResult = try await sut.putImposterStubs(
            imposter: Imposter.exampleAllvariants,
            port: port
        )

        XCTAssertEqual(updatedImposterResult.stubs.count, 5)
        XCTAssertEqual(updatedImposterResult.stubs.first, Stub.httpResponse200)
        XCTAssertEqual(updatedImposterResult.stubs.last, Stub.connectionResetByPeer)
    }

    func testGetAllImposters() async throws {
        let port = try await postDefaultImposter()
        let allImposters = try await sut.getImposter(port: port)

        XCTAssertEqual(allImposters.stubs.count, 1)
        XCTAssertEqual(allImposters.port, port)
    }

    func testDeleteAllImposters() async throws {
        let port = try await postDefaultImposter()
        _ = try await sut.deleteAllImposters()
        let allImposters = try await sut.getAllImposters()

        XCTAssertEqual(allImposters.imposters.count, 0)
    }

    func testDeleteSavedProxyResponses() async throws {
        let imposterResult = try await sut.postImposter(imposter: Imposter(
            port: nil,
            scheme: .https,
            name: "Imposter with proxy",
            stubs: [
                Stub.proxy,
            ]
        ))
        guard let port = imposterResult.port else {
            XCTFail("Port should have been set by now.")
            return
        }

        let response = try await sut.deleteSavedProxyResponses(port: port)

        XCTAssertEqual(response.stubs.count, 1)
    }

    private func postDefaultImposter() async throws -> Int {
        let imposterResult = try await sut.postImposter(imposter: Imposter.exampleSingleStub)
        guard let port = imposterResult.port else {
            XCTFail("Port should have been set by now.")
            return 0
        }

        return port
    }
}