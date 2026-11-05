import SwiftUI
import UIKit

/// Thành phần hiển thị ảnh có khả năng Pinch-to-zoom và Double-tap zoom chuẩn xác dựa trên UIScrollView
public struct ZoomableImageView: UIViewRepresentable {
    public let image: UIImage
    public let onSingleTap: () -> Void
    
    public init(image: UIImage, onSingleTap: @escaping () -> Void) {
        self.image = image
        self.onSingleTap = onSingleTap
    }
    
    public func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.backgroundColor = .black
        
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        imageView.tag = 100
        
        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView
        context.coordinator.scrollView = scrollView
        
        // Cử chỉ chạm đơn (ẩn/hiện thanh công cụ)
        let singleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSingleTap))
        singleTap.numberOfTapsRequired = 1
        
        // Cử chỉ chạm đúp (Double tap to zoom)
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        
        singleTap.require(toFail: doubleTap)
        scrollView.addGestureRecognizer(singleTap)
        scrollView.addGestureRecognizer(doubleTap)
        
        return scrollView
    }
    
    public func updateUIView(_ uiView: UIScrollView, context: Context) {
        if let imageView = uiView.viewWithTag(100) as? UIImageView {
            imageView.image = image
            context.coordinator.updateLayout(for: uiView.bounds.size)
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(onSingleTap: onSingleTap)
    }
    
    public final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var scrollView: UIScrollView?
        weak var imageView: UIImageView?
        let onSingleTap: () -> Void
        
        init(onSingleTap: @escaping () -> Void) {
            self.onSingleTap = onSingleTap
        }
        
        public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return imageView
        }
        
        public func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerImage()
        }
        
        @objc func handleSingleTap() {
            onSingleTap()
        }
        
        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = scrollView else { return }
            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                let location = gesture.location(in: imageView)
                let zoomRect = zoomRectForScale(scale: 2.5, center: location)
                scrollView.zoom(to: zoomRect, animated: true)
            }
        }
        
        func updateLayout(for size: CGSize) {
            guard let scrollView = scrollView, let imageView = imageView, let image = imageView.image else { return }
            guard size.width > 0 && size.height > 0 else { return }
            
            let imageRatio = image.size.width / image.size.height
            let viewRatio = size.width / size.height
            
            var newWidth: CGFloat = size.width
            var newHeight: CGFloat = size.height
            
            if imageRatio > viewRatio {
                newHeight = size.width / imageRatio
            } else {
                newWidth = size.height * imageRatio
            }
            
            imageView.frame = CGRect(x: 0, y: 0, width: newWidth, height: newHeight)
            scrollView.contentSize = CGSize(width: newWidth, height: newHeight)
            centerImage()
        }
        
        private func centerImage() {
            guard let scrollView = scrollView, let imageView = imageView else { return }
            let boundsSize = scrollView.bounds.size
            var frameToCenter = imageView.frame
            
            if frameToCenter.size.width < boundsSize.width {
                frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2
            } else {
                frameToCenter.origin.x = 0
            }
            
            if frameToCenter.size.height < boundsSize.height {
                frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2
            } else {
                frameToCenter.origin.y = 0
            }
            
            imageView.frame = frameToCenter
        }
        
        private func zoomRectForScale(scale: CGFloat, center: CGPoint) -> CGRect {
            guard let scrollView = scrollView else { return .zero }
            var zoomRect = CGRect.zero
            zoomRect.size.height = scrollView.frame.size.height / scale
            zoomRect.size.width  = scrollView.frame.size.width  / scale
            zoomRect.origin.x    = center.x - (zoomRect.size.width  / 2.0)
            zoomRect.origin.y    = center.y - (zoomRect.size.height / 2.0)
            return zoomRect
        }
    }
}
