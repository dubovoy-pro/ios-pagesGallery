//
//  File.swift
//  
//
//  Created by Yury Dubovoy on 17.08.2021.
//

import UIKit
import SnapKit

public final class PagesGalleryCell: UICollectionViewCell, Reusable {
    
    public weak var customContentView: UIView?
    
    // MARK: Setup
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.white
        isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) {
        fatalError("init?(coder:) is not supported")
    }
    
    func setCustomContentView(customContentView: UIView) {
        if let view = self.customContentView {
            view.removeFromSuperview()
        }
        self.customContentView = customContentView
        addSubview(customContentView)
        customContentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
