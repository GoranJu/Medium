import {
  renderDeleteSuccessToast as renderDeleteSuccessToastCE,
  deleteParams as deleteParamsCE,
} from '~/vue_shared/components/resource_lists/utils';
import {
  deleteParams,
  renderRestoreSuccessToast,
  renderDeleteSuccessToast,
} from 'ee/vue_shared/components/resource_lists/utils';
import toast from '~/vue_shared/plugins/global_toast';

const MOCK_CE_PARAMS = { ceParam: true };

jest.mock('~/vue_shared/components/resource_lists/utils', () => ({
  ...jest.requireActual('~/vue_shared/components/resource_lists/utils'),
  renderDeleteSuccessToast: jest.fn(),
  deleteParams: jest.fn(() => MOCK_CE_PARAMS),
}));
jest.mock('~/vue_shared/plugins/global_toast');

const MOCK_PROJECT_NO_DELAY_DELETION = {
  name: 'No Delay Project',
  fullPath: 'path/to/project/1',
  isAdjournedDeletionEnabled: false,
  markedForDeletionOn: null,
  permanentDeletionDate: null,
};

const MOCK_PROJECT_WITH_DELAY_DELETION = {
  name: 'With Delay Project',
  fullPath: 'path/to/project/2',
  isAdjournedDeletionEnabled: true,
  markedForDeletionOn: null,
  permanentDeletionDate: '2024-03-31',
};

const MOCK_PROJECT_PENDING_DELETION = {
  name: 'Pending Deletion Project',
  fullPath: 'path/to/project/3',
  isAdjournedDeletionEnabled: true,
  markedForDeletionOn: '2024-03-24',
  permanentDeletionDate: '2024-03-31',
};

describe('renderRestoreSuccessToast', () => {
  const MOCK_TYPE = 'Project';

  it('calls toast correctly', () => {
    renderRestoreSuccessToast(MOCK_PROJECT_PENDING_DELETION, MOCK_TYPE);

    expect(toast).toHaveBeenCalledWith(
      `${MOCK_TYPE} '${MOCK_PROJECT_PENDING_DELETION.name}' has been successfully restored.`,
    );
  });
});

describe('renderDeleteSuccessToast', () => {
  const MOCK_TYPE = 'Project';

  it('when delayed deletion is disabled, calls renderDeleteSuccessToastCE', () => {
    renderDeleteSuccessToast(MOCK_PROJECT_NO_DELAY_DELETION, MOCK_TYPE);

    expect(renderDeleteSuccessToastCE).toHaveBeenCalledWith(
      MOCK_PROJECT_NO_DELAY_DELETION,
      MOCK_TYPE,
    );
    expect(toast).not.toHaveBeenCalled();
  });

  it('when delayed deletion is enabled and project is not pending deletion, calls toast with pending deletion info', () => {
    renderDeleteSuccessToast(MOCK_PROJECT_WITH_DELAY_DELETION, MOCK_TYPE);

    expect(renderDeleteSuccessToastCE).not.toHaveBeenCalled();
    expect(toast).toHaveBeenCalledWith(
      `${MOCK_TYPE} '${MOCK_PROJECT_WITH_DELAY_DELETION.name}' will be deleted on ${MOCK_PROJECT_WITH_DELAY_DELETION.permanentDeletionDate}.`,
    );
  });

  it('when delayed deletion is enabled and project is already pending deletion, calls renderDeleteSuccessToastCE', () => {
    renderDeleteSuccessToast(MOCK_PROJECT_PENDING_DELETION, MOCK_TYPE);

    expect(renderDeleteSuccessToastCE).toHaveBeenCalledWith(
      MOCK_PROJECT_PENDING_DELETION,
      MOCK_TYPE,
    );
    expect(toast).not.toHaveBeenCalled();
  });
});

describe('deleteParams', () => {
  it('when delayed deletion is disabled, returns deleteParamsCE', () => {
    const res = deleteParams(MOCK_PROJECT_NO_DELAY_DELETION);

    expect(deleteParamsCE).toHaveBeenCalled();
    expect(res).toStrictEqual(MOCK_CE_PARAMS);
  });

  it('when delayed deletion is enabled and project is not pending deletion, returns deleteParamsCE', () => {
    const res = deleteParams(MOCK_PROJECT_WITH_DELAY_DELETION);

    expect(deleteParamsCE).toHaveBeenCalled();
    expect(res).toStrictEqual(MOCK_CE_PARAMS);
  });

  it('when delayed deletion is enabled and project is already pending deletion, returns permanent deletion params', () => {
    const res = deleteParams(MOCK_PROJECT_PENDING_DELETION);

    expect(deleteParamsCE).not.toHaveBeenCalled();
    expect(res).toStrictEqual({
      permanently_remove: true,
      full_path: MOCK_PROJECT_PENDING_DELETION.fullPath,
    });
  });
});
