import UIKit
import SnapKit


enum SwipeDirecton {
    case left
    case right
}


@objc
protocol PagesGalleryDelegate: AnyObject {
    func contentForItemAt(indexPath: IndexPath) -> UIView
    func sizeForItemAt(indexPath: IndexPath) -> CGSize
    func itemCount() -> Int
    @objc optional func itemSelected(collectionView: UICollectionView, indexPath: IndexPath)
}


final class PagesGallery: UIView,
    UICollectionViewDataSource,
    UICollectionViewDelegate,
    UICollectionViewDelegateFlowLayout
{
    
    struct DotConfig {
        let dotColor: UIColor
        let activeDotColor: UIColor
        let dotSize: CGFloat
        let betweenOffset: CGFloat
    }
    
    let dotContainer = UIView()

    var collectionView: UICollectionView!

    private let showDots: Bool
    
    private let autoscroll: Bool
    
    private let allowInertia: Bool
    
    private let delegate: PagesGalleryDelegate
    
    private let dotConfig: DotConfig
    
    private var selectedIndex: Int?

    
    // MARK: Setup
    
    init(showDots: Bool, autoscroll: Bool, allowInertia: Bool, delegate: PagesGalleryDelegate,
         dotConfig: DotConfig = DotConfig(dotColor: UIColor.systemGray, activeDotColor: UIColor.white, dotSize: 8, betweenOffset: 8)) {
        self.showDots = showDots
        
        self.autoscroll = autoscroll
        
        self.allowInertia = allowInertia
        
        self.delegate = delegate
        
        self.dotConfig = dotConfig

        super.init(frame: CGRect.zero)
        setupViews()
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
        collectionView.backgroundColor = UIColor.white
        collectionView.showsHorizontalScrollIndicator = false
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        addSubview(dotContainer)
        setupIndicator()
        showIndicatorAtIndex(cellIndex: 0)
    }
    
    func setupIndicator() {
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

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return delegate.itemCount()
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PagesGalleryCell.reuseIdentifier, for: indexPath) as! PagesGalleryCell

        let contentView = delegate.contentForItemAt(indexPath: indexPath)
        cell.setCustomContentView(customContentView: contentView)
        return cell
    }


    // MARK: UICollectionViewDelegateFlowLayout

    func collectionView(_: UICollectionView, layout: UICollectionViewLayout, sizeForItemAt: IndexPath) -> CGSize {
        delegate.sizeForItemAt(indexPath: sizeForItemAt)
    }


    // MARK: UICollectionViewDelegate

    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        delegate.itemSelected?(collectionView: collectionView, indexPath: indexPath)
        return false
    }


    // MARK: UIScrollViewDelegate

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if (decelerate == false) {
            scrollToTheCell(cellIndex: getNearectCellIndex())
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        scrollToTheCell(cellIndex: getNearectCellIndex())
    }

    func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
        if allowInertia == false {
            scrollView.setContentOffset(scrollView.contentOffset, animated: true)
            let actualPosition = scrollView.panGestureRecognizer.translation(in: scrollView.superview)

            var currentCellIndex = getNearectCellIndex()
            let currentWidth = delegate.sizeForItemAt(indexPath: IndexPath(row: currentCellIndex, section: 0)).width
            if abs(actualPosition.x) < currentWidth * 0.5 {
                if actualPosition.x < 0 {
                    currentCellIndex += 1
                } else {
                    currentCellIndex -= 1
                }
            }
            let maxIndex = delegate.itemCount()-1
            if currentCellIndex > maxIndex { currentCellIndex = maxIndex }
            if currentCellIndex < 0 { currentCellIndex = 0 }
            scrollToTheCell(cellIndex: currentCellIndex)
        }
    }

    // MARK: Actions

    func getNearectCellIndex() -> Int {

        let viewCenterOnBelt: CGFloat = collectionView.contentOffset.x + collectionView.frame.width / 2

        let maxIndex = delegate.itemCount() - 1
        var cellFrames = [CGRect]()
        for i in 0...maxIndex {
            let size = delegate.sizeForItemAt(indexPath: IndexPath(row: i, section: 0))
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
        guard let index = selectedIndex else {
            return nil
        }
        return index
    }

    func showIndicatorAtIndex(cellIndex: Int) {
        selectedIndex = cellIndex
        for item in self.dotContainer.subviews {
            item.backgroundColor = dotConfig.dotColor
        }
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut, animations: { [weak self] in
            if let dotView = self?.dotContainer.subviews[safe: cellIndex] {
                dotView.backgroundColor = self?.dotConfig.activeDotColor
            }
        }, completion: nil)
    }

    func scrollToTheCell(cellIndex: Int) {

        guard self.autoscroll else {
            return
        }

        showIndicatorAtIndex(cellIndex: cellIndex)

        let indexPath = IndexPath(row: cellIndex, section: 0)

        collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
    }
    
}
