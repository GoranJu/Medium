import {
  renderDeleteSuccessToast as renderDeleteSuccessToastCE,
  deleteParams as deleteParamsCE,
} from '~/vue_shared/components/projects_list/utils';
import {
  availableGraphQLProjectActions,
  renderRestoreSuccessToast,
  renderDeleteSuccessToast,
  deleteParams,
} from 'ee/vue_shared/components/projects_list/utils';
import {
  ACTION_EDIT,
  ACTION_RESTORE,
  ACTION_DELETE,
} from '~/vue_shared/components/list_actions/constants';
import toast from '~/vue_shared/plugins/global_toast';

const MOCK_AVAILABLE_CE_ACTIONS = [ACTION_EDIT, ACTION_DELETE];

jest.mock('~/vue_shared/plugins/global_toast');
jest.mock('~/vue_shared/components/projects_list/utils', () => ({
  ...jest.requireActual('~/vue_shared/components/projects_list/utils'),
  availableGraphQLProjectActions: jest.fn(() => MOCK_AVAILABLE_CE_ACTIONS),
  renderDeleteSuccessToast: jest.fn(),
  deleteParams: jest.fn(),
}));

const MOCK_PROJECT_NO_ADJOURNED_DELETION = {
  name: 'No Delay Project',
  fullPath: 'path/to/project/1',
  isAdjournedDeletionEnabled: false,
  markedForDeletionOn: null,
  permanentDeletionDate: '2024-03-31',
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

describe('availableGraphQLProjectActions', () => {
  describe.each`
    userPermissions             | markedForDeletionOn | availableActions
    ${{ removeProject: false }} | ${null}             | ${MOCK_AVAILABLE_CE_ACTIONS}
    ${{ removeProject: false }} | ${'2024-12-31'}     | ${MOCK_AVAILABLE_CE_ACTIONS}
    ${{ removeProject: true }}  | ${null}             | ${MOCK_AVAILABLE_CE_ACTIONS}
    ${{ removeProject: true }}  | ${'2024-12-31'}     | ${[ACTION_EDIT, ACTION_RESTORE, ACTION_DELETE]}
  `(
    'availableGraphQLProjectActions',
    ({ userPermissions, markedForDeletionOn, availableActions }) => {
      it(`when userPermissions = ${JSON.stringify(userPermissions)}, markedForDeletionOn is ${markedForDeletionOn}, then availableActions = [${availableActions}] and is sorted correctly`, () => {
        expect(
          availableGraphQLProjectActions({ userPermissions, markedForDeletionOn }),
        ).toStrictEqual(availableActions);
      });
    },
  );
});

describe('renderRestoreSuccessToast', () => {
  it('calls toast correctly', () => {
    renderRestoreSuccessToast(MOCK_PROJECT_PENDING_DELETION);

    expect(toast).toHaveBeenCalledWith(
      `Project '${MOCK_PROJECT_PENDING_DELETION.name}' has been successfully restored.`,
    );
  });
});

describe('renderDeleteSuccessToast', () => {
  afterEach(() => {
    window.gon = {};
  });

  describe('when adjourned deletion is available at the project level', () => {
    beforeEach(() => {
      renderDeleteSuccessToast(MOCK_PROJECT_WITH_DELAY_DELETION);
    });

    it('renders toast explaining project will be delayed deleted', () => {
      expect(toast).toHaveBeenCalledWith(
        `Project '${MOCK_PROJECT_WITH_DELAY_DELETION.name}' will be deleted on ${MOCK_PROJECT_WITH_DELAY_DELETION.permanentDeletionDate}.`,
      );
    });
  });

  describe('when adjourned deletion is available at the global level but not the project level', () => {
    beforeEach(() => {
      window.gon = {
        licensed_features: {
          adjournedDeletionForProjectsAndGroups: true,
        },
      };
      renderDeleteSuccessToast(MOCK_PROJECT_NO_ADJOURNED_DELETION);
    });

    it('renders toast explaining project is deleted and when data will be removed', () => {
      expect(toast).toHaveBeenCalledWith(
        `Deleting project '${MOCK_PROJECT_NO_ADJOURNED_DELETION.name}'. All data will be removed on ${MOCK_PROJECT_NO_ADJOURNED_DELETION.permanentDeletionDate}.`,
      );
    });
  });

  describe('when adjourned deletion is not available at any level', () => {
    beforeEach(() => {
      renderDeleteSuccessToast(MOCK_PROJECT_NO_ADJOURNED_DELETION);
    });

    it('calls CE function', () => {
      expect(renderDeleteSuccessToastCE).toHaveBeenCalled();
    });
  });

  describe('when project has already been marked for deletion', () => {
    beforeEach(() => {
      renderDeleteSuccessToast(MOCK_PROJECT_PENDING_DELETION);
    });

    it('renders toast explaining project is being deleted', () => {
      expect(toast).toHaveBeenCalledWith(
        `Project '${MOCK_PROJECT_PENDING_DELETION.name}' is being deleted.`,
      );
    });
  });
});

describe('deleteParams', () => {
  afterEach(() => {
    window.gon = {};
  });

  describe('when adjourned deletion is available at the project level', () => {
    it('returns empty object', () => {
      expect(deleteParams(MOCK_PROJECT_WITH_DELAY_DELETION)).toStrictEqual({});
    });
  });

  describe('when adjourned deletion is available at the global level but not the project level', () => {
    beforeEach(() => {
      window.gon = {
        licensed_features: {
          adjournedDeletionForProjectsAndGroups: true,
        },
      };
    });

    it('returns empty object', () => {
      expect(deleteParams(MOCK_PROJECT_NO_ADJOURNED_DELETION)).toStrictEqual({});
    });
  });

  describe('when adjourned deletion is not available at any level', () => {
    beforeEach(() => {
      deleteParams(MOCK_PROJECT_NO_ADJOURNED_DELETION);
    });

    it('calls CE function', () => {
      expect(deleteParamsCE).toHaveBeenCalled();
    });
  });

  describe('when project has already been marked for deletion', () => {
    it('sets permanently_remove param to true and passes full_path param', () => {
      expect(deleteParams(MOCK_PROJECT_PENDING_DELETION)).toStrictEqual({
        permanently_remove: true,
        full_path: MOCK_PROJECT_PENDING_DELETION.fullPath,
      });
    });
  });
});
