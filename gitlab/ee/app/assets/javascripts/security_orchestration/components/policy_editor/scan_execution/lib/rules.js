import { uniqueId } from 'lodash';
import { SCAN_EXECUTION_PIPELINE_RULE, SCAN_EXECUTION_SCHEDULE_RULE } from '../constants';
import { CRON_DEFAULT_TIME } from './cron';

export const buildDefaultPipeLineRule = () => {
  return {
    id: uniqueId('rule_'),
    type: SCAN_EXECUTION_PIPELINE_RULE,
    branches: ['*'],
  };
};

export const buildDefaultScheduleRule = () => {
  return {
    id: uniqueId('rule_'),
    type: SCAN_EXECUTION_SCHEDULE_RULE,
    branches: [],
    cadence: CRON_DEFAULT_TIME,
  };
};

export const RULE_KEY_MAP = {
  [SCAN_EXECUTION_PIPELINE_RULE]: buildDefaultPipeLineRule,
  [SCAN_EXECUTION_SCHEDULE_RULE]: buildDefaultScheduleRule,
};
