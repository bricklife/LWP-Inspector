import LWPKit

enum Defined<T: IDRepresentable> where T.ID: Equatable {
    case defined(T)
    case undefined(T.ID)
}

extension Defined: IDRepresentable {
    init(id: T.ID) {
        if let value = T.init(id: id) {
            self = .defined(value)
        } else {
            self = .undefined(id)
        }
    }
    
    var id: T.ID {
        switch self {
        case .defined(let value):
            return value.id
        case .undefined(let id):
            return id
        }
    }
}

extension Defined: Equatable {
    static func == (lhs: Defined<T>, rhs: Defined<T>) -> Bool {
        return lhs.id == rhs.id
    }
    
    static func == (lhs: Defined<T>, rhs: T) -> Bool {
        return lhs.id == rhs.id
    }
    
    static func == (lhs: T, rhs: Defined<T>) -> Bool {
        return lhs.id == rhs.id
    }
}

extension Defined: CustomStringConvertible where T: CustomStringConvertible, T.ID: FixedWidthInteger, T.ID: CVarArg {
    var description: String {
        let format = "0x%0\(T.ID.bitWidth / 4)x"
        switch self {
        case .defined(let value):
            return String(format: "\(value) (\(format))", value.id)
        case .undefined(let id):
            return String(format: "Undefined (\(format))", id)
        }
    }
}
