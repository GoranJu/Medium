/* eslint-disable no-underscore-dangle */
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_GROUP, TYPENAME_USER } from '~/graphql_shared/constants';
import { GROUP_TYPE, USER_TYPE } from 'ee/security_orchestration/constants';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';
import {
  getPolicyType,
  decomposeApprovers,
  removeUnnecessaryDashes,
} from 'ee/security_orchestration/utils';
import { mockProjectScanExecutionPolicy } from './mocks/mock_scan_execution_policy_data';

const userApprover = {
  avatarUrl: null,
  id: 1,
  name: null,
  state: null,
  username: 'user name',
  webUrl: null,
};

const groupApprover = {
  id: 2,
  name: null,
  fullName: null,
  fullPath: 'full path',
  webUrl: null,
};

const allApprovers = [{ users: [userApprover], groups: [groupApprover] }];

describe('getPolicyType', () => {
  it.each`
    typeName                                     | field             | output
    ${''}                                        | ${undefined}      | ${undefined}
    ${'UnknownPolicyType'}                       | ${undefined}      | ${undefined}
    ${mockProjectScanExecutionPolicy.__typename} | ${undefined}      | ${POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.value}
    ${mockProjectScanExecutionPolicy.__typename} | ${'urlParameter'} | ${POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter}
  `(
    'returns $output when used on typeName: $typeName and field: $field',
    ({ typeName, field, output }) => {
      expect(getPolicyType(typeName, field)).toBe(output);
    },
  );
});

describe('decomposeApprovers', () => {
  describe('with mixed approvers', () => {
    it('returns a copy of the input values with their proper type attribute', () => {
      expect(decomposeApprovers(allApprovers)).toStrictEqual([
        {
          [GROUP_TYPE]: [
            {
              ...groupApprover,
              type: GROUP_TYPE,
              value: convertToGraphQLId(TYPENAME_GROUP, groupApprover.id),
            },
          ],
          [USER_TYPE]: [
            {
              ...userApprover,
              type: USER_TYPE,
              value: convertToGraphQLId(TYPENAME_USER, userApprover.id),
            },
          ],
        },
      ]);
    });

    it.each`
      type          | approver
      ${USER_TYPE}  | ${userApprover}
      ${GROUP_TYPE} | ${groupApprover}
    `('sets types depending on whether the approver has $type', ({ type, approver }) => {
      expect(
        decomposeApprovers(allApprovers)[0][type].find(({ id }) => id === approver.id),
      ).toEqual(expect.objectContaining({ type }));
    });
  });

  it('sets group as a type for group related approvers', () => {
    expect(decomposeApprovers([{ groups: [groupApprover] }])).toStrictEqual([
      {
        [GROUP_TYPE]: [
          {
            ...groupApprover,
            type: GROUP_TYPE,
            value: convertToGraphQLId(TYPENAME_GROUP, groupApprover.id),
          },
        ],
      },
    ]);
  });

  it('sets user as a type for user related approvers', () => {
    expect(decomposeApprovers([{ users: [userApprover] }])).toStrictEqual([
      {
        [USER_TYPE]: [
          {
            ...userApprover,
            type: USER_TYPE,
            value: convertToGraphQLId(TYPENAME_USER, userApprover.id),
          },
        ],
      },
    ]);
  });
});

describe('removeUnnecessaryDashes', () => {
  it.each`
    input          | output
    ${'---\none'}  | ${'one'}
    ${'two'}       | ${'two'}
    ${'--\nthree'} | ${'--\nthree'}
    ${'four---\n'} | ${'four'}
  `('returns $output when used on $input', ({ input, output }) => {
    expect(removeUnnecessaryDashes(input)).toBe(output);
  });
});
