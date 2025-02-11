import { __ } from '~/locale';

export const LEADS_FIRST_NAME_LABEL = __('First name');
export const LEADS_LAST_NAME_LABEL = __('Last name');
export const LEADS_COMPANY_NAME_LABEL = __('Company name');
export const LEADS_COMPANY_SIZE_LABEL = __('Number of employees');
export const LEADS_PHONE_NUMBER_LABEL = __('Telephone number');
export const LEADS_COUNTRY_LABEL = __('Country or region');
export const LEADS_COUNTRY_PROMPT = __('Select a country or region');

export const COUNTRIES_WITH_STATES_ALLOWED = ['US', 'CA'];

export const companySizes = Object.freeze([
  {
    name: '1 - 99',
    id: '1-99',
  },
  {
    name: '100 - 499',
    id: '100-499',
  },
  {
    name: '500 - 1,999',
    id: '500-1,999',
  },
  {
    name: '2,000 - 9,999',
    id: '2,000-9,999',
  },
  {
    name: '10,000 +',
    id: '10,000+',
  },
]);
