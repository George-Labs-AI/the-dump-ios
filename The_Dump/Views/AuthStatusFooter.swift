//
//  AuthStatusFooter.swift
//  The_Dump_App_Two
//
//  Created by Emily Smith on 12/10/25.
// footer component

import SwiftUI

struct AuthStatusFooter: View {
    let email: String?
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(email != nil ? Theme.success : Color.red)
                .frame(width: 8, height: 8)
            Text(email ?? "Not signed in")
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary)
            Spacer()
        }
        .padding(.top, Theme.spacingMD)
    }
}
