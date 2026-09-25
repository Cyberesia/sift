import Foundation
@testable import SiftCore
import Testing

@Test func parserKeepsJPGAndExcludesPNG() {
    let command = AssistantParser.parse(
        "range les jpg de 100LEICA dans Photos, laisse les png",
        knownExtensions: ["jpg", "png"],
        sources: ["100LEICA"],
        folders: FileTransferCoordinator.suggestedCatalogFolders
    )
    #expect(command.included == ["jpg"])
    #expect(command.excluded == ["png"])
    #expect(command.sourceLabel == "100LEICA")
    #expect(command.folder == "Photos")
}

@Test func offlineClassifierChoosesTypePlan() {
    let command = AssistantParser.parse(
        "range les jpg dans Photos, laisse les png",
        knownExtensions: ["jpg", "png"],
        folders: FileTransferCoordinator.suggestedCatalogFolders
    )
    let result = AssistantOfflineClassifier.classify("range les jpg dans Photos, laisse les png", command: command)
    #expect(result.value == .organizeByType)
    #expect(result.confidence >= AssistantDecide.inputBelow)
}

@Test func catalogCompositionSortsExtensionsByCount() {
    let files = [
        CompositionFile(id: "1", sourceLabel: "100LEICA", fileExtension: "png", kind: .image),
        CompositionFile(id: "2", sourceLabel: "100LEICA", fileExtension: "jpg", kind: .image),
        CompositionFile(id: "3", sourceLabel: "100LEICA", fileExtension: "jpg", kind: .image, isAnalyzed: false),
    ]
    let composition = CatalogComposition.make(sourceLabel: "100LEICA", files: files)
    #expect(composition.extensions.map(\.fileExtension) == ["jpg", "png"])
    #expect(composition.extensions.first?.count == 2)
    #expect(composition.unanalyzed == 1)
}

@Test func sliceIncludesJPGButNotPNG() {
    let slice = CatalogSlice(sourceLabel: "100LEICA", includedExtensions: ["jpg"], excludedExtensions: ["png"])
    #expect(slice.contains(CompositionFile(id: "1", sourceLabel: "100LEICA", fileExtension: "JPG", kind: .image)))
    #expect(!slice.contains(CompositionFile(id: "2", sourceLabel: "100LEICA", fileExtension: "png", kind: .image)))
    #expect(!slice.contains(CompositionFile(id: "3", sourceLabel: "Desktop", fileExtension: "jpg", kind: .image)))
}

@Test func contentPlanHoldsIncompleteEvidence() {
    let candidates = [
        OrganizeCandidate(
            id: "ready", path: "/Users/me/ready.jpg", pipelineName: "Photography",
            sourceLabel: "Photos", kind: .image, fileExtension: "jpg", evidenceComplete: true
        ),
        OrganizeCandidate(
            id: "waiting", path: "/Users/me/waiting.jpg", pipelineName: "Photography",
            sourceLabel: "Photos", kind: .image, fileExtension: "jpg", evidenceComplete: false
        ),
    ]
    let plan = OrganizePlanner.preview(
        candidates: candidates,
        rule: OrganizePlanRule(intent: .organizeByContent, destinationFolder: "Photos")
    )
    #expect(plan.first { $0.id == "ready" }?.blocked == false)
    #expect(plan.first { $0.id == "waiting" }?.blockReason == "Content evidence is not ready")
}

@Test func datePlanBuildsASafeNestedMonthFolder() throws {
    let date = try #require(Calendar(identifier: .gregorian).date(from: DateComponents(year: 2024, month: 7, day: 14)))
    let plan = OrganizePlanner.preview(
        candidates: [
            OrganizeCandidate(
                id: "a", path: "/Users/me/a.jpg", pipelineName: "Photography",
                sourceLabel: "Photos", kind: .image, fileExtension: "jpg", date: date
            ),
        ],
        rule: OrganizePlanRule(intent: .organizeByDate, destinationFolder: "Photos", grouping: .month)
    )
    #expect(plan.first?.proposedFolder == "Photos/2024-07")
    #expect(try FileTransferCoordinator.sanitizedFolderPath(plan.first?.proposedFolder ?? "") == "Photos/2024-07")
}

@Test func datePlanHoldsAFileWithoutADate() {
    let plan = OrganizePlanner.preview(
        candidates: [
            OrganizeCandidate(
                id: "a", path: "/Users/me/a.jpg", pipelineName: "Photography",
                sourceLabel: "Photos", kind: .image, fileExtension: "jpg", date: nil
            ),
        ],
        rule: OrganizePlanRule(intent: .organizeByDate, destinationFolder: "Photos", grouping: .month)
    )
    #expect(plan.first?.blockReason == "No reliable date is available")
}

