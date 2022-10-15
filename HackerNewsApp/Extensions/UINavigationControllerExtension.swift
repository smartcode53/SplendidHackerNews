//
//  UINavigationControllerExtension.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 10/16/22.
//

import Foundation
import UIKit

extension UINavigationController {
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = nil
    }
    
}
