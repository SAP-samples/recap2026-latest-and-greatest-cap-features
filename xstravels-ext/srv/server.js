// ============================================================================
// Application Reference Code (READ-ONLY — do not push as part of your extension)
// ============================================================================
// This file replicates the base app's business logic needed to run inside
// `cds watch` on this ext project alone:
//
//   - Extension-point wiring: submitForReview → validateReview
//   - Primary-key generation for new Travels and new Bookings (both NEW on
//     drafts and direct CREATE — mirrors xstravels/srv/travel-service.js).
//   - TotalPrice recompute when BookingFee, FlightPrice or Supplement.Price
//     changes inside a draft.
//
// Files placed directly in `srv/` are ignored by the sandbox at `cds push`
// time — only files inside service-named subfolders like
// `srv/TravelExtensionService/` are packaged as extension handlers.
// This file therefore exists only for local iteration.
//
// It must be named `server.js` (not `travel-service.js`) because the ext
// project boots from `.base/index.csn`, not from a local `.cds` file, so CDS
// cannot auto-pair a service-named `.js` with a service definition here.
// Naming it `server.js` makes CDS pick it up as the server bootstrap.
// ============================================================================

const cds = require('@sap/cds')

cds.once('served', async () => {

  const travel = cds.services.TravelService
  const ext = await cds.connect.to('TravelExtensionService')
  const { Travels, Bookings, 'Bookings.Supplements': Supplements } = travel.entities

  // Extension-point wiring: fire validateReview before the framework performs
  // the Open → InReview transition.
  const submitForReview = Travels.actions?.submitForReview
  if (submitForReview) {
    travel.before(submitForReview, Travels, async req => {
      await ext.validateReview({
        travelID:  req.params[0].ID,
        user:      req.user.id,
        timestamp: req.timestamp?.toISOString()
      })
    })
  }

  // Primary-key generation
  const ensureIncrementalTravelId = async (req) => {
    const [active, draft] = await Promise.all([
      SELECT.one`max(ID) as maxID`.from(Travels),
      SELECT.one`max(ID) as maxID`.from(Travels.drafts)
    ])
    req.data.ID = Math.max(draft?.maxID || 0, active?.maxID || 0) + 1
  }

  travel.before('NEW',    Travels.drafts, req => ensureIncrementalTravelId(req))
  travel.before('CREATE', Travels,        req => !req.data.ID && ensureIncrementalTravelId(req))

  travel.before('NEW', Bookings.drafts, async (req) => {
    const { id } = await SELECT.one`max(Pos) as id`.from(Bookings.drafts).where({ Travel_ID: req.data.Travel_ID })
    req.data.Pos = (id || 0) + 1
  })

  travel.before('CREATE', Bookings, async (req) => {
    if (!req.data.Pos) {
      const { maxPos } = await SELECT.one`max(Pos) as maxPos`
        .from(Bookings).where({ Travel_ID: req.data.Travel_ID })
      req.data.Pos = (maxPos || 0) + 1
    }
  })

  // TotalPrice recompute (via direct SQL for efficiency).
  const UpdateTotals =
    `UPDATE ${Travels.drafts} as t SET TotalPrice = coalesce(BookingFee,0)
      + (SELECT coalesce(sum(FlightPrice),0) from ${Bookings.drafts} where Travel_ID = t.ID)
      + (SELECT coalesce(sum(Price),0) from ${Supplements.drafts} where up__Travel_ID = t.ID)
     WHERE ID = ?`

  async function update_totals(req, next, ...fields) {
    if (!fields.some(f => f in req.data)) return next()
    await next()
    const { ID: TravelID } =
      req.target === Supplements.drafts ? await SELECT.one`up_.Travel.ID as ID`.from(req.subject) :
      req.target === Bookings.drafts    ? await SELECT.one`Travel.ID as ID`.from(req.subject) :
      req.target === Travels.drafts     ? req.data :
      cds.error(`No travel found for ${req.subject}`)
    await cds.run(UpdateTotals, [TravelID])
  }

  // prepend() is needed here so these `on` handlers register into the draft
  // pipeline instead of running after it — otherwise they never fire.
  travel.prepend(() => {
    travel.on('PATCH',  Travels.drafts,     (...a) => update_totals(...a, 'BookingFee'))
    travel.on('PATCH',  Bookings.drafts,    (...a) => update_totals(...a, 'FlightPrice'))
    travel.on('PATCH',  Supplements.drafts, (...a) => update_totals(...a, 'Price'))
    travel.on('DELETE', Bookings.drafts,    (...a) => update_totals(...a, 'ID'))
    travel.on('DELETE', Supplements.drafts, (...a) => update_totals(...a, 'ID'))
  })
})

module.exports = cds.server

