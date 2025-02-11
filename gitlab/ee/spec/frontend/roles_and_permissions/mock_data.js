export const mockDefaultPermissions = [
  { value: 'A', name: 'A', description: 'A', requirements: null },
  { value: 'B', name: 'B', description: 'B', requirements: ['A'] },
  { value: 'C', name: 'C', description: 'C', requirements: ['B'] }, // Nested dependency: C -> B -> A
  { value: 'D', name: 'D', description: 'D', requirements: ['C'] }, // Nested dependency: D -> C -> B -> A
  { value: 'E', name: 'E', description: 'E', requirements: ['F'] }, // Circular dependency
  { value: 'F', name: 'F', description: 'F', requirements: ['E'] }, // Circular dependency
  { value: 'G', name: 'G', description: 'G', requirements: ['A', 'B', 'C'] }, // Multiple dependencies
];

export const mockPermissionsResponse = {
  data: {
    memberRolePermissions: {
      nodes: mockDefaultPermissions,
    },
  },
};

export const standardRoles = [
  {
    __typename: 'StandardRole',
    id: 'gid://gitlab/StandardRole/GUEST',
    accessLevel: 10,
    name: 'Guest',
    usersCount: 1,
    detailsPath: 'role/GUEST',
    description:
      'The Guest role is for users who need visibility into a project or group but should not have the ability to make changes, such as external stakeholders.',
  },
  {
    __typename: 'StandardRole',
    id: 'gid://gitlab/StandardRole/PLANNER',
    accessLevel: 15,
    name: 'Planner',
    usersCount: 1,
    detailsPath: 'role/PLANNER',
    description:
      'The Guest role is for users who need visibility into a project or group but should not have the ability to make changes, such as external stakeholders..',
  },
  {
    __typename: 'StandardRole',
    id: 'gid://gitlab/StandardRole/REPORTER',
    accessLevel: 20,
    name: 'Reporter',
    usersCount: 2,
    detailsPath: 'role/REPORTER',
    description:
      'The Reporter role is suitable for team members who need to stay informed about a project or group but do not actively contribute code.',
  },
  {
    __typename: 'StandardRole',
    id: 'gid://gitlab/StandardRole/DEVELOPER',
    accessLevel: 30,
    name: 'Developer',
    usersCount: 3,
    detailsPath: 'role/DEVELOPER',
    description:
      'The Developer role gives users access to contribute code while restricting sensitive administrative actions.',
  },
  {
    __typename: 'StandardRole',
    id: 'gid://gitlab/StandardRole/MAINTAINER',
    accessLevel: 40,
    name: 'Maintainer',
    usersCount: 4,
    detailsPath: 'role/MAINTAINER',
    description:
      'The Maintainer role is primarily used for managing code reviews, approvals, and administrative settings for projects. This role can also manage project memberships.',
  },
  {
    __typename: 'StandardRole',
    id: 'gid://gitlab/StandardRole/OWNER',
    accessLevel: 50,
    name: 'Owner',
    usersCount: 5,
    detailsPath: 'role/OWNER',
    description:
      'The Owner role is typically assigned to the individual or team responsible for managing and maintaining the group or creating the project. This role has the highest level of administrative control, and can manage all aspects of the group or project, including managing other Owners.',
  },
];

export const memberRoles = [
  {
    id: 'gid://gitlab/MemberRole/1',
    name: 'Custom role 1',
    description: 'Custom role 1 description',
    usersCount: 0,
    editPath: 'edit/path/1',
    dependentSecurityPolicies: [],
    detailsPath: 'details/path/1',
    __typename: 'MemberRole',
  },
  {
    id: 'gid://gitlab/MemberRole/2',
    name: 'Custom role 2',
    description: 'Custom role 2 description',
    usersCount: 1,
    editPath: 'edit/path/2',
    dependentSecurityPolicies: [],
    detailsPath: 'details/path/2',
    __typename: 'MemberRole',
  },
];

export const groupRolesResponse = {
  data: {
    group: {
      id: 'gid://gitlab/Group/1',
      standardRoles: { nodes: standardRoles },
      memberRoles: { nodes: memberRoles },
    },
  },
};

export const instanceRolesResponse = {
  data: {
    standardRoles: { nodes: standardRoles },
    memberRoles: { nodes: memberRoles },
  },
};

export const mockMemberRole = {
  id: 1,
  name: 'Custom role',
  description: 'Custom role description',
  createdAt: '2024-08-04T12:20:43Z',
  editPath: 'role/path/1/edit',
  usersCount: 0,
  baseAccessLevel: { stringValue: 'DEVELOPER', humanAccess: 'Developer' },
  enabledPermissions: { nodes: [{ value: 'A' }, { value: 'B' }] },
  __typename: 'MemberRole',
};

export const getMemberRoleQueryResponse = (memberRole = mockMemberRole) => ({
  data: { memberRole },
});
