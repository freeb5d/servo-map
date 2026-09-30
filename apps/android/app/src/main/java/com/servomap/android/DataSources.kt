package com.servomap.android

/** Where a state's prices come from, and what its licence makes us show (mirrors packages/shared data-sources.ts). */
data class DataSource(
    val name: String,
    val url: String,
    val note: String,
    /** The statement the licence prescribes wherever this state's prices appear, `{year}` for the current year. */
    val attribution: String?,
    val reportUrl: String? = null,
) {
    fun attribution(year: Int): String? = attribution?.replace("{year}", year.toString())
}

private const val QLD_NO_WARRANTY =
    "In consideration of the State permitting use of this data you acknowledge and agree that the State gives no warranty in relation to the data (including accuracy, reliability, completeness, currency or suitability) and accepts no liability (including without limitation, liability in negligence) for any loss, damage or costs (including consequential damage) relating to any use of the data. Data must not be used for direct marketing or be used in breach of the privacy laws."

object DataSources {
    /** State code (lower case) to source, in display order. */
    val all: Map<String, DataSource> = linkedMapOf(
        "nsw" to DataSource("NSW FuelCheck", "https://www.fuelcheck.nsw.gov.au/",
            "Mandatory real-time price reporting under the NSW Fuel Price Reporting scheme.", null),
        "act" to DataSource("NSW FuelCheck", "https://www.fuelcheck.nsw.gov.au/",
            "ACT service stations report their prices in real time through NSW FuelCheck.", null),
        "tas" to DataSource("FuelCheck TAS", "https://www.fuelcheck.tas.gov.au/",
            "Tasmania's mandatory price reporting, served through the NSW FuelCheck API.", null),
        "qld" to DataSource("Fuel Prices QLD", "https://www.fuelpricesqld.com.au/",
            "Real-time prices published under Queensland's mandatory fuel-price reporting scheme.",
            "Based on or contains data provided by the State of Queensland (Department of Energy and Climate) {year}. $QLD_NO_WARRANTY"),
        "sa" to DataSource("SA Fuel Pricing Information Scheme", "https://www.safuelpricinginformation.com.au/",
            "Retailers must report a price change within 30 minutes under South Australia's scheme.",
            "Based on or contains data provided by the State of South Australia (Office of Consumer and Business Services) 2021-2023. Copyright of the State of South Australia.",
            "https://www.cbs.sa.gov.au/fuel"),
        "vic" to DataSource("Servo Saver", "https://service.vic.gov.au/find-services/transport-and-driving/servo-saver",
            "Service Victoria publishes prices 24 hours after retailers report them.",
            "© State of Victoria accessed via the Victorian Government Service Victoria Platform"),
        "wa" to DataSource("FuelWatch", "https://www.fuelwatch.wa.gov.au/",
            "FuelWatch publishes each day's prices for the next day, so WA prices change once a day.", null),
        "nt" to DataSource("MyFuel NT", "https://myfuelnt.nt.gov.au/",
            "Mandatory real-time price reporting under the Northern Territory's MyFuel NT scheme.", null),
    )
}
