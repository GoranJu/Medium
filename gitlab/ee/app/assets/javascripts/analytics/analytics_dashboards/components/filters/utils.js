import { queryToObject } from '~/lib/utils/url_utility';
import { formatDate, newDate } from '~/lib/utils/datetime_utility';
import { ISO_SHORT_FORMAT } from '~/vue_shared/constants';
import {
  convertObjectPropsToCamelCase,
  convertObjectPropsToSnakeCase,
  parseBoolean,
} from '~/lib/utils/common_utils';
import {
  DATE_RANGE_OPTIONS,
  DATE_RANGE_OPTION_CUSTOM,
  DATE_RANGE_OPTION_KEYS,
  DEFAULT_SELECTED_DATE_RANGE_OPTION,
} from './constants';

const isCustomOption = (option) => option && option === DATE_RANGE_OPTION_CUSTOM;

export const getDateRangeOption = (optionKey) => DATE_RANGE_OPTIONS[optionKey] || null;

export const dateRangeOptionToFilter = ({ startDate, endDate, key }) => ({
  startDate,
  endDate,
  dateRangeOption: key,
});

const DEFAULT_FILTER = dateRangeOptionToFilter(
  DATE_RANGE_OPTIONS[DEFAULT_SELECTED_DATE_RANGE_OPTION],
);

export const buildDefaultDashboardFilters = (queryString, dashboardDefaultFilters = {}) => {
  const { dateRangeOption, startDate, endDate, filterAnonUsers } = convertObjectPropsToCamelCase(
    queryToObject(queryString, { gatherArrays: true }),
  );

  const optionKey = dateRangeOption || dashboardDefaultFilters?.dateRange?.defaultOption;
  const dateRangeOverride = DATE_RANGE_OPTION_KEYS.includes(optionKey)
    ? dateRangeOptionToFilter(getDateRangeOption(optionKey))
    : {};

  const customDateRange = isCustomOption(optionKey);

  return {
    ...DEFAULT_FILTER,
    // Override default filter with user defined option
    ...dateRangeOverride,
    // Override date range when selected option is custom date range
    ...(customDateRange && { startDate: newDate(startDate) }),
    ...(customDateRange && { endDate: newDate(endDate) }),
    filterAnonUsers: parseBoolean(filterAnonUsers),
  };
};

export const filtersToQueryParams = ({ dateRangeOption, startDate, endDate, filterAnonUsers }) => {
  const customDateRange = isCustomOption(dateRangeOption);

  return convertObjectPropsToSnakeCase({
    dateRangeOption,
    // Clear the date range unless the custom date range is selected
    startDate: customDateRange ? formatDate(startDate, ISO_SHORT_FORMAT) : null,
    endDate: customDateRange ? formatDate(endDate, ISO_SHORT_FORMAT) : null,
    // Clear the anon users filter unless truthy
    filterAnonUsers: filterAnonUsers || null,
  });
};

export function isDashboardFilterEnabled(filter) {
  return filter?.enabled || false;
}
