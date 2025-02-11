import { PROFILE_VIEW_TYPE } from '~/usage_quotas/constants';
import { getStorageTabMetadata } from '~/usage_quotas/storage/tab_metadata';
import { getPipelineTabMetadata } from './pipelines/tab_metadata';
import { getPagesTabMetadata } from './pages/tab_metadata';

export const usageQuotasTabsMetadata = [
  getPipelineTabMetadata(),
  getStorageTabMetadata({ viewType: PROFILE_VIEW_TYPE }),
  getPagesTabMetadata(),
].filter(Boolean);
