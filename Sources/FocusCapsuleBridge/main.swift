import Foundation
import Network
import FocusCapsuleCore

let args = CommandLine.arguments
let sourceIndex = args.firstIndex(of: "--source")
let source = sourceIndex.flatMap { index -> String? in
    let next = args.index(after: index)
    return next < args.endIndex ? args[next] : nil
}

let input = FileHandle.standardInput.readDataToEndOfFile()
guard var json = HookEnvelope.decode(input), !json.isEmpty else {
    exit(0)
}

if let source {
    json[HookEnvelope.sourceKey] = source
    json["_source"] = source
}
if json["hook_event_name"] == nil, json["eventName"] == nil, json["event_name"] == nil {
    json["hook_event_name"] = "Notification"
}
guard let body = HookEnvelope.encode(json) else {
    exit(0)
}

let connection = NWConnection(to: .unix(path: FocusCapsuleSocket.path), using: .tcp)
let done = DispatchSemaphore(value: 0)
connection.stateUpdateHandler = { state in
    if case .failed = state {
        done.signal()
    }
}
connection.start(queue: .global())
connection.send(content: body, completion: .contentProcessed { _ in
    connection.cancel()
    done.signal()
})
_ = done.wait(timeout: .now() + 1.5)
