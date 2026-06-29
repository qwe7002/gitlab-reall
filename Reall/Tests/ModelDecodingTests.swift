import XCTest
@testable import Reall

final class ModelDecodingTests: XCTestCase {

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            if let date = formatter.date(from: value) ?? fallback.date(from: value) { return date }
            throw DecodingError.dataCorruptedError(in: try decoder.singleValueContainer(),
                                                   debugDescription: "bad date")
        }
        return decoder
    }

    func testDecodeProject() throws {
        let json = """
        {
          "id": 42,
          "name": "reall",
          "name_with_namespace": "qwe7002 / reall",
          "path": "reall",
          "path_with_namespace": "qwe7002/reall",
          "description": "A GitLab client",
          "star_count": 7,
          "forks_count": 2,
          "open_issues_count": 3,
          "visibility": "public",
          "default_branch": "main",
          "last_activity_at": "2026-06-29T10:00:00.000Z"
        }
        """.data(using: .utf8)!
        let project = try makeDecoder().decode(GitLabProject.self, from: json)
        XCTAssertEqual(project.id, 42)
        XCTAssertEqual(project.starCount, 7)
        XCTAssertEqual(project.defaultBranch, "main")
        XCTAssertNotNil(project.lastActivityAt)
    }

    func testDecodeIssue() throws {
        let json = """
        {
          "id": 1, "iid": 12, "project_id": 42,
          "title": "Fix bug", "state": "opened",
          "labels": ["bug", "p1"],
          "user_notes_count": 4,
          "created_at": "2026-06-01T08:00:00Z",
          "references": { "full": "qwe7002/reall#12" }
        }
        """.data(using: .utf8)!
        let issue = try makeDecoder().decode(GitLabIssue.self, from: json)
        XCTAssertTrue(issue.isOpen)
        XCTAssertEqual(issue.labels, ["bug", "p1"])
        XCTAssertEqual(issue.reference, "qwe7002/reall#12")
    }

    func testMergeRequestDisplayState() throws {
        let json = """
        {
          "id": 1, "iid": 5, "project_id": 42,
          "title": "WIP feature", "state": "opened",
          "draft": true, "labels": []
        }
        """.data(using: .utf8)!
        let mr = try makeDecoder().decode(GitLabMergeRequest.self, from: json)
        XCTAssertEqual(mr.displayState, .draft)
    }

    func testCIStatusMapping() {
        XCTAssertEqual(CIStatus("success"), .success)
        XCTAssertTrue(CIStatus("running").isActive)
        XCTAssertFalse(CIStatus("failed").isActive)
        XCTAssertEqual(CIStatus("waiting_for_resource").label, "Waiting")
    }
}
