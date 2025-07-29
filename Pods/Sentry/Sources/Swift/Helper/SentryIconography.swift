import CoreGraphics

extension CGMutablePath {
    func addSVGArc(startPoint: CGPoint, xyRadii: CGFloat, clockwise: Bool, endPoint: CGPoint) {
        let midX: CGFloat = (startPoint.x + endPoint.x) / 2
        let midY: CGFloat = (startPoint.y + endPoint.y) / 2
        let d: CGFloat = sqrt(pow(endPoint.x - startPoint.x, 2) + pow(endPoint.y - startPoint.y, 2))
        let h: CGFloat = sqrt(pow(xyRadii, 2) - pow(d / 2, 2))
        let orientation: CGFloat = clockwise ? 1 : -1
        
        let centerX = midX + orientation * h * (startPoint.y - endPoint.y) / d
        let centerY = midY + orientation * h * (endPoint.x - startPoint.x) / d
        let centerPoint = CGPoint(x: centerX, y: centerY)
        
        let startAngleAtan2X = startPoint.x - centerX
        let startAngleAtan2Y = startPoint.y - centerY
        let startAngle: CGFloat = atan2(startAngleAtan2Y, startAngleAtan2X)
        
        let endAngleAtan2X = endPoint.x - centerX
        let endAngleAtan2Y = endPoint.y - centerY
        let endAngle: CGFloat = atan2(endAngleAtan2Y, endAngleAtan2X)
        
        addArc(center: centerPoint, radius: xyRadii, startAngle: startAngle, endAngle: endAngle, clockwise: !clockwise)
    }
}

extension CGPoint {
    func translated(x: CGFloat = 0, y: CGFloat = 0) -> CGPoint {
        .init(x: self.x + x, y: self.y + y)
    }
}

