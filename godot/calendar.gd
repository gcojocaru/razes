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

## Each field counts from 1, except season, which indexes SEASONS.
static func date(day: int) -> Dictionary:
	return {
		"year": day / DAYS_PER_YEAR + 1,
		"season": day % DAYS_PER_YEAR / DAYS_PER_SEASON,
		"month": day % DAYS_PER_SEASON / DAYS_PER_MONTH + 1,
		"week": day % DAYS_PER_MONTH / DAYS_PER_WEEK + 1,
		"day": day % DAYS_PER_WEEK + 1,
	}
