import UIKit
import SnapKit


@objc
public protocol PagesGalleryDelegate: AnyObject {
    func contentForItemAt(indexPath: IndexPath) -> UIView
    func sizeForItemAt(indexPath: IndexPath) -> CGSize
    func itemCount() -> Int
    @objc optional func itemSelected(index: Int)
}

public extension PagesGallery {

    struct DotConfig {
        let dotColor: UIColor
        let activeDotColor: UIColor
        let dotSize: CGFloat
        let betweenOffset: CGFloat
        
        public init(dotColor: UIColor, activeDotColor: UIColor, dotSize: CGFloat, betweenOffset: CGFloat) {
            self.dotColor = dotColor
            self.activeDotColor = activeDotColor
            self.dotSize = dotSize
            self.betweenOffset = betweenOffset
        }
    }

}


public final class PagesGallery: UIView,
    UICollectionViewDataSource,
    UICollectionViewDelegate,
    UICollectionViewDelegateFlowLayout
{
    
    public let dotContainer = UIView()

    public var collectionView: UICollectionView!

    private let showDots: Bool
    
    private let allowInertia: Bool

    private let allowAutoscroll: Bool

    private var delegate: PagesGalleryDelegate
    
    private let dotConfig: DotConfig
    
    private var activeDotIndex: Int?

    
    // MARK: Actions

    public func next() {
        let itemCount = delegate.itemCount()
        guard let currentIndex = activeDotIndex else {
            return
        }
        let nextIndex = currentIndex + 1
        if nextIndex > itemCount-1 {
            return
        }

        scrollToTheCell(cellIndex: nextIndex)
    }
    
    // MARK: Setup
    
    public init(
        startIndex: Int,
        showDots: Bool,
        allowInertia: Bool,
        allowAutoscroll: Bool,
        delegate: PagesGalleryDelegate,
        dotConfig: DotConfig = DotConfig(
            dotColor: UIColor.systemGray,
            activeDotColor: UIColor.white,
            dotSize: 8,
            betweenOffset: 8)
    ) {
        
        self.showDots = showDots
        
        self.allowInertia = allowInertia

        self.allowAutoscroll = allowAutoscroll

        self.delegate = delegate
        
        self.dotConfig = dotConfig

        super.init(frame: CGRect.zero)
        setupViews()
        
        if delegate.itemCount() > startIndex {
            activeDotIndex = startIndex
        }
        updateIndicator(activeDotIndex: startIndex)
        scrollToTheCell(cellIndex: startIndex, animated: false)

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupViews() {
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.scrollDirection = .horizontal
        flowLayout.minimumInteritemSpacing = 0
        flowLayout.minimumLineSpacing = 0

        collectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: flowLayout)
        collectionView.register(PagesGalleryCell.self, forCellWithReuseIdentifier: PagesGalleryCell.reuseIdentifier)
        
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        addSubview(dotContainer)
        setupIndicator()
    }
    
    func setupIndicator() {
        
        guard showDots else {
            return
        }
        
        dotContainer.subviews.forEach { $0.removeFromSuperview() }
        let dotCount = delegate.itemCount()
        if dotCount > 0 {
            for index in 0...dotCount-1 {
                let dotView = UIView()
                dotView.backgroundColor = dotConfig.dotColor
                dotView.layer.cornerRadius = dotConfig.dotSize / 2
                dotContainer.addSubview(dotView)
                dotView.snp.makeConstraints {make in
                    if index == 0 {
                        make.leading.equalToSuperview()
                    } else {
                        make.leading.equalTo(dotContainer.subviews[index-1].snp.trailing).offset(dotConfig.betweenOffset)
                    }
                    make.top.equalToSuperview()
                    make.width.height.equalTo(dotConfig.dotSize)
                    if index == dotCount-1 {
                        make.trailing.equalToSuperview()
                    }
                }
            }
        }
    }

    // MARK: UICollectionViewDataSource

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return delegate.itemCount()
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PagesGalleryCell.reuseIdentifier, for: indexPath) as! PagesGalleryCell

        let contentView = delegate.contentForItemAt(indexPath: indexPath)
        cell.setCustomContentView(customContentView: contentView)
        return cell
    }


    // MARK: UICollectionViewDelegateFlowLayout

    public func collectionView(_: UICollectionView, layout: UICollectionViewLayout, sizeForItemAt: IndexPath) -> CGSize {
        return delegate.sizeForItemAt(indexPath: sizeForItemAt)
    }


    // MARK: UICollectionViewDelegate

    public func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        return false
    }


    // MARK: UIScrollViewDelegate
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let nearestIndex = getNearectCellIndex() else {
            return
        }
        if activeDotIndex != nearestIndex {
            activeDotIndex = nearestIndex
            updateIndicator(activeDotIndex: activeDotIndex)
            delegate.itemSelected?(index: nearestIndex)
        }
    }

    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if (decelerate == false) {
            if allowAutoscroll {
                guard let nearestIndex = getNearectCellIndex() else {
                    return
                }
                scrollToTheCell(cellIndex: nearestIndex)
            }
        }
    }

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if allowAutoscroll {
            guard let nearestIndex = getNearectCellIndex() else {
                return
            }
            scrollToTheCell(cellIndex: nearestIndex)
        }
    }

    public func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
        if allowInertia == false {
            scrollView.setContentOffset(scrollView.contentOffset, animated: true)
            let actualPosition = scrollView.panGestureRecognizer.translation(in: scrollView.superview)

            guard var currentCellIndex = getNearectCellIndex() else {
                return
            }
            let size = delegate.sizeForItemAt(
                indexPath: IndexPath(row: currentCellIndex, section: 0))
            let currentWidth = size.width
            if abs(actualPosition.x) < currentWidth * 0.5 {
                if actualPosition.x < 0 {
                    currentCellIndex += 1
                } else {
                    currentCellIndex -= 1
                }
            }
            let maxIndex = delegate.itemCount() - 1
            if currentCellIndex > maxIndex { currentCellIndex = maxIndex }
            if currentCellIndex < 0 { currentCellIndex = 0 }
            scrollToTheCell(cellIndex: currentCellIndex)
        }
    }

    // MARK: Actions

    func getNearectCellIndex() -> Int? {

        let viewCenterOnBelt: CGFloat = collectionView.contentOffset.x + collectionView.frame.width / 2

        let maxIndex = delegate.itemCount() - 1
        if maxIndex < 0 {
            return nil
        }
        var cellFrames = [CGRect]()
        for i in 0...maxIndex {
            let size = delegate.sizeForItemAt(
                indexPath: IndexPath(row: i, section: 0))
            let x = cellFrames.last?.maxX ?? 0
            let frame = CGRect(x: x, y: 0, width: size.width, height: size.height)
            cellFrames.append(frame)
        }

        let cellCenters = cellFrames.map { frame -> CGFloat in
            frame.minX + frame.width/2
        }

        let distances = cellCenters.map { value -> CGFloat in
            abs(value - viewCenterOnBelt)
        }

        let index = distances.firstIndex(of: distances.min()!)!
        return index

    }

    func getSelectedIndex() -> Int? {
        guard let index = activeDotIndex else {
            return nil
        }
        return index
    }

    func updateIndicator(activeDotIndex: Int?) {
        
        guard showDots else {
            return
        }
        
        for item in self.dotContainer.subviews {
            item.backgroundColor = dotConfig.dotColor
        }
        if let activeDotIndex = activeDotIndex {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut, animations: { [weak self] in
                if let dotView = self?.dotContainer.subviews[safe: activeDotIndex] {
                    dotView.backgroundColor = self?.dotConfig.activeDotColor
                }
            }, completion: nil)
        }
    }

    func scrollToTheCell(cellIndex: Int, animated: Bool = true) {
        
        guard let cellCount = collectionView.dataSource?.collectionView(
                collectionView, numberOfItemsInSection: 0), cellIndex < cellCount else {
            return
        }

        let indexPath = IndexPath(row: cellIndex, section: 0)

        collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: animated)
    }
    
}
