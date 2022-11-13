//
//  SendDataViewController.swift
//  NeRFCam
//
//  Created by Manuel Concepcion Brito on 2/11/22.
//

import UIKit

class SendDataViewController: UIViewController {


    
    @IBOutlet var someLabel: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.view.backgroundColor = .black // do not delete causes lag otherwise
        someLabel.text = "Please wait while we render the object"
        
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
