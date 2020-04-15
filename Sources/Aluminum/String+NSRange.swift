//
//  String+NSRange.swift
//  Aluminum
//
//  Created by Maxim Vainshtein on 10/03/2020.
//  Copyright © 2020 Maxim Vainshtein. All rights reserved.
//

import Foundation


internal extension String {
    func substring(with nsrange: NSRange) -> String? {
        guard nsrange.length > 0 else { return nil }
        guard let range = Range(nsrange, in: self) else { return nil }
        return String(self[range])
    }
}
