/**
 * @param {import('@sap/cds-oyster').OysterReq<import('#cds-models/TravelExtensionService')>} req
 * @this {import('@sap/cds-oyster').OysterThis<import('#cds-models/TravelExtensionService')>}
 * @typedef {import('@sap/cds-oyster')} _
 */

module.exports = async function validateReview(req) {
  const { travelID, user, timestamp } = req.data
  const { Travels, Bookings } = this.entities

  // TODO: implement your policy here.
  //
  //   const travel = await SELECT.one.from(Travels).where({ ID: travelID })
  //   if (travel?.TotalPrice > 10000) req.reject(409, "Total " + travel.TotalPrice + " exceeds policy limit")
  //
  // Left as a no-op — the review transition proceeds.
}
