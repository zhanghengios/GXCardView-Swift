//
//  GXCardCView.swift
//  GXCardViewSample
//
//  Created by Gin on 2020/9/8.
//  Copyright © 2020 gin. All rights reserved.
//

import UIKit

protocol GXCardCViewDataSource: NSObjectProtocol {
    func numberOfItems(in cardView: GXCardCView) -> Int
    func cardView(_ cardView: GXCardCView, cellForItemAt indexPath: IndexPath) -> GXCardCell
}

@objc protocol GXCardCViewDelegate: NSObjectProtocol {
    @objc optional func cardView(_ cardView: GXCardCView, didSelectItemAt index: Int)
    @objc optional func cardView(_ cardView: GXCardCView, didRemove cell: GXCardCell, forItemAt index: Int, direction: GXCardCell.SwipeDirection)
    @objc optional func cardView(_ cardView: GXCardCView, didRemoveLast cell: GXCardCell, forItemAt index: Int, direction: GXCardCell.SwipeDirection)
    @objc optional func cardView(_ cardView: GXCardCView, didDisplay cell: GXCardCell, forItemAt index: Int)
    @objc optional func cardView(_ cardView: GXCardCView, didMove cell: GXCardCell, forItemAt index: Int, move point: CGPoint, direction: GXCardCell.SwipeDirection)
}

class GXCardCView: UIView {
    weak var dataSource: GXCardCViewDataSource?
    weak var delegate: GXCardCViewDelegate?
    private(set) var cardLayout: GXCardLayout!
    private(set) var collectionView: UICollectionView!
    
    convenience init(frame: CGRect, cardLayout layout: GXCardLayout) {
        self.init(frame:frame)
        self.setCardLayout(cardLayout: layout)
    }
    
    func setCardLayout(cardLayout layout: GXCardLayout) {
        self.cardLayout = layout
        self.collectionView = UICollectionView(frame: self.bounds, collectionViewLayout: self.cardLayout)
        self.collectionView.backgroundColor = .clear
        self.collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.collectionView.dataSource = self
        self.collectionView.delegate = self
        self.addSubview(self.collectionView)
    }
}

extension GXCardCView {
    final func register<T: UICollectionViewCell>(classCellType: T.Type) {
        let cellID = String(describing: classCellType)
        self.collectionView.register(classCellType, forCellWithReuseIdentifier: cellID)
    }
    final func register<T: UICollectionViewCell>(nibCellType: T.Type) {
        let cellID = String(describing: nibCellType)
        let nib = UINib.init(nibName: cellID, bundle: nil)
        self.collectionView.register(nib, forCellWithReuseIdentifier: cellID)
    }
    final func dequeueReusableCell<T: UICollectionViewCell>(for indexPath: IndexPath, cellType: T.Type = T.self) -> T {
        let cellID = String(describing: cellType)
        let bareCell = self.collectionView.dequeueReusableCell(withReuseIdentifier: cellID, for: indexPath)
        guard let cell = bareCell as? T else {
            fatalError(
                "Failed to dequeue a cell with identifier \(cellID) matching type \(cellType.self). "
                    + "Check that the reuseIdentifier is set properly in your XIB/Storyboard "
                    + "and that you registered the cell beforehand"
            )
        }
        return cell
    }
    final func reloadData() {
        self.collectionView.reloadData()
    }
    final func scrollToItem(at index: Int, animated: Bool) {
        if animated && index > 0 {
            let currentIndex: Int = Int(round(self.collectionView.contentOffset.y / self.collectionView.frame.height))
            if abs(currentIndex - index) > 1 {
                let offsetY: CGFloat = CGFloat(index - 1) * self.collectionView.frame.height
                self.collectionView.setContentOffset(CGPoint(x: 0, y: offsetY), animated: false)
            }
        }
        let offsetY: CGFloat = CGFloat(index) * self.collectionView.frame.height
        self.collectionView.setContentOffset(CGPoint(x: 0, y: offsetY), animated: animated)
    }
    final func removeTopCardViewCell(swipe direction: GXCardCell.SwipeDirection) {
        let index: Int = Int(round(self.collectionView.contentOffset.y / self.collectionView.frame.height))
        let topCell = self.collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? GXCardCell
        topCell?.remove(swipe: direction)
    }
}

extension GXCardCView: UICollectionViewDataSource, UICollectionViewDelegate {
    // MARK: - UICollectionViewDataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.dataSource?.numberOfItems(in: self) ?? 0
    }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = self.dataSource?.cardView(self, cellForItemAt: indexPath)
        cell?.maxRemoveDistance = self.cardLayout.maxRemoveDistance
        cell?.maxAngle = self.cardLayout.maxAngle
        cell?.cardView = self
        cell?.delegate = self
        return cell ?? UICollectionViewCell()
    }
    // MARK: - UICollectionViewDelegate
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if (delegate?.responds(to: #selector(delegate?.cardView(_:didSelectItemAt:))) ?? false) {
            self.delegate?.cardView?(self, didSelectItemAt: indexPath.item)
        }
    }
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if (delegate?.responds(to: #selector(delegate?.cardView(_:didDisplay:forItemAt:))) ?? false) {
            self.delegate?.cardView?(self, didDisplay: cell as! GXCardCell, forItemAt: indexPath.item)
        }
    }
}

extension GXCardCView: UIScrollViewDelegate {
    // MARK: - UIScrollViewDelegate
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        guard self.cardLayout.isRepeat else { return }
        let index: Int = Int(round(scrollView.contentOffset.y / scrollView.frame.height))
        let lastIndex = (self.dataSource?.numberOfItems(in: self) ?? 0)
        if index == lastIndex {
            self.scrollToItem(at: 0, animated: false)
        }
    }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard self.cardLayout.isRepeat else { return }
        let index: Int = Int(round(scrollView.contentOffset.y / scrollView.frame.height))
        let lastIndex = (self.dataSource?.numberOfItems(in: self) ?? 0)
        if index == lastIndex {
            self.scrollToItem(at: 0, animated: false)
        }
    }
}

extension GXCardCView: GXCardCellDelagate {
    func cardCell(_ cell: GXCardCell, didRemoveAt direction: GXCardCell.SwipeDirection) {
        let index = self.collectionView.indexPath(for: cell)?.item ?? 0
        let lastIndex = (self.dataSource?.numberOfItems(in: self) ?? 0) - 1

        if self.cardLayout.isRepeat {
            self.scrollToItem(at: index + 1, animated: true)
        }
        else {
            if index <= lastIndex {
                self.scrollToItem(at: index + 1, animated: true)
            }
        }
        
        if (delegate?.responds(to: #selector(delegate?.cardView(_:didRemove:forItemAt:direction:))) ?? false) {
            self.delegate?.cardView?(self, didRemove: cell, forItemAt: index, direction: direction)
        }
        if  index == lastIndex {
            if (delegate?.responds(to: #selector(delegate?.cardView(_:didRemoveLast:forItemAt:direction:))) ?? false) {
                self.delegate?.cardView?(self, didRemoveLast: cell, forItemAt: index, direction: direction)
            }
        }
    }
    func cardCell(_ cell: GXCardCell, didMoveAt point: CGPoint, direction: GXCardCell.SwipeDirection) {
        if (delegate?.responds(to: #selector(delegate?.cardView(_:didMove:forItemAt:move:direction:))) ?? false) {
            let index = self.collectionView.indexPath(for: cell)?.item ?? 0
            self.delegate?.cardView?(self, didMove: cell, forItemAt: index, move: point, direction: direction)
        }
    }
}
