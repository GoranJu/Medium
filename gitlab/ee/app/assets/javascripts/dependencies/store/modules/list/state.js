import { FILTER } from './constants';

export default () => ({
  endpoint: '',
  exportEndpoint: '',
  vulnerabilityInfo: {},
  vulnerabilityItemsLoading: [],
  fetchingInProgress: false,
  asyncExport: false,
  initialized: false,
  isLoading: false,
  errorLoading: false,
  dependencies: [],
  namespaceType: '',
  pageInfo: {
    total: 0,
  },
  filter: FILTER.all,
  searchFilterParameters: {},
  sortField: null,
  sortOrder: null,
  licenses: [],
  fetchingLicensesInProgress: false,
});
