import customApolloProvider from 'ee/usage_quotas/shared/provider';
import { getStorageTabMetadata } from '~/usage_quotas/storage/tab_metadata';
import { GROUP_VIEW_TYPE } from '~/usage_quotas/constants';
import { getSeatTabMetadata } from './seats/tab_metadata';
import { getCodeSuggestionsTabMetadata } from './code_suggestions/tab_metadata';
import { getPipelineTabMetadata } from './pipelines/tab_metadata';
import { getTransferTabMetadata } from './transfer/tab_metadata';
import { getProductAnalyticsTabMetadata } from './product_analytics/tab_metadata';
import { getPagesTabMetadata } from './pages/tab_metadata';

export const usageQuotasTabsMetadata = [
  getSeatTabMetadata(),
  getCodeSuggestionsTabMetadata(),
  getPipelineTabMetadata(),
  getStorageTabMetadata({ viewType: GROUP_VIEW_TYPE, customApolloProvider }),
  getTransferTabMetadata({ viewType: GROUP_VIEW_TYPE }),
  getProductAnalyticsTabMetadata(),
  getPagesTabMetadata(),
].filter(Boolean);
