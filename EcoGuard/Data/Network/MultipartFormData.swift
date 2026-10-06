import Foundation

/// `multipart/form-data` 바디. 파트를 차례로 붙이고 `encoded()`로 닫는 경계까지 붙인 바디를 만든다.
nonisolated struct MultipartFormData: Sendable {
    let boundary: String
    private var parts: [Data] = []

    init(boundary: String = "EcoGuard-\(UUID().uuidString)") {
        self.boundary = boundary
    }

    var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    /// 글자 값 파트. 한글이 깨지지 않도록 UTF-8임을 밝힌다(서버는 `@RequestParam`으로 받는다).
    mutating func appendField(name: String, value: String) {
        var part = Data()
        part.append("--\(boundary)\r\n")
        part.append("Content-Disposition: form-data; name=\"\(name)\"\r\n")
        part.append("Content-Type: text/plain; charset=utf-8\r\n\r\n")
        part.append(value)
        part.append("\r\n")
        parts.append(part)
    }

    mutating func appendFile(name: String, fileName: String, mimeType: String, data: Data) {
        var part = Data()
        part.append("--\(boundary)\r\n")
        part.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileName)\"\r\n")
        part.append("Content-Type: \(mimeType)\r\n\r\n")
        part.append(data)
        part.append("\r\n")
        parts.append(part)
    }

    func encoded() -> Data {
        var body = parts.reduce(into: Data()) { $0.append($1) }
        body.append("--\(boundary)--\r\n")
        return body
    }
}

private nonisolated extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
