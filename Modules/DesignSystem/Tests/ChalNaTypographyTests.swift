import Testing
import SwiftUI
import UIKit
import DesignSystem

struct ChalNaTypographyTests {
    @Test func rolesUseTheDesignedFacesAndScaleWithDynamicType() {
        let roles: [(Font, String, CGFloat, Font.TextStyle)] = [
            (ChalNaTypography.display, "Bold", 36, .largeTitle),
            (ChalNaTypography.screenTitle, "Bold", 28, .title),
            (ChalNaTypography.title, "Bold", 22, .title2),
            (ChalNaTypography.headline, "Bold", 16, .headline),
            (ChalNaTypography.body, "Regular", 16, .body),
            (ChalNaTypography.label, "Medium", 14, .subheadline),
            (ChalNaTypography.caption, "Medium", 12, .caption),
        ]
        for (role, weight, size, style) in roles {
            let name = "AppleSDGothicNeo-\(weight)"
            #expect(UIFont(name: name, size: size)?.familyName == "Apple SD Gothic Neo")
            #expect(role == Font.custom(name, size: size, relativeTo: style))
        }
    }

    @Test func fixedWordmarkUsesTheSameTypeface() {
        #expect(ChalNaTypography.fixed(48) == Font.custom("AppleSDGothicNeo-Bold", fixedSize: 48))
    }

    @Test func twoColumnEditingRequiresEnoughWidthAndLandscape() {
        #expect(!ChalNaLayout.isSplit(CGSize(width: 393, height: 852)))
        #expect(!ChalNaLayout.isSplit(CGSize(width: 466, height: 678)))
        #expect(!ChalNaLayout.isSplit(CGSize(width: 669, height: 951)))
        #expect(ChalNaLayout.isSplit(CGSize(width: 951, height: 669)))
    }
}
