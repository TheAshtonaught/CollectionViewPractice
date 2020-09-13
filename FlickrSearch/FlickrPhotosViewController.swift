

import UIKit

final class FlickrPhotosViewController: UICollectionViewController {
  // MARK: - Properties
  private let reuseIdentifier = "FlickrCell"
  private let sectionInsets = UIEdgeInsets(top: 50.0, left: 20.0, bottom: 50.0, right: 20.0)
  private var searches: [FlickrSearchResults] = []
  private let flickr = Flickr()
  private let itemsPerRow: CGFloat = 3
  private var selectedPhotos: [FlickrPhoto] = []
  private let shareLabel = UILabel()
  var largePhotoIndexPath: IndexPath? {
    didSet {
      var indexPaths: [IndexPath] = []
      if let largePhotoIndexPath = largePhotoIndexPath {
        indexPaths.append(largePhotoIndexPath)
      }
      
      if let oldValue = oldValue {
        indexPaths.append(oldValue)
      }
      
      collectionView.performBatchUpdates({
        self.collectionView.reloadItems(at: indexPaths)
      }) { _ in
        
        if let largePhotoIndexPath = self.largePhotoIndexPath {
          self.collectionView.scrollToItem(at: largePhotoIndexPath, at: .centeredVertically, animated: true)
        }
      }
    }
  }
  
  var sharing: Bool = false {
    didSet {
      collectionView.allowsMultipleSelection = sharing
      collectionView.selectItem(at: nil, animated: true, scrollPosition: [])
      selectedPhotos.removeAll()
      
      guard let shareButton = self.navigationItem.rightBarButtonItems?.first else {
        return
      }
      
      guard sharing else {
        navigationItem.setRightBarButton(shareButton, animated: true)
        return
      }
      
      if largePhotoIndexPath != nil {
        largePhotoIndexPath = nil
      }
      
      updateSharedPhotoCountLabel()
      
      let sharingItem = UIBarButtonItem(customView: shareLabel)
      let items: [UIBarButtonItem] = [shareButton, sharingItem]
      
      navigationItem.setRightBarButtonItems(items, animated: true)
      
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    collectionView.dragInteractionEnabled = true
    collectionView.dragDelegate = self
    collectionView.dropDelegate = self
  }
  
  @IBAction func share(_ sender: UIBarButtonItem) {
    
    guard !searches.isEmpty else {
      return
    }
    
    guard !selectedPhotos.isEmpty else {
      sharing.toggle()
      return
    }
    
    guard sharing else {
      return
    }
    
    let images: [UIImage] = selectedPhotos.compactMap { photo  in
      if let thumbnail = photo.thumbnail {
        return thumbnail
      }
      
      return nil
    }
    
    guard !images.isEmpty else {
      return
    }
    
    let shareController = UIActivityViewController(activityItems: images, applicationActivities: nil)
    shareController.completionWithItemsHandler = { _, _, _, _
      in
      self.sharing = false
      self.selectedPhotos.removeAll()
      self.updateSharedPhotoCountLabel()
    }
    
    shareController.popoverPresentationController?.barButtonItem = sender
    shareController.popoverPresentationController?.permittedArrowDirections = .any
    present(shareController, animated: true, completion: nil)
    
  }
  
  
  
}

// MARK: - Private
private extension FlickrPhotosViewController {
  func photo(for indexPath: IndexPath) -> FlickrPhoto {
    return searches[indexPath.section].searchResults[indexPath.row]
  }
  
  func performLargeImageFetch(for indexPath: IndexPath, flickrPhoto: FlickrPhoto) {
    guard let cell = collectionView.cellForItem(at: indexPath) as? FlickrPhotoCell else {
      return
    }
    
    cell.activityIndicator.startAnimating()
    
    flickrPhoto.loadLargeImage { [weak self] result in
      
      guard let self = self else {
        return
      }
      
      switch result {
      case .results(let photo):
        if indexPath == self.largePhotoIndexPath {
          cell.imgView.image = photo.largeImage
        }
      case .error(_):
        return
      }
    }
  }
  
  func updateSharedPhotoCountLabel() {
    if sharing {
      shareLabel.text = "\(selectedPhotos.count) photos selected"
    } else {
      shareLabel.text = ""
    }
    
    shareLabel.textColor = themeColor
    
    UIView.animate(withDuration: 0.3) {
      self.shareLabel.sizeToFit()
    }
  }
  
  func removePhoto(at indexPath: IndexPath) {
    searches[indexPath.section].searchResults.remove(at: indexPath.row)
  }
  
  func insertPhoto(_ flickrPhoto: FlickrPhoto, at indexPath: IndexPath) {
    searches[indexPath.section].searchResults.insert(flickrPhoto, at: indexPath.row)
  }
  
}

// MARK: - Text Field Delegate
extension FlickrPhotosViewController : UITextFieldDelegate {
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    // 1
    let activityIndicator = UIActivityIndicatorView(style: .gray)
    textField.addSubview(activityIndicator)
    activityIndicator.frame = textField.bounds
    activityIndicator.startAnimating()
    
