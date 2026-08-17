#if DEBUG
import CoreData
import CoreLocation
import Foundation

extension PersistenceController {
    /// Builds an in-memory, CloudKit-free Core Data stack pre-populated with
    /// fixture tracks, for `fastlane snapshot` screenshot automation. Gated
    /// behind `#if DEBUG` so it never compiles into Release/TestFlight builds.
    static func forSnapshotTesting() -> NSPersistentContainer {
        CLLocationArrayTransformer.register()

        let bundle = Bundle(for: PersistenceController.self)
        guard let modelURL = bundle.url(forResource: "TrackPaw", withExtension: "momd") ?? Bundle.main.url(forResource: "TrackPaw", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Failed to load TrackPaw managed object model for snapshot testing")
        }

        // A fresh NSManagedObjectModel instance is required here, not the implicitly
        // shared one NSPersistentContainer(name:) would resolve. This snapshot store
        // and `PersistenceController.shared`'s real CloudKit-backed one can both be
        // instantiated in the same process, and handing a second container a model
        // object already bound to another container's store trips Core Data error
        // 134020 ("model configuration used to open the store is incompatible with
        // the one used to create it").
        let container = NSPersistentContainer(name: "TrackPaw", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            fatalError("Failed to load in-memory snapshot store: \(loadError)")
        }

        seedFixtureTracks(in: container.viewContext)
        return container
    }

    private static func seedFixtureTracks(in context: NSManagedObjectContext) {
        let morningWalk = Track(context: context, name: "Morning walk with Bella", id: UUID())
        morningWalk.comments = "Calm loop around the pond, great for beginners."
        morningWalk.difficulty = 2
        morningWalk.created = Date().addingTimeInterval(-3 * 24 * 60 * 60)
        morningWalk.timeToCreate = 18 * 60
        morningWalk.started = Date().addingTimeInterval(-2 * 24 * 60 * 60)
        morningWalk.timeToFinish = 21 * 60
        morningWalk.length = 950
        morningWalk.state = TrackState.trailTracked.rawValue
        morningWalk.laidPath = [
            CLLocation(latitude: 59.3293, longitude: 18.0686),
            CLLocation(latitude: 59.3296, longitude: 18.0690),
            CLLocation(latitude: 59.3298, longitude: 18.0686),
            CLLocation(latitude: 59.3298, longitude: 18.0680),
            CLLocation(latitude: 59.3296, longitude: 18.0676),
            CLLocation(latitude: 59.3293, longitude: 18.0676),
            CLLocation(latitude: 59.3291, longitude: 18.0680),
            CLLocation(latitude: 59.3291, longitude: 18.0686),
            CLLocation(latitude: 59.3293, longitude: 18.0686)
        ]
        morningWalk.trackPath = morningWalk.laidPath

        let forestScent = Track(context: context, name: "Forest scent trail", id: UUID())
        forestScent.comments = "Longer trail with scent markers hidden in the underbrush."
        forestScent.difficulty = 4
        forestScent.created = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        forestScent.timeToCreate = 32 * 60
        forestScent.started = Date().addingTimeInterval(-6 * 24 * 60 * 60)
        forestScent.timeToFinish = 40 * 60
        forestScent.length = 1800
        forestScent.state = TrackState.trailTracked.rawValue
        forestScent.laidPath = [
            CLLocation(latitude: 59.3350, longitude: 18.0750),
            CLLocation(latitude: 59.3355, longitude: 18.0758),
            CLLocation(latitude: 59.3360, longitude: 18.0755),
            CLLocation(latitude: 59.3363, longitude: 18.0748),
            CLLocation(latitude: 59.3362, longitude: 18.0740),
            CLLocation(latitude: 59.3357, longitude: 18.0735),
            CLLocation(latitude: 59.3350, longitude: 18.0736),
            CLLocation(latitude: 59.3346, longitude: 18.0742),
            CLLocation(latitude: 59.3347, longitude: 18.0748),
            CLLocation(latitude: 59.3350, longitude: 18.0750)
        ]
        forestScent.trackPath = forestScent.laidPath

        do {
            try context.save()
        } catch {
            fatalError("Failed to save snapshot fixtures: \(error)")
        }
    }
}
#endif