@Test func undoneSuggestionIsHeldNextTime() {
    let plan = OrganizePlanner.preview(candidates: [
        OrganizeCandidate(
            id: "a", path: "/Users/me/a.jpg", pipelineName: "Photography",
            sourceLabel: "Photos", kind: .image, fileExtension: "jpg", undoneFolder: "Photos"
        ),
    ])
    #expect(plan.first?.blocked == true)
    #expect(plan.first?.blockReason == "You undid this filing suggestion")
}

@Test func committedIntentNeedsTwoChallengerWins() {
    var memory = AssistantDecide.force(.scan, text: "scan this Mac")
    memory.ui = .committed(.scan, forced: false)
    let challenger = AssistantResult(probabilities: [.organizeByType: 0.65, .scan: 0.3])
    memory = AssistantDecide.decide(memory, result: challenger, text: "organize jpg")
    #expect(memory.ui == .committed(.scan, forced: false))
    memory = AssistantDecide.decide(memory, result: challenger, text: "organize jpg")
    #expect(memory.ui.activeIntent == .organizeByType)
}

@Test func planIntentSwitchesToAnotherPlanIntentAtOnce() {
    var memory = AssistantMemory()
    memory.ui = .committed(.organizeByType, forced: false)
    let byDate = AssistantResult(probabilities: [.organizeByDate: 0.7, .organizeByType: 0.2])
    memory = AssistantDecide.decide(memory, result: byDate, text: "organize by date")
    #expect(memory.ui.activeIntent == .organizeByDate)
}

@Test func findRequestSearchesTheCatalogInsteadOfScanning() {
    let command = AssistantParser.parse("find pictures with dogs")
    #expect(command.searchTerms == ["dogs"])
    #expect(command.kinds == [.image])
    let result = AssistantOfflineClassifier.classify("find pictures with dogs", command: command)
    #expect(result.value == .find)
    #expect(AssistantDecide.rawState(result) == .committed(.find, forced: false))
}

@Test func frenchFindRequestKeepsTheSubject() {
    let command = AssistantParser.parse("montre moi les photos de chiens")
    #expect(command.searchTerms == ["chiens"])
    #expect(AssistantOfflineClassifier.classify("montre moi les photos de chiens", command: command).value == .find)
}

@Test func bareSubjectStillGetsAnAnswer() {
    let command = AssistantParser.parse("sunset beach")
    #expect(AssistantOfflineClassifier.classify("sunset beach", command: command).value == .find)
}

@Test func scanNeedsScanWords() {
    let command = AssistantParser.parse("scan this Mac")
    #expect(AssistantOfflineClassifier.classify("scan this Mac", command: command).value == .scan)
}

@Test func pluralTermsAlsoTrySingularLabels() {
    #expect(AssistantFindResult.variants(of: "dogs") == ["dogs", "dog"])
    #expect(AssistantFindResult.variants(of: "puppies").contains("puppy"))
    #expect(AssistantFindResult.variants(of: "cat") == ["cat"])
}

@Test func findResultSaysWhetherHitsAreRealMatches() {
    #expect(AssistantFindResult(query: "dogs", hits: [], labeledCount: 0, searching: false).match == .nothing)
    #expect(AssistantFindResult(query: "dogs", hits: [], labeledCount: 3, searching: false).match == .labeled)
}

@Test func organizeBlockerFollowsPageStepOrder() {
    #expect(OrganizeBlocker.first(hasDestination: false, transferChosen: false) == .destination)
    #expect(OrganizeBlocker.first(hasDestination: false, transferChosen: true) == .destination)
    #expect(OrganizeBlocker.first(hasDestination: true, transferChosen: false) == .transferChoice)
    #expect(OrganizeBlocker.first(hasDestination: true, transferChosen: true) == nil)
    #expect(OrganizeBlocker.destination.step == 1)
    #expect(OrganizeBlocker.transferChoice.step == 2)
}

@Test func jevFanoutDecodesChoiceScoreAndNoul() throws {
    let data = try JSONSerialization.data(withJSONObject: [
        "answers": [
            "intent": [
                "value": "organizeByType",
                "confidence": 0.82,
                "probabilities": ["organizeByType": 0.82, "slice": 0.1, "none": 0.08],
            ],
            "readiness": ["score": 2],
            "needsReview": ["noul": 0.1],
        ],
    ])
    let result = try JevClient.decodeAssistant(data)
    #expect(result.value == .organizeByType)
    #expect(result.readiness == 1)
    #expect(result.engine == "jev")
}
