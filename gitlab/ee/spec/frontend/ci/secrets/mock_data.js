import { ROTATION_PERIOD_TWO_WEEKS } from 'ee/ci/secrets/constants';

export const mockProjectEnvironments = {
  data: {
    project: {
      __typename: 'Project',
      id: 'gid://gitlab/Project/20',
      environments: {
        __typename: 'EnvironmentConnection',
        nodes: [
          {
            __typename: 'Environment',
            id: 'gid://gitlab/Environment/56',
            name: 'project_env_development',
          },
          {
            __typename: 'Environment',
            id: 'gid://gitlab/Environment/55',
            name: 'project_env_production',
          },
          {
            __typename: 'Environment',
            id: 'gid://gitlab/Environment/57',
            name: 'project_env_staging',
          },
        ],
      },
    },
  },
};

export const mockGroupEnvironments = {
  data: {
    group: {
      __typename: 'Group',
      id: 'gid://gitlab/Group/96',
      environmentScopes: {
        __typename: 'CiGroupEnvironmentScopeConnection',
        nodes: [
          {
            __typename: 'CiGroupEnvironmentScope',
            name: 'group_env_development',
          },
          {
            __typename: 'CiGroupEnvironmentScope',
            name: 'group_env_production',
          },
          {
            __typename: 'CiGroupEnvironmentScope',
            name: 'group_env_staging',
          },
        ],
      },
    },
  },
};

export const mockProjectBranches = {
  data: {
    project: {
      id: 'gid://gitlab/Project/19',
      repository: {
        branchNames: ['dev', 'main', 'production', 'staging'],
        __typename: 'Repository',
      },
      __typename: 'Project',
    },
  },
};

export const mockSecretId = 44;

export const mockSecret = ({ customSecret } = {}) => ({
  __typename: 'Secret',
  id: mockSecretId,
  branch: 'main',
  branchMatchesCount: 2,
  branchMatchesPath: '/branches',
  createdAt: '2024-01-22T08:04:26.024Z',
  description: 'This is a secret',
  environment: 'staging',
  envMatchesCount: 2,
  envMatchesPath: '/environments',
  expiration: '2029-01-22T08:04:26.024Z',
  key: 'APP_PWD',
  lastAccessed: Date.now(),
  lastAccessedUser: {
    id: 1,
    avatarUrl:
      'https://www.gravatar.com/avatar/83f082bcac69be6bda7945a24ae1a1fda41e864296bd32356819a09cc342e384?s=80&d=identicon',
    name: 'Jane Doe',
    userId: 1,
    username: 'root',
    webUrl: 'http://127.0.0.1:3000/root',
  },
  name: 'APP_PWD',
  nextRotation: '2024-09-26T08:04:26.024Z',
  rotationPeriod: ROTATION_PERIOD_TWO_WEEKS.value,
  status: 'enabled',
  ...customSecret,
});

export const mockProjectSecret = ({ customSecret, errors = [] } = {}) => ({
  data: {
    projectSecretCreate: {
      errors,
      __typename: 'ProjectSecretCreatePayload',
      projectSecret: {
        name: 'APP_PWD',
        description: 'This is a secret',
        ...customSecret,
        __typename: 'ProjectSecret',
      },
    },
  },
});

export const mockProjectSecretQueryResponse = ({ customSecret } = {}) => ({
  data: {
    projectSecret: {
      __typename: 'ProjectSecret',
      ...mockSecret(),
      ...customSecret,
    },
  },
});

export const secretManagerStatusResponse = (status) => {
  return {
    data: {
      projectSecretsManager: {
        status,
        __typename: 'ProjectSecretsManager',
      },
    },
  };
};
