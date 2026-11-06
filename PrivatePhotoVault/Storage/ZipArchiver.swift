import Foundation

/// Cấu trúc đại diện cho một mục trong file ZIP
public struct ZipEntry {
    public let relativePath: String
    public let data: Data
    public let modificationDate: Date
    
    public init(relativePath: String, data: Data, modificationDate: Date = Date()) {
        self.relativePath = relativePath
        self.data = data
        self.modificationDate = modificationDate
    }
}

/// Động cơ tạo và giải nén file ZIP thuần Swift, hỗ trợ tên tiếng Việt UTF-8 và streaming hiệu năng cao
public final class ZipArchiver {
    public static let shared = ZipArchiver()
    
    private init() {}
    
    // MARK: - CRC32 Checksum Table
    
    private static let crcTable: [UInt32] = {
        (0...255).map { i -> UInt32 in
            var c = UInt32(i)
            for _ in 0..<8 {
                c = (c & 1 != 0) ? (0xEDB88320 ^ (c >> 1)) : (c >> 1)
            }
            return c
        }
    }()
    
    public static func crc32(data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        data.withUnsafeBytes { rawBuffer in
            let bytes = rawBuffer.bindMemory(to: UInt8.self)
            for byte in bytes {
                let index = Int((crc ^ UInt32(byte)) & 0xFF)
                crc = crcTable[index] ^ (crc >> 8)
            }
        }
        return crc ^ 0xFFFFFFFF
    }
    
    // MARK: - ZIP Creation
    
    /// Đóng gói danh sách ZipEntry thành file ZIP tại đích chỉ định
    public func createZip(
        entries: [ZipEntry],
        destinationURL: URL,
        progress: ((Int, Int, String) -> Void)? = nil,
        isCancelled: (() -> Bool)? = nil
    ) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        fileManager.createFile(atPath: destinationURL.path, contents: nil, attributes: nil)
        guard let fileHandle = try? FileHandle(forWritingTo: destinationURL) else {
            throw NSError(domain: "ZipArchiver", code: 1, userInfo: [NSLocalizedDescriptionKey: "Không thể mở file để ghi ZIP."])
        }
        defer {
            try? fileHandle.close()
        }
        
        var centralDirectoryEntries: [Data] = []
        var currentOffset: UInt32 = 0
        let totalCount = entries.count
        
        for (index, entry) in entries.enumerated() {
            if isCancelled?() == true {
                try? fileManager.removeItem(at: destinationURL)
                throw NSError(domain: "ZipArchiver", code: 99, userInfo: [NSLocalizedDescriptionKey: "Tiến trình nén ZIP đã bị hủy."])
            }
            
            progress?(index + 1, totalCount, entry.relativePath)
            
            let pathData = entry.relativePath.data(using: .utf8) ?? Data(entry.relativePath.utf8)
            let pathLength = UInt16(pathData.count)
            let fileData = entry.data
            let uncompressedSize = UInt32(fileData.count)
            let compressedSize = uncompressedSize // Phương thức lưu trữ Store (không nén lại ảnh/video gốc để giữ nguyên chất lượng 100%)
            let fileCRC = ZipArchiver.crc32(data: fileData)
            
            // Chuyển đổi ngày tháng theo chuẩn DOS Date & Time
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: entry.modificationDate)
            let year = max(1980, components.year ?? 2026) - 1980
            let month = components.month ?? 1
            let day = components.day ?? 1
            let hour = components.hour ?? 0
            let minute = components.minute ?? 0
            let second = (components.second ?? 0) / 2
            
            let dosTime = UInt16((hour << 11) | (minute << 5) | second)
            let dosDate = UInt16((year << 9) | (month << 5) | day)
            
            // 1. Ghi Local File Header
            var localHeader = Data()
            localHeader.appendUInt32(0x04034b50) // Local file header signature
            localHeader.appendUInt16(20)         // Version needed to extract (2.0)
            localHeader.appendUInt16(0x0800)     // General purpose bit flag (Bit 11: UTF-8 encoding enabled)
            localHeader.appendUInt16(0)          // Compression method: 0 = Store (Uncompressed)
            localHeader.appendUInt16(dosTime)
            localHeader.appendUInt16(dosDate)
            localHeader.appendUInt32(fileCRC)
            localHeader.appendUInt32(compressedSize)
            localHeader.appendUInt32(uncompressedSize)
            localHeader.appendUInt16(pathLength)
            localHeader.appendUInt16(0)          // Extra field length
            localHeader.append(pathData)
            
            try fileHandle.write(contentsOf: localHeader)
            try fileHandle.write(contentsOf: fileData)
            
            // 2. Chuẩn bị Central Directory Header cho file này
            var cdEntry = Data()
            cdEntry.appendUInt32(0x02014b50) // Central directory header signature
            cdEntry.appendUInt16(20)         // Version made by
            cdEntry.appendUInt16(20)         // Version needed to extract
            cdEntry.appendUInt16(0x0800)     // Bit 11: UTF-8 encoding
            cdEntry.appendUInt16(0)          // Compression method: Store
            cdEntry.appendUInt16(dosTime)
            cdEntry.appendUInt16(dosDate)
            cdEntry.appendUInt32(fileCRC)
            cdEntry.appendUInt32(compressedSize)
            cdEntry.appendUInt32(uncompressedSize)
            cdEntry.appendUInt16(pathLength)
            cdEntry.appendUInt16(0)          // Extra field length
            cdEntry.appendUInt16(0)          // File comment length
            cdEntry.appendUInt16(0)          // Disk number start
            cdEntry.appendUInt16(0)          // Internal file attributes
            cdEntry.appendUInt32(0)          // External file attributes
            cdEntry.appendUInt32(currentOffset) // Relative offset of local header
            cdEntry.append(pathData)
            
