import axios from '~/lib/utils/axios_utils';
import { buildApiUrl } from '~/api/api_utils';

const PROJECT_RESTORE_PATH = '/api/:version/projects/:id/restore';

export function restoreProject(projectId) {
  const url = buildApiUrl(PROJECT_RESTORE_PATH).replace(':id', projectId);

  return axios.post(url);
}
