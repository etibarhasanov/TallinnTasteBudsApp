import Foundation

/// The short list of words the app needs that the website has no equivalent for
/// — tab names, the saved list, the about screen.
///
/// Everything a reader sees about a *place* comes from `ui.json` and changes
/// when the site changes. These are the app's own furniture, so they live here,
/// in the same eight languages the site offers. Keep the language set in step
/// with `data/ui.json`; anything missing falls back to English.
enum AppStrings {
    static func text(_ key: Key, _ lang: String) -> String {
        table[lang]?[key] ?? table["en"]?[key] ?? key.rawValue
    }

    enum Key: String {
        case tabMap, tabList, tabSaved
        case sort, sortNearest, save, saved, savedEmpty, savedEmptyHint
        case appearance
        case discountOffer, discountOpen, about, aboutBody, openWebsite, syncNote
    }

    private static let table: [String: [Key: String]] = [
        "en": [
            .tabMap: "Map", .tabList: "Places", .tabSaved: "Saved",
            .sort: "Sort", .sortNearest: "Nearest", .save: "Save", .saved: "Saved",
            .savedEmpty: "Nothing saved yet.",
            .savedEmptyHint: "Tap the bookmark on a place to keep it here.",
            .appearance: "Appearance",
            .discountOffer: "Discount", .discountOpen: "Get the code",
            .about: "About", .openWebsite: "Open the website",
            .aboutBody: "Every place on this map has been visited and approved in person. There are no scores: being on the map is the verdict.",
            .syncNote: "Places, text and photos come from tallinntastebuds.ee, so the app shows whatever the website shows."
        ],
        "et": [
            .tabMap: "Kaart", .tabList: "Kohad", .tabSaved: "Salvestatud",
            .sort: "Järjesta", .sortNearest: "Lähim", .save: "Salvesta", .saved: "Salvestatud",
            .savedEmpty: "Midagi pole veel salvestatud.",
            .savedEmptyHint: "Puuduta koha juures järjehoidjat, et see siia jääks.",
            .appearance: "Välimus",
            .discountOffer: "Soodustus", .discountOpen: "Võta kood",
            .about: "Teave", .openWebsite: "Ava veebileht",
            .aboutBody: "Igas selle kaardi kohas olen ise käinud ja selle heaks kiitnud. Hindeid pole: kaardil olemine ongi hinnang.",
            .syncNote: "Kohad, tekstid ja pildid tulevad lehelt tallinntastebuds.ee, seega rakendus näitab sedasama, mida veebileht."
        ],
        "ru": [
            .tabMap: "Карта", .tabList: "Места", .tabSaved: "Сохранённое",
            .sort: "Сортировка", .sortNearest: "Ближайшие", .save: "Сохранить", .saved: "Сохранено",
            .savedEmpty: "Пока ничего не сохранено.",
            .savedEmptyHint: "Нажмите закладку у места, чтобы оно осталось здесь.",
            .appearance: "Оформление",
            .discountOffer: "Скидка", .discountOpen: "Получить код",
            .about: "О приложении", .openWebsite: "Открыть сайт",
            .aboutBody: "В каждом месте на этой карте я был лично и одобрил его. Оценок нет: попадание на карту и есть оценка.",
            .syncNote: "Места, тексты и фотографии берутся с tallinntastebuds.ee, поэтому приложение показывает то же, что и сайт."
        ],
        "uk": [
            .tabMap: "Карта", .tabList: "Місця", .tabSaved: "Збережені",
            .sort: "Сортувати", .sortNearest: "Найближчі", .save: "Зберегти", .saved: "Збережено",
            .savedEmpty: "Ще нічого не збережено.",
            .savedEmptyHint: "Торкніться закладки біля місця, щоб воно лишилося тут.",
            .appearance: "Вигляд",
            .discountOffer: "Знижка", .discountOpen: "Отримати код",
            .about: "Про застосунок", .openWebsite: "Відкрити сайт",
            .aboutBody: "У кожному місці на цій карті я був особисто і схвалив його. Оцінок немає: потрапити на карту — це вже вирок.",
            .syncNote: "Місця, тексти та фото беруться з tallinntastebuds.ee, тому застосунок показує те саме, що й сайт."
        ],
        "fi": [
            .tabMap: "Kartta", .tabList: "Paikat", .tabSaved: "Tallennetut",
            .sort: "Järjestä", .sortNearest: "Lähin", .save: "Tallenna", .saved: "Tallennettu",
            .savedEmpty: "Mitään ei ole vielä tallennettu.",
            .savedEmptyHint: "Napauta paikan kirjanmerkkiä, niin se jää tänne.",
            .appearance: "Ulkoasu",
            .discountOffer: "Alennus", .discountOpen: "Hae koodi",
            .about: "Tietoja", .openWebsite: "Avaa sivusto",
            .aboutBody: "Olen käynyt jokaisessa tämän kartan paikassa itse ja hyväksynyt sen. Pisteitä ei ole: kartalla oleminen on tuomio.",
            .syncNote: "Paikat, tekstit ja kuvat tulevat osoitteesta tallinntastebuds.ee, joten sovellus näyttää saman kuin sivusto."
        ],
        "az": [
            .tabMap: "Xəritə", .tabList: "Yerlər", .tabSaved: "Yadda saxlanan",
            .sort: "Sırala", .sortNearest: "Ən yaxın", .save: "Yadda saxla", .saved: "Saxlanıb",
            .savedEmpty: "Hələ heç nə saxlanmayıb.",
            .savedEmptyHint: "Yerin yanındakı əlfəcinə toxun ki, burada qalsın.",
            .appearance: "Görünüş",
            .discountOffer: "Endirim", .discountOpen: "Kodu al",
            .about: "Haqqında", .openWebsite: "Saytı aç",
            .aboutBody: "Bu xəritədəki hər yerdə özüm olmuşam və bəyənmişəm. Bal yoxdur: xəritədə olmaq elə qiymətdir.",
            .syncNote: "Yerlər, mətnlər və şəkillər tallinntastebuds.ee saytından gəlir, ona görə tətbiq saytda nə varsa onu göstərir."
        ],
        "pt": [
            .tabMap: "Mapa", .tabList: "Lugares", .tabSaved: "Guardados",
            .sort: "Ordenar", .sortNearest: "Mais perto", .save: "Guardar", .saved: "Guardado",
            .savedEmpty: "Ainda não guardou nada.",
            .savedEmptyHint: "Toque no marcador de um lugar para o manter aqui.",
            .appearance: "Aspeto",
            .discountOffer: "Desconto", .discountOpen: "Obter o código",
            .about: "Sobre", .openWebsite: "Abrir o site",
            .aboutBody: "Estive pessoalmente em todos os lugares deste mapa e aprovei-os. Não há pontuações: estar no mapa é o veredicto.",
            .syncNote: "Os lugares, os textos e as fotos vêm de tallinntastebuds.ee, por isso a aplicação mostra o mesmo que o site."
        ],
        "es": [
            .tabMap: "Mapa", .tabList: "Sitios", .tabSaved: "Guardados",
            .sort: "Ordenar", .sortNearest: "Más cerca", .save: "Guardar", .saved: "Guardado",
            .savedEmpty: "Aún no has guardado nada.",
            .savedEmptyHint: "Toca el marcador de un sitio para que se quede aquí.",
            .appearance: "Apariencia",
            .discountOffer: "Descuento", .discountOpen: "Conseguir el código",
            .about: "Acerca de", .openWebsite: "Abrir la web",
            .aboutBody: "He estado en persona en todos los sitios de este mapa y los he aprobado. No hay puntuaciones: estar en el mapa es el veredicto.",
            .syncNote: "Los sitios, los textos y las fotos vienen de tallinntastebuds.ee, así que la app muestra lo mismo que la web."
        ],
        "tr": [
            .tabMap: "Harita", .tabList: "Mekânlar", .tabSaved: "Kaydedilenler",
            .sort: "Sırala", .sortNearest: "En yakın", .save: "Kaydet", .saved: "Kaydedildi",
            .savedEmpty: "Henüz bir şey kaydedilmedi.",
            .savedEmptyHint: "Burada kalması için mekânın yer imine dokunun.",
            .appearance: "Görünüm",
            .discountOffer: "İndirim", .discountOpen: "Kodu al",
            .about: "Hakkında", .openWebsite: "Siteyi aç",
            .aboutBody: "Bu haritadaki her mekâna kendim gittim ve onayladım. Puan yok: haritada olmak zaten karardır.",
            .syncNote: "Mekânlar, metinler ve fotoğraflar tallinntastebuds.ee adresinden gelir; yani uygulama sitede ne varsa onu gösterir."
        ]
    ]
}

extension ContentStore {
    /// Sugar so a view can write `store.app(.tabMap)` next to `store.strings("price")`.
    func app(_ key: AppStrings.Key) -> String {
        AppStrings.text(key, lang)
    }

    func app(_ key: AppStrings.Key, _ replacements: [String: String]) -> String {
        replacements.reduce(AppStrings.text(key, lang)) { text, pair in
            text.replacingOccurrences(of: "{\(pair.key)}", with: pair.value)
        }
    }
}