            centralDirectoryEntries.append(cdEntry)
            currentOffset += UInt32(localHeader.count + fileData.count)
        }
        
        // 3. Ghi Central Directory
        let centralDirectoryStart = currentOffset
        var centralDirectorySize: UInt32 = 0
        for cd in centralDirectoryEntries {
            try fileHandle.write(contentsOf: cd)
            centralDirectorySize += UInt32(cd.count)
        }
        
        // 4. Ghi End of Central Directory Record (EOCD)
        var eocd = Data()
        eocd.appendUInt32(0x06054b50)        // End of central directory signature
        eocd.appendUInt16(0)                 // Number of this disk
        eocd.appendUInt16(0)                 // Disk where central directory starts
        eocd.appendUInt16(UInt16(entries.count)) // Total entries on this disk
        eocd.appendUInt16(UInt16(entries.count)) // Total entries in central directory
        eocd.appendUInt32(centralDirectorySize)
        eocd.appendUInt32(centralDirectoryStart)
        eocd.appendUInt16(0)                 // ZIP comment length
        
        try fileHandle.write(contentsOf: eocd)
    }
    
    // MARK: - ZIP Extraction & Validation
    
    /// Đọc và trích xuất danh sách các file từ một file ZIP
    public func extractZip(from zipURL: URL) throws -> [ZipEntry] {
        let fileData = try Data(contentsOf: zipURL)
        guard fileData.count > 22 else {
            throw NSError(domain: "ZipArchiver", code: 2, userInfo: [NSLocalizedDescriptionKey: "File ZIP bị rỗng hoặc không hợp lệ."])
        }
        
        // Tìm chữ ký EOCD (0x06054b50) từ cuối file lên
        var eocdOffset: Int? = nil
        let minOffset = max(0, fileData.count - 65557)
        for i in stride(from: fileData.count - 22, through: minOffset, by: -1) {
            if fileData[i] == 0x50 && fileData[i+1] == 0x4b && fileData[i+2] == 0x05 && fileData[i+3] == 0x06 {
                eocdOffset = i
                break
            }
        }
        
        guard let eocdPos = eocdOffset else {
            throw NSError(domain: "ZipArchiver", code: 3, userInfo: [NSLocalizedDescriptionKey: "Không tìm thấy cấu trúc End of Central Directory trong file ZIP."])
        }
        
        let totalEntries = Int(fileData.readUInt16(at: eocdPos + 10))
        let cdOffset = Int(fileData.readUInt32(at: eocdPos + 16))
        
        var currentCDPos = cdOffset
        var extractedEntries: [ZipEntry] = []
        
        for _ in 0..<totalEntries {
            guard currentCDPos + 46 <= fileData.count else { break }
            let sig = fileData.readUInt32(at: currentCDPos)
            guard sig == 0x02014b50 else { break }
            
            let compressionMethod = fileData.readUInt16(at: currentCDPos + 10)
            let compressedSize = Int(fileData.readUInt32(at: currentCDPos + 20))
            let uncompressedSize = Int(fileData.readUInt32(at: currentCDPos + 24))
            let nameLength = Int(fileData.readUInt16(at: currentCDPos + 28))
            let extraLength = Int(fileData.readUInt16(at: currentCDPos + 30))
            let commentLength = Int(fileData.readUInt16(at: currentCDPos + 32))
            let localHeaderOffset = Int(fileData.readUInt32(at: currentCDPos + 42))
            
            let nameData = fileData.subdata(in: (currentCDPos + 46)..<(currentCDPos + 46 + nameLength))
            let fileName = String(data: nameData, encoding: .utf8) ?? String(decoding: nameData, as: UTF8.self)
            
            // Đọc dữ liệu từ Local Header
            guard localHeaderOffset + 30 <= fileData.count else { break }
            let localNameLen = Int(fileData.readUInt16(at: localHeaderOffset + 26))
            let localExtraLen = Int(fileData.readUInt16(at: localHeaderOffset + 28))
            let fileDataStart = localHeaderOffset + 30 + localNameLen + localExtraLen
            
            guard fileDataStart + compressedSize <= fileData.count else { break }
            let rawData = fileData.subdata(in: fileDataStart..<(fileDataStart + compressedSize))
            
            if compressionMethod == 0 { // Store
                extractedEntries.append(ZipEntry(relativePath: fileName, data: rawData))
            } else {
                // Nếu nén Deflate, giải nén dữ liệu
                if let decompressed = (rawData as NSData).decompressed(using: .zlib) as Data? {
                    extractedEntries.append(ZipEntry(relativePath: fileName, data: decompressed))
                } else {
                    extractedEntries.append(ZipEntry(relativePath: fileName, data: rawData))
                }
            }
            
            currentCDPos += 46 + nameLength + extraLength + commentLength
        }
        
        return extractedEntries
    }
}

// MARK: - Data Byte Helpers

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        var v = value.littleEndian
        append(UnsafeBufferPointer(start: &v, count: 1))
    }
    
    mutating func appendUInt32(_ value: UInt32) {
        var v = value.littleEndian
        append(UnsafeBufferPointer(start: &v, count: 1))
    }
    
    func readUInt16(at offset: Int) -> UInt16 {
        return withUnsafeBytes { rawBuffer in
            rawBuffer.load(fromByteOffset: offset, as: UInt16.self).littleEndian
        }
    }
    
    func readUInt32(at offset: Int) -> UInt32 {
        return withUnsafeBytes { rawBuffer in
            rawBuffer.load(fromByteOffset: offset, as: UInt32.self).littleEndian
        }
    }
}
