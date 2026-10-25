class_name Calendar
## Game calendar: a year is 4 seasons of 3 months, each month 4 weeks of 7 days.
## Dates are derived from a single day count starting at 0 (first day of spring, year 1).

const DAYS_PER_WEEK := 7
const WEEKS_PER_MONTH := 4
const MONTHS_PER_SEASON := 3
const SEASONS := ["Spring", "Summer", "Autumn", "Winter"]

const DAYS_PER_MONTH := DAYS_PER_WEEK * WEEKS_PER_MONTH
const DAYS_PER_SEASON := DAYS_PER_MONTH * MONTHS_PER_SEASON
const DAYS_PER_YEAR := DAYS_PER_SEASON * 4
## Chișinău's latitude, which sets how high the sun climbs and how long days last.
const LATITUDE := deg_to_rad(47.0)
const AXIAL_TILT := deg_to_rad(23.44)

## Unit vector towards the sun (x east, y up, z south) at `hour` of `day`. Spring and
## autumn begin at the equinoxes, when the sun rises at 06:00, summer and winter at
## the solstices: about 15.7 hours of daylight at midsummer and 8.3 at midwinter.
static func sun(day: int, hour: float) -> Vector3:
	var declination := AXIAL_TILT * sin(TAU * day / DAYS_PER_YEAR)
	var hour_angle := TAU * (hour - 12.0) / 24.0
	return Vector3(
		-cos(declination) * sin(hour_angle),
		sin(declination) * sin(LATITUDE) + cos(declination) * cos(LATITUDE) * cos(hour_angle),
		cos(declination) * sin(LATITUDE) * cos(hour_angle) - sin(declination) * cos(LATITUDE))

## Each field counts from 1, except season, which indexes SEASONS.
static func date(day: int) -> Dictionary:
	return {
		"year": day / DAYS_PER_YEAR + 1,
		"season": day % DAYS_PER_YEAR / DAYS_PER_SEASON,
		"month": day % DAYS_PER_SEASON / DAYS_PER_MONTH + 1,
		"week": day % DAYS_PER_MONTH / DAYS_PER_WEEK + 1,
		"day": day % DAYS_PER_WEEK + 1,
	}
