import ClockKit
import SwiftUI

/// Provides complications for the watch face
class ComplicationController: NSObject, CLKComplicationDataSource {
    
    // MARK: - Complication Configuration
    
    func getComplicationDescriptors(handler: @escaping ([CLKComplicationDescriptor]) -> Void) {
        let descriptors = [
            CLKComplicationDescriptor(
                identifier: "com.ramble.record",
                displayName: "Ramble",
                supportedFamilies: [
                    .circularSmall,
                    .modularSmall,
                    .utilitarianSmall,
                    .graphicCircular,
                    .graphicCorner
                ]
            )
        ]
        handler(descriptors)
    }
    
    // MARK: - Timeline Configuration
    
    func getTimelineEndDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        // Static complication - no timeline needed
        handler(nil)
    }
    
    func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
        // Show complication even when device is locked
        handler(.showOnLockScreen)
    }
    
    // MARK: - Current Timeline Entry
    
    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        let template = makeTemplate(for: complication.family)
        if let template = template {
            let entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
            handler(entry)
        } else {
            handler(nil)
        }
    }
    
    // MARK: - Placeholder Templates
    
    func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        handler(makeTemplate(for: complication.family))
    }
    
    // MARK: - Template Creation
    
    private func makeTemplate(for family: CLKComplicationFamily) -> CLKComplicationTemplate? {
        switch family {
        case .circularSmall:
            return CLKComplicationTemplateCircularSmallSimpleImage(
                imageProvider: CLKImageProvider(onePieceImage: UIImage(systemName: "mic.fill")!)
            )
            
        case .modularSmall:
            return CLKComplicationTemplateModularSmallSimpleImage(
                imageProvider: CLKImageProvider(onePieceImage: UIImage(systemName: "mic.fill")!)
            )
            
        case .utilitarianSmall:
            return CLKComplicationTemplateUtilitarianSmallSquare(
                imageProvider: CLKImageProvider(onePieceImage: UIImage(systemName: "mic.fill")!)
            )
            
        case .graphicCircular:
            return CLKComplicationTemplateGraphicCircularImage(
                imageProvider: CLKFullColorImageProvider(fullColorImage: UIImage(systemName: "mic.circle.fill")!)
            )
            
        case .graphicCorner:
            return CLKComplicationTemplateGraphicCornerCircularImage(
                imageProvider: CLKFullColorImageProvider(fullColorImage: UIImage(systemName: "mic.circle.fill")!)
            )
            
        default:
            return nil
        }
    }
}

// MARK: - SwiftUI Complication Views (for WidgetKit - WatchOS 9+)

import WidgetKit

/// Widget configuration for Ramble complications
struct RambleWidget: Widget {
    let kind: String = "RambleWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RambleTimelineProvider()) { entry in
            RambleComplicationView(entry: entry)
        }
        .configurationDisplayName("Ramble")
        .description("Quick access to voice recording")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryInline
        ])
    }
}

/// Timeline provider for the widget
struct RambleTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> RambleEntry {
        RambleEntry(date: Date())
    }
    
    func getSnapshot(in context: Context, completion: @escaping (RambleEntry) -> Void) {
        completion(RambleEntry(date: Date()))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<RambleEntry>) -> Void) {
        let entry = RambleEntry(date: Date())
        // Static content - refresh after 24 hours
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(86400)))
        completion(timeline)
    }
}

/// Entry for the widget timeline
struct RambleEntry: TimelineEntry {
    let date: Date
}

/// SwiftUI view for the complication
struct RambleComplicationView: View {
    var entry: RambleEntry
    
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "mic.fill")
                    .font(.title2)
                    .foregroundColor(.red)
            }
            
        case .accessoryCorner:
            Image(systemName: "mic.fill")
                .font(.title3)
                .foregroundColor(.red)
                .widgetLabel {
                    Text("Record")
                }
            
        case .accessoryInline:
            Label("Record", systemImage: "mic.fill")
            
        default:
            Image(systemName: "mic.fill")
                .foregroundColor(.red)
        }
    }
}