struct SentryIconography {
    static let logo = {
        let path = CGMutablePath()

        // M29,2.26
        var point: CGPoint = .init(x: 29, y: 2.26)
        path.move(to: point)

        // a4.67,4.67,0,0,0-8,0
        var endpoint: CGPoint = point.translated(x: -8)
        path.addSVGArc(startPoint: point, xyRadii: 4.67, clockwise: false, endPoint: endpoint)
        point = endpoint

        // L14.42,13.53
        endpoint = .init(x: 14.42, y: 13.53)
        path.addLine(to: endpoint)
        point = endpoint

        // A32.21,32.21,0,0,1,32.17,40.19
        endpoint = .init(x: 32.17, y: 40.19)
        path.addSVGArc(startPoint: point, xyRadii: 32.21, clockwise: true, endPoint: endpoint)
        point = endpoint

        // H27.55
        endpoint = .init(x: 27.55, y: point.y)
        path.addLine(to: endpoint)
        point = endpoint

        // A27.68,27.68,0,0,0,12.09,17.47
        endpoint = .init(x: 12.09, y: 17.47)
        path.addSVGArc(startPoint: point, xyRadii: 27.68, clockwise: false, endPoint: endpoint)
        point = endpoint
        
        // L6,28
        endpoint = CGPoint(x: 6, y: 28)
        path.addLine(to: endpoint)
        point = endpoint

        // a15.92,15.92,0,0,1,9.23,12.17
        endpoint = point.translated(x: 9.23, y: 12.17)
        path.addSVGArc(startPoint: point, xyRadii: 15.92, clockwise: true, endPoint: endpoint)
        point = endpoint

        // H4.62
        endpoint = .init(x: 4.62, y: point.y)
        path.addLine(to: endpoint)
        point = endpoint

        // A.76.76,0,0,1,4,39.06
        endpoint = .init(x: 4, y: 39.06)
        path.addSVGArc(startPoint: point, xyRadii: 0.76, clockwise: true, endPoint: endpoint)
        point = endpoint

        // l2.94-5
        endpoint = point.translated(x: 2.94, y: -5)
        path.addLine(to: endpoint)
        point = endpoint

        // a10.74,10.74,0,0,0-3.36-1.9
        endpoint = point.translated(x: -3.36, y: -1.9)
        path.addSVGArc(startPoint: point, xyRadii: 10.74, clockwise: false, endPoint: endpoint)
        point = endpoint

        // l-2.91,5
        endpoint = point.translated(x: -2.91, y: 5)
        path.addLine(to: endpoint)
        point = endpoint

        // a4.54,4.54,0,0,0,1.69,6.24
        endpoint = point.translated(x: 1.69, y: 6.24)
        path.addSVGArc(startPoint: point, xyRadii: 4.54, clockwise: false, endPoint: endpoint)
        point = endpoint

        // A4.66,4.66,0,0,0,4.62,44
        endpoint = .init(x: 4.62, y: 44)
        path.addSVGArc(startPoint: point, xyRadii: 4.66, clockwise: false, endPoint: endpoint)
        point = endpoint

        // H19.15
        endpoint = CGPoint(x: 19.15, y: point.y)
        path.addLine(to: endpoint)
        point = endpoint

        // a19.4,19.4,0,0,0-8-17.31
        endpoint = point.translated(x: -8, y: -17.31)
        path.addSVGArc(startPoint: point, xyRadii: 19.4, clockwise: false, endPoint: endpoint)
        point = endpoint

        // l2.31-4
        endpoint = point.translated(x: 2.31, y: -4)
        path.addLine(to: endpoint)
        point = endpoint

        // A23.87,23.87,0,0,1,23.76,44
        endpoint = .init(x: 23.76, y: 44)
        path.addSVGArc(startPoint: point, xyRadii: 23.87, clockwise: true, endPoint: endpoint)
        point = endpoint

        // H36.07
        endpoint = CGPoint(x: 36.07, y: point.y)
        path.addLine(to: endpoint)
        point = endpoint

        // a35.88,35.88,0,0,0-16.41-31.8
        endpoint = point.translated(x: -16.41, y: -31.8)
        path.addSVGArc(startPoint: point, xyRadii: 35.88, clockwise: false, endPoint: endpoint)
        point = endpoint

        // l4.67-8
        endpoint = point.translated(x: 4.67, y: -8)
        path.addLine(to: endpoint)
        point = endpoint

        // a.77.77,0,0,1,1.05-.27
        endpoint = point.translated(x: 1.05, y: -0.27)
        path.addSVGArc(startPoint: point, xyRadii: 0.77, clockwise: true, endPoint: endpoint)
        point = endpoint

        // c.53.29,20.29,34.77,20.66,35.17
        var c1 = point.translated(x: 0.53, y: 0.29)
        var c2 = point.translated(x: 20.29, y: 34.77)
        endpoint = point.translated(x: 20.66, y: 35.17)
        path.addCurve(to: endpoint, control1: c1, control2: c2)
        point = endpoint

        // a.76.76,0,0,1-.68,1.13
        endpoint = point.translated(x: -0.68, y: 1.13)
        path.addSVGArc(startPoint: point, xyRadii: 0.76, clockwise: true, endPoint: endpoint)
        point = endpoint

        // H40.6
        endpoint = CGPoint(x: 40.6, y: point.y)
        path.addLine(to: endpoint)
        point = endpoint

        // q.09,1.91,0,3.81
        c1 = .init(x: point.x + 0.09, y: point.y + 1.91)
        endpoint = .init(x: point.x, y: point.y + 3.81)
        path.addQuadCurve(to: endpoint, control: c1)
        point = endpoint

        // h4.78
        endpoint = .init(x: point.x + 4.78, y: point.y)
        path.addLine(to: endpoint)
        point = endpoint

        // A4.59,4.59,0,0,0,50,39.43
        endpoint = .init(x: 50, y: 39.43)
        path.addSVGArc(startPoint: point, xyRadii: 4.59, clockwise: false, endPoint: endpoint)
        point = endpoint

        // a4.49,4.49,0,0,0-.62-2.28
        endpoint = point.translated(x: -0.62, y: -2.28)
        path.addSVGArc(startPoint: point, xyRadii: 4.49, clockwise: false, endPoint: endpoint)
        point = endpoint

        // Z
        path.closeSubpath()

        return path
    }()
    
    static let megaphone = {
        let path = CGMutablePath()
                
        path.move(to: CGPoint(x: 1, y: 3))
        path.addLine(to: CGPoint(x: 7, y: 3))
        path.addLine(to: CGPoint(x: 10, y: 1))
        path.addLine(to: CGPoint(x: 12, y: 1))
        path.addLine(to: CGPoint(x: 12, y: 11))
        path.addLine(to: CGPoint(x: 10, y: 11))
        path.addLine(to: CGPoint(x: 7, y: 9))
        path.addLine(to: CGPoint(x: 1, y: 9))
        path.closeSubpath()
        
        path.addRect(CGRect(x: 2, y: 9, width: 3.5, height: 6))
        
        path.move(to: CGPoint(x: 12, y: 6))
        path.addRelativeArc(center: CGPoint(x: 12, y: 6), radius: 3, startAngle: -(.pi / 2), delta: .pi)
        
        return path
    }()
}