    flickr.searchFlickr(for: textField.text!) { searchResults in
      activityIndicator.removeFromSuperview()
      
      switch searchResults {
      case .error(let error) :
        print("Error Searching: \(error)")
      case .results(let results):
        print("Found \(results.searchResults.count) matching \(results.searchTerm)")
        self.searches.insert(results, at: 0)
        
        // 4
        self.collectionView?.reloadData()
      }
    }
    
    textField.text = nil
    textField.resignFirstResponder()
    return true
  }
}

// MARK: - UICollectionViewDataSource
extension FlickrPhotosViewController {
  //1
  override func numberOfSections(in collectionView: UICollectionView) -> Int {
    return searches.count
  }
  
  //2
  override func collectionView(_ collectionView: UICollectionView,
                               numberOfItemsInSection section: Int) -> Int {
    return searches[section].searchResults.count
  }
  
  //3
  override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    //1
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier,
                                                  for: indexPath) as! FlickrPhotoCell
    //2
    let flickrPhoto = photo(for: indexPath)
    
    cell.activityIndicator.stopAnimating()
    
    guard indexPath == largePhotoIndexPath else {
      cell.imgView.image = flickrPhoto.thumbnail
      return cell
    }
    
    guard flickrPhoto.largeImage == nil else {
      cell.imgView.image = flickrPhoto.largeImage
      return cell
    }
    
    
    cell.imgView.image = flickrPhoto.thumbnail
    
    performLargeImageFetch(for: indexPath, flickrPhoto: flickrPhoto)
    
    return cell
  }
  
  override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
    
    switch kind {
    case UICollectionView.elementKindSectionHeader:
      guard let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "\(FlickrPhotoHeaderView.self)", for: indexPath) as? FlickrPhotoHeaderView else {
        fatalError("Invalid view type")
      }
      
      let searchTerm = searches[indexPath.section].searchTerm
      headerView.label.text = searchTerm
      return headerView
    default:
      assert(false, "invaled element type")
    }
  }
  
}

// MARK: - Collection View Flow Layout Delegate
extension FlickrPhotosViewController : UICollectionViewDelegateFlowLayout {
  //1
  func collectionView(_ collectionView: UICollectionView,
                      layout collectionViewLayout: UICollectionViewLayout,
                      sizeForItemAt indexPath: IndexPath) -> CGSize {
    //2
    let paddingSpace = sectionInsets.left * (itemsPerRow + 1)
    let availableWidth = view.frame.width - paddingSpace
    let widthPerItem = floor(availableWidth / itemsPerRow)
    
    if indexPath == largePhotoIndexPath {
      let flickrPhoto = photo(for: indexPath)
      var size = collectionView.bounds.size
      size.height -= (sectionInsets.top + sectionInsets.bottom)
      size.width -= (sectionInsets.left + sectionInsets.right)
      return flickrPhoto.sizeToFillWidth(of: size)
    }
    
    return CGSize(width: widthPerItem, height: widthPerItem)
  }
  
  //3
  func collectionView(_ collectionView: UICollectionView,
                      layout collectionViewLayout: UICollectionViewLayout,
                      insetForSectionAt section: Int) -> UIEdgeInsets {
    return sectionInsets
  }
  
  // 4
  func collectionView(_ collectionView: UICollectionView,
                      layout collectionViewLayout: UICollectionViewLayout,
                      minimumLineSpacingForSectionAt section: Int) -> CGFloat {
    return sectionInsets.left
  }
  
  
  
}

extension FlickrPhotosViewController {
  override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
    
    guard !sharing else {
      return true
    }
    
    if largePhotoIndexPath == indexPath {
      largePhotoIndexPath = nil
    } else {
      largePhotoIndexPath = indexPath
    }
    
    return false
  }
  
  override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    guard sharing else {
      return
    }
    
    let flickrPhoto = photo(for: indexPath)
    selectedPhotos.append(flickrPhoto)
    updateSharedPhotoCountLabel()
    
  }
}
//MARK: - UICollectionViewDragDelegate
extension FlickrPhotosViewController: UICollectionViewDragDelegate {
  func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
    let flickrPhoto = photo(for: indexPath)
    guard let thumbnail = flickrPhoto.thumbnail else {
      return []
    }
    let item = NSItemProvider(object: thumbnail)
    let dragItem = UIDragItem(itemProvider: item)
    return [dragItem]
  }
}


// MARK: - UICollectionViewDropDelegate
extension FlickrPhotosViewController: UICollectionViewDropDelegate {
  func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
    return true
  }
  
  func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
    guard let destinationIndexPath = coordinator.destinationIndexPath else {
      return
    }
    
    coordinator.items.forEach { (dropItem) in
      guard let sourceIndexPath = dropItem.sourceIndexPath else {
        return
      }
      
      collectionView.performBatchUpdates({
        let image = photo(for: sourceIndexPath)
        removePhoto(at: sourceIndexPath)
        insertPhoto(image, at: destinationIndexPath)
        collectionView.deleteItems(at: [sourceIndexPath])
        collectionView.insertItems(at: [sourceIndexPath])
      }, completion: { _ in
        coordinator.drop(dropItem.dragItem, toItemAt: destinationIndexPath)
      })
    }
  }
  
  func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
    return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
  }
  
}
