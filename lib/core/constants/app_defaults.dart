// Prayer calculation method keys — used in SharedPreferences and prayer_manager.dart.
// These must match the case labels in PrayerManager._getParams().
const String kCalcMethodKarachi   = 'karachi';
const String kCalcMethodIsna      = 'isna';
const String kCalcMethodMwl       = 'mwl';
const String kCalcMethodEgypt     = 'egypt';
const String kCalcMethodDubai     = 'dubai';
const String kCalcMethodQatar     = 'qatar';
const String kCalcMethodSingapore = 'singapore';
const String kCalcMethodTehran    = 'tehran';
const String kCalcMethodTurkey    = 'turkey';

// Default calculation method applied when no user preference is stored.
const String kDefaultCalcMethod = kCalcMethodKarachi;

// Madhab keys — used in SharedPreferences, prayer_manager.dart, and settings UI.
const String kMadhabHanafi = 'hanafi';
const String kMadhabShafi  = 'shafii';

// Default madhab applied when no user preference is stored.
const String kDefaultMadhab = kMadhabHanafi;

// User role keys — used in Firestore documents, auth flows, and role checks.
const String kRoleCommon = 'user';
const String kRoleImam   = 'imam';

// Default role assigned to newly registered users.
const String kDefaultRole = kRoleCommon;

// Teaching audience keys — used in imam profile and registration form.
const String kTeachingAudienceNeighbourhood = 'neighbourhood';
const String kTeachingAudienceAnyone        = 'anyone';

// Default teaching audience for new imam profiles.
const String kDefaultTeachingAudience = kTeachingAudienceNeighbourhood;
