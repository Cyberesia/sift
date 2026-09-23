import Foundation
import SiftCore
import Testing

@Test func preferredDirectoryUsesTheNamedChildWhenTheBookmarkIsTheParent() throws {
    let parent = FileManager.default.temporaryDirectory.appendingPathComponent("sift-parent-\(UUID().uuidString)", isDirectory: true)
    let named = parent.appendingPathComponent("80", isDirectory: true)
    try FileManager.default.createDirectory(at: named, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: parent) }

    let resolved = DestinationStore.preferredDirectory(parent, named: "80")
    #expect(resolved.standardizedFileURL.path == named.standardizedFileURL.path)

    let alreadyNamed = DestinationStore.preferredDirectory(named, named: "80")
    #expect(alreadyNamed.standardizedFileURL.path == named.standardizedFileURL.path)
}

@Test func transferWritesInsideTheNamedFolder() async throws {
    let parent = FileManager.default.temporaryDirectory.appendingPathComponent("sift-xfer-\(UUID().uuidString)", isDirectory: true)
    let destination = parent.appendingPathComponent("80", isDirectory: true)
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: parent) }
    let source = parent.appendingPathComponent("shot.jpg")
    try Data("photo".utf8).write(to: source)

    let copied = try await FileTransferCoordinator().transfer(
        from: source,
        to: destination,
        folderName: "Photos",
        mode: .copy
    )
    #expect(copied.standardizedFileURL.path.hasPrefix(destination.standardizedFileURL.path + "/"))
    #expect(FileManager.default.fileExists(atPath: source.path))
    #expect(!FileManager.default.fileExists(atPath: parent.appendingPathComponent("Photos").appendingPathComponent("shot.jpg").path))
}

@Test func transferRefusesToClimbOutOfTheDestination() async throws {
    let parent = FileManager.default.temporaryDirectory.appendingPathComponent("sift-climb-\(UUID().uuidString)", isDirectory: true)
    let destination = parent.appendingPathComponent("80", isDirectory: true)
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: parent) }
    let source = parent.appendingPathComponent("shot.jpg")
    try Data("photo".utf8).write(to: source)

    await #expect(throws: FileTransferError.self) {
        try await FileTransferCoordinator().transfer(
            from: source,
            to: destination,
            folderName: "..",
            mode: .copy
        )
    }
}

@Test func filingSeparatesCopiesInsideTheFolderFromOriginals() {
    let summary = CatalogFilingClassifier.summarize(
        files: [
            CatalogFile(id: "copy", path: "/Volumes/disk/80/Photos/shot.jpg", contentHash: "abc"),
            CatalogFile(id: "origin", path: "/Users/me/Downloads/shot.jpg", contentHash: "abc"),
            CatalogFile(id: "new", path: "/Users/me/Downloads/other.jpg", contentHash: "def"),
        ],
        destinationRoots: ["/Volumes/disk/80"],
        transfers: [
            CatalogTransfer(
                sourcePath: "/Users/me/Downloads/shot.jpg",
                destinationPath: "/Volumes/disk/80/Photos/shot.jpg"
            ),
        ]
    )
    #expect(summary.inDestination == 1)
    #expect(summary.stillAtOrigin == 1)
    #expect(summary.untouched == 1)
    #expect(summary.filedOutside == 0)
    #expect(summary.line(folderName: "80").contains("already inside"))
    #expect(summary.line(folderName: "80").contains("original"))
}

@Test func filingNoticesCopiesThatLandedBesideTheDestination() {
    let summary = CatalogFilingClassifier.summarize(
        files: [
            CatalogFile(id: "copy", path: "/Volumes/disk/Photos/shot.jpg", contentHash: "abc"),
            CatalogFile(id: "origin", path: "/Users/me/Downloads/shot.jpg", contentHash: "abc"),
        ],
        destinationRoots: ["/Volumes/disk/80"],
        transfers: [
            CatalogTransfer(
                sourcePath: "/Users/me/Downloads/shot.jpg",
                destinationPath: "/Volumes/disk/Photos/shot.jpg"
            ),
        ]
    )
    #expect(summary.filedOutside == 1)
    #expect(summary.stillAtOrigin == 1)
    #expect(summary.inDestination == 0)
    #expect(summary.line(folderName: "80").contains("next to"))
}

@Test func organizePlanSkipsFilesAlreadyFiled() {
    let plan = OrganizePlanner.preview(
        candidates: [
            OrganizeCandidate(id: "inside", path: "/Volumes/disk/80/Photos/a.jpg", pipelineName: "Photography"),
            OrganizeCandidate(id: "origin", path: "/Users/me/Downloads/a.jpg", pipelineName: "Photography"),
            OrganizeCandidate(id: "fresh", path: "/Users/me/Downloads/b.jpg", pipelineName: "Photography"),
        ],
        inDestinationPaths: [CatalogFilingClassifier.normalize("/Volumes/disk/80/Photos/a.jpg")],
        originPaths: [CatalogFilingClassifier.normalize("/Users/me/Downloads/a.jpg")]
    )
    #expect(plan.first { $0.id == "inside" }?.blocked == true)
    #expect(plan.first { $0.id == "origin" }?.blocked == true)
    #expect(plan.first { $0.id == "fresh" }?.blocked == false)
    #expect(plan.first { $0.id == "fresh" }?.proposedFolder == "Photos")
}

@Test func scanActivityNamesTheSelectedKinds() {
    #expect(ScanActivityCopy.lookingFor([.audio]) == "Looking for audio…")
    #expect(ScanActivityCopy.lookingFor([.audio, .image]) == "Looking for photos and audio…")
}
