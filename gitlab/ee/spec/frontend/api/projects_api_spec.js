import MockAdapter from 'axios-mock-adapter';
import * as projectsApi from 'ee/api/projects_api';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';

describe('ee/api/projects_api.js', () => {
  let mock;

  const projectId = 1;

  beforeEach(() => {
    mock = new MockAdapter(axios);

    window.gon = { api_version: 'v7' };
  });

  afterEach(() => {
    mock.restore();
  });

  describe('restoreProject', () => {
    beforeEach(() => {
      jest.spyOn(axios, 'post');
    });

    it('calls POST to the correct URL', () => {
      const expectedUrl = `/api/v7/projects/${projectId}/restore`;

      mock.onPost(expectedUrl).replyOnce(HTTP_STATUS_OK);

      return projectsApi.restoreProject(projectId).then(() => {
        expect(axios.post).toHaveBeenCalledWith(expectedUrl);
      });
    });
  });
});
