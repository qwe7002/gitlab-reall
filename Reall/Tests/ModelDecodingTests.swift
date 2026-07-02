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

    func testDecodeTodoWithMergeRequestTarget() throws {
        let json = """
        {
          "id": 102,
          "action_name": "marked",
          "target_type": "MergeRequest",
          "target_url": "https://gitlab.com/qwe7002/servercase/-/merge_requests/9",
          "body": "feat(probe): bake the installer into the binary",
          "state": "pending",
          "created_at": "2026-06-29T04:00:00.000Z",
          "project": {
            "id": 7,
            "name": "servercase",
            "name_with_namespace": "qwe7002 / servercase",
            "path_with_namespace": "qwe7002/servercase"
          },
          "target": {
            "id": 900, "iid": 9, "project_id": 7,
            "title": "Bake the installer into the binary",
            "state": "opened", "labels": []
          }
        }
        """.data(using: .utf8)!
        let todo = try makeDecoder().decode(GitLabTodo.self, from: json)
        XCTAssertTrue(todo.isUnread)
        XCTAssertEqual(todo.reference, "qwe7002/servercase #9")
        XCTAssertEqual(todo.title, "Bake the installer into the binary")
        XCTAssertNotNil(todo.mergeRequest)
        XCTAssertNil(todo.issue)
        if case .mergeRequest = todo.route {} else { XCTFail("expected merge request route") }
    }

    func testDecodeTodoTolueratesUnknownTarget() throws {
        // A target shape we can't model shouldn't drop the whole row.
        let json = """
        {
          "id": 5, "action_name": "mentioned",
          "target_type": "DesignManagement::Design",
          "state": "pending",
          "project": { "id": 1, "path_with_namespace": "qwe7002/x" },
          "target": { "unexpected": true }
        }
        """.data(using: .utf8)!
        let todo = try makeDecoder().decode(GitLabTodo.self, from: json)
        XCTAssertNil(todo.route)
        XCTAssertEqual(todo.reference, "qwe7002/x")
    }

    func testMarkdownParserSplitsBlocks() {
        let md = """
        # Title
        Intro with **bold**.

        - one
        - two

        ```
        code line
        ```

        > a quote
        """
        let blocks = MarkdownParser.parse(md)
        XCTAssertEqual(blocks.first, .heading(level: 1, text: "Title"))
        XCTAssertTrue(blocks.contains(.paragraph("Intro with **bold**.")))
        XCTAssertTrue(blocks.contains(.unorderedList(["one", "two"])))
        XCTAssertTrue(blocks.contains(.codeBlock("code line")))
        XCTAssertTrue(blocks.contains(.quote("a quote")))
    }

    func testMarkdownParserRuleIsNotAList() {
        // "---" must be a horizontal rule, not an unordered list item.
        XCTAssertEqual(MarkdownParser.parse("---"), [.rule])
    }

    func testPipelineShortSHA() {
        let json = """
        { "id": 3, "status": "success", "sha": "0123456789abcdef" }
        """.data(using: .utf8)!
        let pipeline = try! makeDecoder().decode(GitLabPipeline.self, from: json)
        XCTAssertEqual(pipeline.shortSHA, "01234567")
    }

    func testCIStatusMapping() {
        XCTAssertEqual(CIStatus("success"), .success)
        XCTAssertTrue(CIStatus("running").isActive)
        XCTAssertFalse(CIStatus("failed").isActive)
        XCTAssertEqual(CIStatus("waiting_for_resource").label, "Waiting")
    }
}
