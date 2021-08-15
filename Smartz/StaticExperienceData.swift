//
//  StaticExperienceData.swift
//  Joli
//
//  Created by Anthony Chinwo on 07/08/2021.
//  Copyright © 2021 Anthony Chinwo. All rights reserved.
//

import Foundation
import JoliCore

public extension ExperienceData.Item {
    
    static func makeCastmember(_ title: String, subtitle: String, alias: String, imageUrlString: String) -> Self {
        return ExperienceData.Item(experienceItemType: .person,
                                   aliasTitle: alias,
                                   caution: nil,
                                   defaultPrice: nil,
                                   duration: nil,
                                   imageName: imageUrlString,
                                   isOptional: nil,
                                   itemGrouping: nil,
                                   itemSubgrouping: nil,
                                   spicy: nil,
                                   subtitle: subtitle,
                                   title: title)
    }
    
}

let crazyworldDemo = ExperienceData.fromDefaults(.init(logoImageUrl: URL(staticString: "https://storage.googleapis.com/joli-app-bucket/images/logo_crazyworld.png"),
                                                       bannerImageUrl: URL(staticString: "https://storage.googleapis.com/joli-app-bucket/images/poster_crazy_world_lowres.jpg"),
                                                       bannerVideoUrl: URL(staticString: "https://youtu.be/wbs5ed9I9C0"),
                                                       brandName: "It's a Crazy World",
                                                       landingPageText: "“It’s a crazy world” is a modern-day 30-minute sitcom created by Amanda Ebeye and majorly directed by KC Muel and Amanda Ebeye. It tells the story of a very wealthy man with three women and three kids. It’s a hilarious sitcom that addresses the competition women go through in general trying to outdo themselves and constantly vying for the man’s attention. In this case, these women would use any means available to them, with social media being their number one go-to tool. \n\nThe other two women are constantly trying to win the favorite spot which the first wife already occupies as he constantly reminds them that besides pregnancy and the kids from the other women; he’s a man with a one-man-one-woman personality. So they try every way they can to win that spot, employing social media tools, the last wife and the kids’ area always on Instagram, Snapchat, Facebook, living a lie, making their worlds look perfect when it is not.",
                                                       socialInstagramUsername: "itsacrazyworld_tvseries",
                                                       releaseDate: Date(timeIntervalSince1970: 1627171200),
                                                       releasePlatformName: "Netflix",
                                                       releasePlatformLogoUrl: URL(staticString: "https://storage.googleapis.com/joli-app-bucket/images/logo_netflix.png"),
                                                       releasePlatformInstaUsername: "naijaonnetflix",
                                                       items: [
                                                        ExperienceData.Item.makeCastmember("Bob Manuel Udokwu", subtitle: "Husband to Adaeze Okpalla, a smooth talker that knows how to get his way with women. He presently has two other women living with him too because once a woman gets pregnant for him, he brings her in because he wants all his children under one roof but he never marries them eventually.", alias: "Don Chukwunma Okpalla", imageUrlString: "https://www.bellanaija.com/wp-content/uploads/2020/04/Screen-Shot-2020-04-25-at-15.20.58-1.png"),
                                                        ExperienceData.Item.makeCastmember("Kunle Coker", subtitle: "A Yoruba businessman, and Don’s friend and confidant. The wives don’t like him because they feel he’s a bad influence on Don, after all, rumor has it he has a wife in all 36 states in Nigeria.", alias: "Chief Balogun", imageUrlString: "https://www.bellanaija.com/wp-content/uploads/2020/04/Screen-Shot-2020-04-25-at-15.20.38.png"),
                                                        ExperienceData.Item.makeCastmember("Tunbosun Aiyedehin", subtitle: "Don’s only legitimate wife. She’s what you would typically call “the good wife”. She believes that someday what was used on her husband would expire and she would once again have him all to herself.", alias: "Adaeze", imageUrlString: "https://www.bellanaija.com/wp-content/uploads/2020/04/Screen-Shot-2020-04-25-at-15.19.22.png"),
                                                        ExperienceData.Item.makeCastmember("Grace Ama", subtitle: "One of Don’s mistresses, Kemi is a teacher who hails from the Yoruba speaking part of Nigeria. She has an eleven-year-old son for Don. Who has refused to match her intelligence? Kiddo played by Etochi Asiegbu is the direct opposite of his mother. His mother a very intelligent and successful teacher but Kiddo wants something else and is not able to assimilate. His mother feels he suffers some form of dyslexia.", alias: "Kemi", imageUrlString: "https://www.bellanaija.com/wp-content/uploads/2020/04/IMG_4034-scaled.jpg"),
                                                        ExperienceData.Item.makeCastmember("Amanda Ebeye", subtitle: "Who happens to be one of Mr. Okpalla’s lovers. A busy body who has her nose in every body’s business and hardly has time for even her own business. Don has refused to take her to the altar, and she’s permanently fighting for it. Meks is the slay queen, always-on social media searching for clout through her celebrity friends.", alias: "Meks", imageUrlString: "https://www.bellanaija.com/wp-content/uploads/2020/04/Screen-Shot-2020-04-25-at-15.21.46.png"),
                                                        ExperienceData.Item.makeCastmember("Treasure Obasi", subtitle: "She is the second child of Don and Adaeze and the only daughter in the family. She’s 19 years old, just finished secondary school and is awaiting entry into University. She’s young, beautiful, very exceeded, and loves taking and posting photos on Facebook, and Instagram. She’s also the one that constantly helps her mom with posting pictures and videos on Instagram and other social media platforms. ", alias: "Anita", imageUrlString: "https://www.bellanaija.com/wp-content/uploads/2020/04/anita-scaled.jpg"),
                                                        ExperienceData.Item.makeCastmember("Francis Odega", subtitle: "A security man “China”. He nicknamed himself China and lies to people that he used to be in China but chose to come back home to Nigeria because of how loyal he is to his country. He refuses to be called a gateman and is always fast to correct them that he is the “chief security officer”.", alias: "China", imageUrlString: "https://www.bellanaija.com/wp-content/uploads/2020/04/Screen-Shot-2020-04-25-at-15.20.46.png"),
                                                        ExperienceData.Item.makeCastmember("Adekunle Salawu", subtitle: "Kunle is one of the scriptwriters on “It’s a crazy world”. His character is hilarious, he speaks with a Calabar accent and feels his food is the best in Africa. Most of the time he is torn between the wives and doesn’t know who to please, they also try to get information from him about their husbands.", alias: "Bassey, the chef", imageUrlString: "https://www.bellanaija.com/wp-content/uploads/2020/04/Screen-Shot-2020-04-25-at-15.20.22.png"),
                                                        ExperienceData.Item.makeCastmember("Aret Edet", subtitle: "Don’s younger sister who frowns at his polygamous ways. She considers the first wife Adaeze the only wife and says the others are illegitimate. She is always at logger heads with Meks and Kemi", alias: "Aunty Frances", imageUrlString: "https://www.bellanaija.com/wp-content/uploads/2020/04/Screen-Shot-2020-04-25-at-15.21.38.png"),
                                                        ExperienceData.Item.makeCastmember("John Owotorufa", subtitle: "Sammy is the first son of Adaeze, and in the university. He is very flirtatious like his father and doesn’t have issues with his father’s mistresses.", alias: "Sammy", imageUrlString: "https://www.bellanaija.com/wp-content/uploads/2020/04/Screen-Shot-2020-04-25-at-15.21.57.png"),
                                                       ]
))
