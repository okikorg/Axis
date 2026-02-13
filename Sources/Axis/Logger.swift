import os

extension Logger {
    private static let subsystem = "com.okik.axis"

    static let editor = Logger(subsystem: subsystem, category: "editor")
    static let fileOps = Logger(subsystem: subsystem, category: "fileops")
    static let app = Logger(subsystem: subsystem, category: "app")
}
