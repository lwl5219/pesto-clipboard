import CoreData
import AppKit

@objc(ClipboardItemContent)
public class ClipboardItemContent: NSManagedObject {
    @NSManaged public var type: String      // Pasteboard type (UTI), e.g., "public.tiff", "public.png"
    @NSManaged public var value: Data?      // Binary data (uses external storage for large blobs)
    @NSManaged public var order: Int16      // Original order from pasteboard (preserves source app's preferred order)
    @NSManaged public var item: ClipboardItem?

    // MARK: - Factory Method

    static func create(
        in context: NSManagedObjectContext,
        type: String,
        value: Data?,
        order: Int16,
        item: ClipboardItem
    ) -> ClipboardItemContent {
        let content = ClipboardItemContent(context: context)
        content.type = type
        content.value = value
        content.order = order
        content.item = item
        return content
    }

    // MARK: - Convenience

    var pasteboardType: NSPasteboard.PasteboardType {
        NSPasteboard.PasteboardType(type)
    }

    var dataSize: Int {
        value?.count ?? 0
    }
}
