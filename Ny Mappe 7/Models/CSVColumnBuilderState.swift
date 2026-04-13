import Foundation

struct CSVColumnBuilderState: Equatable {
    var columns: [[String]]
    var currentColumnIndex: Int

    var totalEntries: Int {
        columns.reduce(0) { $0 + $1.count }
    }
}
