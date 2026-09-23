import Foundation
import SiftCore
import Testing

@Test func versionCompareStripsLeadingVAndOrdersNumerically() {
    #expect(SiftVersionCompare.normalize("v0.1.1") == "0.1.1")
    #expect(SiftVersionCompare.normalize("V1.0.0") == "1.0.0")
    #expect(SiftVersionCompare.isRemoteNewer(remote: "0.1.2", local: "0.1.1"))
    #expect(SiftVersionCompare.isRemoteNewer(remote: "v0.2.0", local: "0.1.9"))
    #expect(!SiftVersionCompare.isRemoteNewer(remote: "0.1.1", local: "0.1.1"))
    #expect(!SiftVersionCompare.isRemoteNewer(remote: "0.1.0", local: "0.1.1"))
    #expect(SiftVersionCompare.compare("0.1.10", "0.1.9") == .orderedDescending)
    #expect(SiftVersionCompare.compare("0.1.0", "0.1.0") == .orderedSame)
}

@Test func releasePrefersTheDMG() throws {
    let data = Data("""
    {
      "tag_name": "v0.1.5",
      "name": "Sift 0.1.5",
      "html_url": "https://github.com/Cyberesia/sift/releases/tag/v0.1.5",
      "assets": [
        {
          "name": "Sift-0.1.5.zip",
          "browser_download_url": "https://github.com/Cyberesia/sift/releases/download/v0.1.5/Sift-0.1.5.zip"
        },
        {
          "name": "Sift-0.1.5.dmg",
          "browser_download_url": "https://github.com/Cyberesia/sift/releases/download/v0.1.5/Sift-0.1.5.dmg"
        }
      ]
    }
    """.utf8)
    let release = try SiftGitHubReleaseAPI.decode(data)
    #expect(release.version == "0.1.5")
    #expect(release.preferredDownloadURL.absoluteString.hasSuffix("Sift-0.1.5.dmg"))
}

@Test func releaseWithoutADmgFallsBackToTheReleasePage() throws {
    let data = Data("""
    {
      "tag_name": "v0.1.0",
      "html_url": "https://github.com/Cyberesia/sift/releases/tag/v0.1.0",
      "assets": []
    }
    """.utf8)
    let release = try SiftGitHubReleaseAPI.decode(data)
    #expect(release.preferredDownloadURL.absoluteString == "https://github.com/Cyberesia/sift/releases/tag/v0.1.0")
}
