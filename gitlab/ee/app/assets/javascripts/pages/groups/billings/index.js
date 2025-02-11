import { shouldQrtlyReconciliationMount } from 'ee/billings/qrtly_reconciliation';
import initSubscriptions from 'ee/billings/subscriptions';

initSubscriptions();
shouldQrtlyReconciliationMount();
