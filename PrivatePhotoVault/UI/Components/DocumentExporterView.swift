import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Wrapper mở native iOS Document Picker để lưu file ZIP vào "On My iPhone" hoặc "iCloud Drive"
public struct DocumentExporterView: UIViewControllerRepresentable {
    public let fileURL: URL
    public let onCompleted: () -> Void
    
    public init(fileURL: URL, onCompleted: @escaping () -> Void) {
        self.fileURL = fileURL
        self.onCompleted = onCompleted
    }
    
    public func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [fileURL], asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }
    
    public func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentExporterView
        
        init(_ parent: DocumentExporterView) {
            self.parent = parent
        }
        
        public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onCompleted()
        }
        
        public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onCompleted()
        }
    }
}

/// Wrapper mở native iOS Document Picker để chọn file ZIP nhập/khôi phục từ "Files"
public struct DocumentImporterView: UIViewControllerRepresentable {
    public let onFilePicked: (URL) -> Void
    public let onCancelled: () -> Void
    
    public init(onFilePicked: @escaping (URL) -> Void, onCancelled: @escaping () -> Void) {
        self.onFilePicked = onFilePicked
        self.onCancelled = onCancelled
    }
    
    public func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.zip], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    public func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentImporterView
        
        init(_ parent: DocumentImporterView) {
            self.parent = parent
        }
        
        public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let firstURL = urls.first {
                parent.onFilePicked(firstURL)
            } else {
                parent.onCancelled()
            }
        }
        
        public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onCancelled()
        }
    }
}
