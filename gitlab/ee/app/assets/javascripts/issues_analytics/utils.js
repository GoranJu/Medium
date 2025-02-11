import { isEmpty, mapKeys } from 'lodash';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { RENAMED_FILTER_KEYS_DEFAULT } from 'ee/issues_analytics/constants';
import { dateFormats } from '~/analytics/shared/constants';
import dateFormat from '~/lib/dateformat';
import { getMonthNames, cloneDate } from '~/lib/utils/datetime_utility';

/**
 * Returns an object with renamed filter keys.
 *
 * @param {Object} filters - Filters with keys to be renamed
 * @param {Object} newKeys - Map of old keys to new keys
 *
 * @returns {Object}
 */
const renameFilterKeys = (filters, newKeys) =>
  mapKeys(filters, (value, key) => newKeys[key] ?? key);

/**
 * This util method takes the global page filters and transforms parameters which
 * are not standardized between the internal issue analytics api and the public
 * issues api.
 *
 * @param {Object} filters - the global filters used to fetch issues data
 * @param {Object} renamedKeys - map of keys to be renamed
 *
 * @returns {Object} - the transformed filters for the public api
 */
export const transformFilters = (filters = {}, renamedKeys = RENAMED_FILTER_KEYS_DEFAULT) => {
  let formattedFilters = convertObjectPropsToCamelCase(filters, {
    deep: true,
    dropKeys: ['scope', 'include_subepics'],
  });

  if (!isEmpty(renamedKeys)) {
    formattedFilters = renameFilterKeys(formattedFilters, renamedKeys);
  }

  const newFilters = {};

  Object.entries(formattedFilters).forEach(([key, val]) => {
    const negatedFilterMatch = key.match(/^not\[(.+)\]/);

    if (negatedFilterMatch) {
      const negatedFilterKey = negatedFilterMatch[1];

      if (!newFilters.not) {
        newFilters.not = {};
      }

      Object.assign(newFilters.not, { [negatedFilterKey]: val });
    } else {
      newFilters[key] = val;
    }
  });

  return newFilters;
};

/**
 * @typedef {Object} monthDataItem
 * @property {Date} fromDate
 * @property {Date} toDate
 * @property {String} month - abbreviated month
 * @property {Number} year
 */

/**
 * Accepts a date range and an Issue Analytics count query type and
 * generates the data needed to build the GraphQL query for the chart
 *
 * @param startDate - start date for the date range
 * @param endDate - end date for the date range
 * @param format - format to be used by date range
 * @return {monthDataItem[]} - date range data
 */
export const generateChartDateRangeData = (startDate, endDate, format = dateFormats.isoDate) => {
  const chartDateRangeData = [];
  const abbrMonthNames = getMonthNames(true);
  const formatDate = (date) => dateFormat(date, format, true);

  for (
    let fromDate = cloneDate(startDate);
    fromDate < endDate;
    fromDate.setMonth(fromDate.getMonth() + 1, 1)
  ) {
    let toDate = cloneDate(fromDate);
    toDate.setMonth(toDate.getMonth() + 1, 1);
    if (toDate > endDate) toDate = endDate;

    chartDateRangeData.push({
      fromDate: formatDate(fromDate),
      toDate: formatDate(toDate),
      month: abbrMonthNames[fromDate.getMonth()],
      year: fromDate.getFullYear(),
      identifier: `query_${fromDate.getFullYear()}_${fromDate.getMonth() + 1}`,
    });
  }

  return chartDateRangeData;
};
