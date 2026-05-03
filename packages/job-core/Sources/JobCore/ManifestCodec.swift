import Foundation

public enum ManifestCodec {
    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    public static func encode(_ manifest: BundleManifest) throws -> Data {
        try makeEncoder().encode(manifest)
    }

    public static func decode(_ data: Data) throws -> BundleManifest {
        try makeDecoder().decode(BundleManifest.self, from: data)
    }

    public static func write(_ manifest: BundleManifest, to url: URL) throws {
        let data = try encode(manifest)
        try data.write(to: url, options: [.atomic])
    }

    public static func read(from url: URL) throws -> BundleManifest {
        let data = try Data(contentsOf: url)
        return try decode(data)
    }
}
