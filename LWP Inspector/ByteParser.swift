import LWPKit

public actor ByteParser<C> where C: ByteCollection {
    private var handlers: [MessageType: (CommonMessageHeader, C.SubSequence) -> Void] = [:]
    
    public init() {}
    
    public func parse(_ bytes: C) {
        do {
            let header = try CommonMessageHeader(bytes)
            if let handler = handlers[header.messageType] {
                let payload = try bytes.view.suffix(header.length)
                handler(header, payload)
            } else {
                print("handler not found for", header.messageType, bytes)
            }
        } catch {
            print(error)
        }
    }
    
    public func addHandler<M>(for: M.Type, handler: @escaping (M) -> Void) where M: DecodableMessage  {
        handlers[M.messageType] = { header, payload in
            do {
                let message = try M(header: header, payload: payload)
                handler(message)
            } catch {
                print(error)
            }
        }
    }
    
    public func messageStream<M>(for: M.Type) -> AsyncStream<M> where M: DecodableMessage {
        return AsyncStream<M> { continuation in
            handlers[M.messageType] = { header, payload in
                do {
                    let message = try M(header: header, payload: payload)
                    continuation.yield(message)
                } catch {
                    print(error)
                }
            }
        }
    }
}
