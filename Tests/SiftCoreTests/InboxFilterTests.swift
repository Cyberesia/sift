import SiftCore
import Foundation
import Testing

@Test func inboxAssetUnderSourceNotDestination() {
    let source = URL(fileURLWithPath: "/Users/me/PhotosInbox")
    let dest = URL(fileURLWithPath: "/Users/me/Organized")
    let asset = URL(fileURLWithPath: "/Users/me/PhotosInbox/2024/img.jpg")

    #expect(
        InboxFilter.isInbox(
            assetURL: asset,
            sourceRoots: [source],
            destinationRoot: dest
        )
    )
}

@Test func inboxExcludesFilesAlreadyInDestination() {
    let source = URL(fileURLWithPath: "/Users/me/Inbox")
    let dest = URL(fileURLWithPath: "/Users/me/Organized")
    let asset = URL(fileURLWithPath: "/Users/me/Organized/Photos/img.jpg")

    #expect(
        !InboxFilter.isInbox(
            assetURL: asset,
            sourceRoots: [source],
            destinationRoot: dest
        )
    )
}

@Test func inboxRequiresSourceRootWhenRootsProvided() {
    let source = URL(fileURLWithPath: "/Users/me/Inbox")
    let asset = URL(fileURLWithPath: "/Users/other/photo.jpg")

    #expect(
        !InboxFilter.isInbox(
            assetURL: asset,
            sourceRoots: [source],
            destinationRoot: nil
        )
    )
}
