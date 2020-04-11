//
//  String+Padding.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 11/04/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Foundation


internal extension String {
    var padded: String {
        return "\n\n\(self)\n\n"
    }
}
