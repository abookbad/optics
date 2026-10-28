import AppKit

// `Optics --convert <format> <files…>` and `Optics --tool <tool> <files…>` run one job
// headlessly and print the outputs; anything else launches the menu bar app.
let args = Array(CommandLine.arguments.dropFirst())

if args.count >= 3, args[0] == "--convert" || args[0] == "--tool" {
    let files = args.dropFirst(2).map { URL(fileURLWithPath: $0).standardizedFileURL }
    let job: () async throws -> JobOutput
    if args[0] == "--convert" {
        guard let f = OutputFormat(rawValue: args[1]) else {
            print("Unknown format. One of: \(OutputFormat.allCases.map(\.rawValue).joined(separator: ", "))"); exit(2)
        }
        job = { try await Engine.convert(files, to: f) }
    } else {
        guard let t = Tool(rawValue: args[1]) else {
            print("Unknown tool. One of: \(Tool.allCases.map(\.rawValue).joined(separator: ", "))"); exit(2)
        }
        job = { try await Engine.run(t, on: files) }
    }
    Task {
        do {
            switch try await job() {
            case .files(let urls): urls.forEach { print($0.path) }
            case .text(let text, _): print(text)
            }
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }
    dispatchMain()
} else {
    OpticsApp.main()
}
