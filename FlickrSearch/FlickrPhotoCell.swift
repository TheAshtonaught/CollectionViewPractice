

import UIKit

class FlickrPhotoCell: UICollectionViewCell {
    
  @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
  @IBOutlet weak var imgView: UIImageView!
  
  override var isSelected: Bool {
    didSet{
      imgView.layer.borderWidth = isSelected ? 10 : 0
    }
  }
  
  override func awakeFromNib() {
    super.awakeFromNib()
    imgView.layer.borderColor = themeColor.cgColor
    isSelected = false
  }
}
