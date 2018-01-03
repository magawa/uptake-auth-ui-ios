import UIKit
import UptakeToolbox
import UptakeUI


internal class EmbeddedLoginViewController: UIViewController {
  @IBOutlet internal weak var imageView: UIImageView!
  @IBOutlet internal weak var interface: UIControl!
  internal let industry: IndustryType
  private let showInterface: Bool
  
  internal required init(industry: IndustryType, showInterface: Bool = true) {
    self.industry = industry
    self.showInterface = showInterface
    super.init(nibName: "EmbeddedLoginView", bundle: Bundle(for: type(of: self)))
  }
  
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("Unimplemented")
  }
  
  
  internal override func viewDidLoad() {
    super.viewDidLoad()
    
    interface.isVisible = showInterface
    
    view.backgroundColor = .darkBackground
    
    let name: String
    switch industry{
    case .construction:
      name = "construction"
    case .wind:
      //only have construction for now.
      name = "construction"
    }
    imageView.image = UIImage(named: name, in: Bundle(for: type(of: self)), compatibleWith: nil)
    
  }
}
