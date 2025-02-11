import { __, sprintf } from '~/locale';
import { getCurrentUtcDate, getDateInPast } from '~/lib/utils/datetime_utility';

export const TODAY = getCurrentUtcDate();
export const SEVEN_DAYS_AGO = getDateInPast(TODAY, 7);

export const DATE_RANGE_OPTION_TODAY = 'today';
export const DATE_RANGE_OPTION_LAST_7_DAYS = '7d';
export const DATE_RANGE_OPTION_LAST_30_DAYS = '30d';
export const DATE_RANGE_OPTION_LAST_60_DAYS = '60d';
export const DATE_RANGE_OPTION_LAST_90_DAYS = '90d';
export const DATE_RANGE_OPTION_LAST_180_DAYS = '180d';
export const DATE_RANGE_OPTION_CUSTOM = 'custom';

export const DEFAULT_DATE_RANGE_OPTIONS = [
  DATE_RANGE_OPTION_LAST_30_DAYS,
  DATE_RANGE_OPTION_LAST_7_DAYS,
  DATE_RANGE_OPTION_TODAY,
  DATE_RANGE_OPTION_CUSTOM,
];

export const DEFAULT_SELECTED_DATE_RANGE_OPTION = DATE_RANGE_OPTION_LAST_7_DAYS;

/**
 * The default options to display in the date_range_filter.
 *
 * Each options consists of:
 *
 * key - The key used to select the option and sync with the URL
 * text - Text to display in the dropdown item
 * startDate - Optional, the start date to set
 * endDate - Optional, the end date to set
 * showDateRangePicker - Optional, show the date range picker component and uses
 *                       it to set the date.
 */
export const DATE_RANGE_OPTIONS = {
  [DATE_RANGE_OPTION_LAST_180_DAYS]: {
    key: DATE_RANGE_OPTION_LAST_180_DAYS,
    text: sprintf(__('Last %{days} days'), { days: 180 }),
    startDate: getDateInPast(TODAY, 180),
    endDate: TODAY,
  },
  [DATE_RANGE_OPTION_LAST_90_DAYS]: {
    key: DATE_RANGE_OPTION_LAST_90_DAYS,
    text: sprintf(__('Last %{days} days'), { days: 90 }),
    startDate: getDateInPast(TODAY, 90),
    endDate: TODAY,
  },
  [DATE_RANGE_OPTION_LAST_60_DAYS]: {
    key: DATE_RANGE_OPTION_LAST_60_DAYS,
    text: sprintf(__('Last %{days} days'), { days: 60 }),
    startDate: getDateInPast(TODAY, 60),
    endDate: TODAY,
  },
  [DATE_RANGE_OPTION_LAST_30_DAYS]: {
    key: DATE_RANGE_OPTION_LAST_30_DAYS,
    text: sprintf(__('Last %{days} days'), { days: 30 }),
    startDate: getDateInPast(TODAY, 30),
    endDate: TODAY,
  },
  [DATE_RANGE_OPTION_LAST_7_DAYS]: {
    key: DATE_RANGE_OPTION_LAST_7_DAYS,
    text: sprintf(__('Last %{days} days'), { days: 7 }),
    startDate: SEVEN_DAYS_AGO,
    endDate: TODAY,
  },
  [DATE_RANGE_OPTION_TODAY]: {
    key: DATE_RANGE_OPTION_TODAY,
    text: __('Today'),
    startDate: TODAY,
    endDate: TODAY,
  },
  [DATE_RANGE_OPTION_CUSTOM]: {
    key: DATE_RANGE_OPTION_CUSTOM,
    text: __('Custom range'),
    showDateRangePicker: true,
  },
};

export const DATE_RANGE_OPTION_KEYS = Object.keys(DATE_RANGE_OPTIONS);
