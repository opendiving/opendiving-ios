import Foundation

struct ValidationErrorDetail: Decodable {
    let type: String?
    let loc: [String]?
    let msg: String?
}

enum APIErrorDetail: Decodable {
    case message(String)
    case validation([ValidationErrorDetail])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .message(string)
            return
        }
        let errors = try container.decode([ValidationErrorDetail].self)
        self = .validation(errors)
    }

    var displayMessage: String {
        switch self {
        case .message(let text):
            return text
        case .validation(let errors):
            return errors
                .compactMap { $0.msg }
                .joined(separator: "; ")
        }
    }
}

struct APIErrorResponse: Decodable {
    let detail: APIErrorDetail
}

struct APIError: Error, LocalizedError {
    let statusCode: Int
    let message: String

    var errorDescription: String? { message }
}
